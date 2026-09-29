import Foundation

/// Minimal Phoenix-channel client for Supabase Realtime, used to push rate changes to the app the
/// instant an admin saves an edit (instead of waiting for the periodic poll in `RatesView`).
/// Deliberately hand-rolled with `URLSessionWebSocketTask` rather than pulling in the full
/// supabase-swift SDK: the app only needs one channel and one event kind (`postgres_changes`).
actor SupabaseRealtimeClient {
    /// A signal that *something* changed on the subscribed table. Callers should treat this as
    /// "invalidate and reload", not attempt to diff the payload, since the wire format can add
    /// fields over time without notice.
    struct ChangeEvent: Sendable {}

    private let projectURL: URL
    private let apiKey: String
    private var task: URLSessionWebSocketTask?
    private var receiveLoopTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var messageRef = 0
    private var continuation: AsyncStream<ChangeEvent>.Continuation?

    init?(projectURL: URL, apiKey: String) {
        guard !apiKey.isEmpty else { return nil }
        self.projectURL = projectURL
        self.apiKey = apiKey
    }

    /// Starts (or restarts) the socket and returns a stream that yields whenever the given table
    /// reports an insert/update/delete. The stream stays open until `stop()` is called; on socket
    /// errors it retries with a short backoff so a flaky connection doesn't need caller intervention.
    func changes(table: String, schema: String = "public") -> AsyncStream<ChangeEvent> {
        stop()
        let (stream, continuation) = AsyncStream<ChangeEvent>.makeStream()
        self.continuation = continuation
        connectAndListen(table: table, schema: schema)
        return stream
    }

    func stop() {
        heartbeatTask?.cancel()
        receiveLoopTask?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        heartbeatTask = nil
        receiveLoopTask = nil
        task = nil
        continuation?.finish()
        continuation = nil
    }

    private func connectAndListen(table: String, schema: String, attempt: Int = 0) {
        guard var components = URLComponents(url: projectURL, resolvingAgainstBaseURL: false) else { return }
        components.scheme = components.scheme == "http" ? "ws" : "wss"
        components.path = "/realtime/v1/websocket"
        components.queryItems = [
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "vsn", value: "1.0.0")
        ]
        guard let url = components.url else { return }

        let session = URLSession(configuration: .default)
        let socket = session.webSocketTask(with: url)
        task = socket
        socket.resume()

        let topic = "realtime:\(schema):\(table)"
        send(socket, event: "phx_join", topic: topic, payload: [
            "config": ["postgres_changes": [["event": "*", "schema": schema, "table": table]]]
        ])

        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                guard let self, !Task.isCancelled else { return }
                await self.sendHeartbeat(socket)
            }
        }

        receiveLoopTask = Task { [weak self] in
            guard let self else { return }
            await self.receiveLoop(socket, table: table, schema: schema, attempt: attempt)
        }
    }

    private func receiveLoop(_ socket: URLSessionWebSocketTask, table: String, schema: String, attempt: Int) async {
        do {
            while !Task.isCancelled {
                let message = try await socket.receive()
                if case .string(let text) = message, Self.isPostgresChangeEvent(text) {
                    continuation?.yield(ChangeEvent())
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            let backoff = min(30, pow(2.0, Double(attempt)))
            try? await Task.sleep(for: .seconds(backoff))
            guard !Task.isCancelled else { return }
            connectAndListen(table: table, schema: schema, attempt: attempt + 1)
        }
    }

    private func sendHeartbeat(_ socket: URLSessionWebSocketTask) {
        send(socket, event: "heartbeat", topic: "phoenix", payload: [:])
    }

    private func send(_ socket: URLSessionWebSocketTask, event: String, topic: String, payload: [String: Any]) {
        messageRef += 1
        let envelope: [String: Any] = ["topic": topic, "event": event, "payload": payload, "ref": "\(messageRef)"]
        guard let data = try? JSONSerialization.data(withJSONObject: envelope) else { return }
        socket.send(.string(String(decoding: data, as: UTF8.self))) { _ in }
    }

    /// True when the frame is a `postgres_changes` broadcast (an actual row insert/update/delete),
    /// as opposed to Phoenix protocol bookkeeping (`phx_reply`, heartbeats, join acks, etc).
    nonisolated static func isPostgresChangeEvent(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = object["event"] as? String else { return false }
        return event == "postgres_changes"
    }
}
