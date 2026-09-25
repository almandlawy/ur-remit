import SwiftUI

struct RatesView: View {
    @StateObject private var model: RatesViewModel
    @Environment(\.locale) private var locale

    init(repository: any RatesRepository) {
        _model = StateObject(wrappedValue: RatesViewModel(repository: repository))
    }

    var body: some View {
        Group {
            switch model.state {
            case .idle, .loading:
                List(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16).fill(.quaternary).frame(height: 110).redacted(reason: .placeholder)
                }.accessibilityLabel(Text("rates"))
            case .loaded(let snapshot) where snapshot.rates.isEmpty:
                ContentUnavailableView("no_rates", systemImage: "chart.line.downtrend.xyaxis")
            case .loaded(let snapshot):
                List {
                    if snapshot.isFromCache {
                        Label("offline_notice", systemImage: "wifi.slash").foregroundStyle(.secondary)
                    }
                    ForEach(snapshot.rates) { rate in
                        URCard {
                            Text(rate.displayName(locale: locale)).font(.headline)
                            Text("\(rate.sourceCurrency) / \(rate.destinationCurrency)").font(.caption).foregroundStyle(.secondary)
                            if let buy = rate.buy { LabeledContent("شراء", value: buy.formatted()) }
                            if let sell = rate.sell { LabeledContent("بيع", value: sell.formatted()) }
                        }.listRowSeparator(.hidden)
                    }
                }.listStyle(.plain).refreshable { await model.load() }
            case .failed:
                ContentUnavailableView {
                    Label("تعذر تحميل الأسعار", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("retry") { Task { await model.load() } }
                }
            }
        }
        .navigationTitle("rates")
        .task { if case .idle = model.state { await model.load() } }
    }
}
