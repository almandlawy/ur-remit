import SwiftUI

struct TrackingView: View {
    let api: any APIClient
    @State private var reference = ""; @State private var result: TransferTracking?
    @State private var message = ""; @State private var loading = false

    var body: some View {
        Form {
            Section("transfer_reference") {
                TextField("reference_placeholder", text: $reference)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityLabel(Text("transfer_reference"))
                Button {
                    Task { await track() }
                } label: {
                    if loading {
                        ProgressView("checking_transfer")
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("track_transfer")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(loading || !validReference)
                if !reference.isEmpty && !validReference {
                    Text("invalid_reference")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if let result {
                Section("transfer_status") {
                    Label {
                        statusLabel(result.status).font(.headline)
                    } icon: {
                        Image(systemName: statusSymbol(result.status))
                    }
                    LabeledContent("origin", value: result.origin)
                    LabeledContent("destination", value: result.destination)
                    LabeledContent("last_updated", value: result.lastUpdate.formatted(date: .abbreviated, time: .shortened))
                    if let estimatedCompletion = result.estimatedCompletion {
                        LabeledContent("estimated_completion", value: estimatedCompletion.formatted(date: .abbreviated, time: .shortened))
                    }
                    if result.status == "HELD" {
                        Text("transfer_held_notice")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if !message.isEmpty {
                Section { Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.secondary) }
            }
            Section { Text("tracking_security_notice").font(.footnote) }
        }.navigationTitle("tracking")
    }

    private var normalizedReference: String { reference.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    private var validReference: Bool { normalizedReference.range(of: #"^UR-[A-Z0-9]{8}$"#, options: .regularExpression) != nil }

    private func track() async {
        loading = true; message = ""; result = nil; defer { loading = false }
        do { result = try await api.track(reference: normalizedReference) }
        catch is CancellationError { return }
        catch { message = String(localized: "tracking_lookup_failed") }
    }

    private func statusLabel(_ value: String) -> Text {
        switch value {
        case "ISSUED": Text("status_issued")
        case "ASSIGNED": Text("status_assigned")
        case "READY_FOR_PICKUP": Text("status_ready")
        case "COMPLETED": Text("status_completed")
        case "CANCELLED": Text("status_cancelled")
        case "REFUNDED": Text("status_refunded")
        case "HELD": Text("status_held")
        default: Text(value)
        }
    }

    private func statusSymbol(_ value: String) -> String { value == "COMPLETED" ? "checkmark.seal.fill" : value == "HELD" ? "exclamationmark.shield.fill" : "clock.badge.checkmark" }
}
