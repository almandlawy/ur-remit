import SwiftUI

/// Reuses the existing public `api.rates()` call (same pattern as the web admin panel) to list
/// routes, then edits each one via the authenticated `AdminAPIClient.updateRate`, which writes
/// straight to Supabase's `rates` table (RLS-gated to signed-in admins). Kept intentionally simple:
/// one row per route with inline buy/sell/fee fields and a per-row save button.
struct AdminRatesView: View {
    let api: any APIClient
    @ObservedObject var session: AdminSessionStore

    @State private var rates: [Rate] = []
    @State private var drafts: [UUID: RateDraft] = [:]
    @State private var savingID: UUID?
    @State private var rowMessage: [UUID: String] = [:]
    @State private var loadState: LoadState = .loading

    private enum LoadState { case loading, loaded, empty, failed(String) }

    struct RateDraft {
        var buy: String
        var sell: String
        var feeFixed: String
    }

    var body: some View {
        List {
            switch loadState {
            case .loading:
                ProgressView("admin_loading_rates").frame(maxWidth: .infinity)
            case .failed(let message):
                ContentUnavailableView("admin_load_failed", systemImage: "wifi.exclamationmark", description: Text(message))
            case .empty:
                ContentUnavailableView("admin_no_rates", systemImage: "chart.line.flattrend.xyaxis")
            case .loaded:
                ForEach(rates) { rate in
                    rateRow(rate)
                }
            }
        }
        .navigationTitle("admin_rates_title")
        .refreshable { await load() }
        .task { await load() }
    }

    @ViewBuilder
    private func rateRow(_ rate: Rate) -> some View {
        let binding = draftBinding(for: rate)
        Section(rate.displayName(locale: .current)) {
            LabeledContent("rate_buy") { TextField("rate_buy", text: binding.buy).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
            LabeledContent("rate_sell") { TextField("rate_sell", text: binding.sell).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
            LabeledContent("admin_fee_fixed") { TextField("admin_fee_fixed", text: binding.feeFixed).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
            if let message = rowMessage[rate.id] {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
            Button {
                Task { await save(rate) }
            } label: {
                if savingID == rate.id {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("admin_save_rate").frame(maxWidth: .infinity)
                }
            }
            .disabled(savingID != nil)
        }
    }

    private func draftBinding(for rate: Rate) -> (buy: Binding<String>, sell: Binding<String>, feeFixed: Binding<String>) {
        let current: RateDraft = drafts[rate.id] ?? RateDraft(
            buy: rate.buy.map { "\($0)" } ?? "",
            sell: rate.sell.map { "\($0)" } ?? "",
            feeFixed: rate.feeFixed.map { "\($0)" } ?? ""
        )
        if drafts[rate.id] == nil { drafts[rate.id] = current }
        return (
            Binding(get: { drafts[rate.id]?.buy ?? current.buy }, set: { drafts[rate.id]?.buy = $0 }),
            Binding(get: { drafts[rate.id]?.sell ?? current.sell }, set: { drafts[rate.id]?.sell = $0 }),
            Binding(get: { drafts[rate.id]?.feeFixed ?? current.feeFixed }, set: { drafts[rate.id]?.feeFixed = $0 })
        )
    }

    private func load() async {
        loadState = .loading
        do {
            let fetched = try await api.rates()
            rates = fetched.sorted { $0.displayName(locale: .current) < $1.displayName(locale: .current) }
            loadState = rates.isEmpty ? .empty : .loaded
        } catch {
            loadState = .failed(String(localized: "admin_load_failed_detail"))
        }
    }

    private func save(_ rate: Rate) async {
        let draft = draftBinding(for: rate)
        savingID = rate.id
        rowMessage[rate.id] = nil
        defer { savingID = nil }
        let update = AdminRateUpdate(
            buy: Decimal(string: draft.buy.wrappedValue),
            sell: Decimal(string: draft.sell.wrappedValue),
            feeFixed: Decimal(string: draft.feeFixed.wrappedValue),
            feePercent: nil
        )
        do {
            try await session.updateRate(id: rate.id, update: update)
            rowMessage[rate.id] = String(localized: "admin_rate_saved")
            await load()
        } catch AdminAPIError.forbidden {
            rowMessage[rate.id] = String(localized: "admin_forbidden")
        } catch AdminAPIError.sessionExpired {
            rowMessage[rate.id] = String(localized: "admin_session_expired")
        } catch {
            rowMessage[rate.id] = String(localized: "admin_rate_save_failed")
        }
    }
}
