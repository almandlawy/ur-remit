import SwiftUI

enum TransferAmount {
    static func positiveDecimal(from text: String, locale: Locale) -> Decimal? {
        guard let amount = Decimal(string: text, locale: locale), amount > 0 else { return nil }
        return amount
    }
}

struct CalculatorView: View {
    let repository: any RatesRepository
    @State private var rates: [Rate] = []; @State private var selectedRateID: UUID?
    @State private var amount = ""; @State private var loading = true
    @State private var loadFailed = false
    @State private var isFromCache = false
    @State private var cacheWriteFailed = false
    @Environment(\.locale) private var locale

    private var selectedRate: Rate? { rates.first { $0.id == selectedRateID } }
    private var result: Decimal? {
        guard let rate = selectedRate,
              let value = TransferAmount.positiveDecimal(from: amount, locale: locale),
              let exchange = rate.sell ?? rate.buy else { return nil }
        return value * exchange
    }

    var body: some View {
        Form {
            Section("calculator_details") {
                Picker("transfer_route", selection: $selectedRateID) {
                    Text("choose_route").tag(UUID?.none)
                    ForEach(rates) { rate in
                        Text(rate.displayName(locale: locale)).tag(Optional(rate.id))
                    }
                }
                TextField("amount", text: $amount)
                    .keyboardType(.decimalPad)
                    .accessibilityLabel(Text("amount_to_convert"))
            }
            if let rate = selectedRate, let result {
                Section("estimated_result") {
                    LabeledContent("exchange_rate", value: (rate.sell ?? rate.buy ?? 0).formatted())
                    LabeledContent("estimated_payout", value: "\(result.formatted()) \(rate.destinationCurrency)")
                    if isFromCache {
                        Label("calculator_cached_rates", systemImage: "wifi.slash")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if cacheWriteFailed {
                        Label("rates_not_saved_for_offline", systemImage: "externaldrive.badge.exclamationmark")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if Date.now >= rate.staleAfter {
                        Label("rate_may_be_outdated", systemImage: "clock.badge.exclamationmark")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    Text("estimate_disclaimer")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("contact_to_confirm_rate", destination: URL(string: "https://urremit.com/contact")!)
                }
            }
            if selectedRate != nil && !amount.isEmpty && result == nil {
                Section { Text("invalid_amount").font(.footnote).foregroundStyle(.secondary) }
            }
            if loadFailed && !rates.isEmpty {
                Section {
                    Label("refresh_failed_showing_saved", systemImage: "wifi.exclamationmark")
                        .foregroundStyle(.secondary)
                    Button("retry") { Task { await loadRates() } }
                }
            }
            if loading {
                Section { ProgressView("loading_rates") }
            } else if rates.isEmpty {
                Section {
                    ContentUnavailableView(
                        loadFailed ? "calculator_rates_failed" : "calculator_no_rates",
                        systemImage: loadFailed ? "wifi.exclamationmark" : "function"
                    )
                    Button("retry") { Task { await loadRates() } }
                }
            }
        }
        .navigationTitle("calculator")
        .task { await loadRates() }
        .refreshable { await loadRates() }
    }

    private func loadRates() async {
        loading = true
        loadFailed = false
        defer { loading = false }
        do {
            let snapshot = try await repository.loadRates()
            rates = snapshot.rates.filter { $0.buy != nil || $0.sell != nil }
            isFromCache = snapshot.isFromCache
            cacheWriteFailed = snapshot.cacheWriteFailed
        } catch is CancellationError {
            return
        } catch {
            loadFailed = true
        }
    }
}
