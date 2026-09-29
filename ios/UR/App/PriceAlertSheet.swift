import SwiftUI

struct PriceAlertSheet: View {
    let rateID: UUID
    let displayName: String
    let currency: String
    let currentPrice: Decimal?

    @Environment(\.dismiss) private var dismiss
    @State private var threshold: String = ""
    @State private var permissionDenied = false

    private var existing: Decimal? {
        PriceAlertManager.shared.threshold(for: rateID)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .trailing, spacing: 16) {
                Text(displayName)
                    .font(.title3.weight(.black))
                    .foregroundStyle(URColor.deepNavy)

                if let current = currentPrice {
                    Text("السعر الحالي: \(current.formatted()) \(currency)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("سيتم تنبيهك عند وصول السعر إلى:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("مثال: 3.75", text: $threshold)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.trailing)
                    Text(currency)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(URColor.premiumGold)
                }
                .padding(14)
                .background(URColor.ivory, in: RoundedRectangle(cornerRadius: 12))

                if permissionDenied {
                    Label("الإشعارات غير مفعّلة. فعّلها من الإعدادات.", systemImage: "bell.slash.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Button {
                    if let value = Decimal(string: threshold) {
                        PriceAlertManager.shared.setAlert(for: rateID, threshold: value)
                        dismiss()
                    }
                } label: {
                    Label("حفظ التنبيه", systemImage: "bell.badge.fill")
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(URColor.deepNavy, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .disabled(Decimal(string: threshold) == nil)

                if existing != nil {
                    Button(role: .destructive) {
                        PriceAlertManager.shared.removeAlert(for: rateID)
                        dismiss()
                    } label: {
                        Label("إزالة التنبيه", systemImage: "bell.slash")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("تنبيه سعر")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إغلاق") { dismiss() }
                }
            }
            .task {
                await PriceAlertManager.shared.requestPermissionIfNeeded()
                permissionDenied = !PriceAlertManager.shared.isAuthorized
                if let existing {
                    threshold = "\(existing)"
                }
            }
        }
    }
}
