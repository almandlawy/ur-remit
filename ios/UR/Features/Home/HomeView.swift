import SwiftUI

struct HomeView: View {
    let repository: any RatesRepository
    let api: any APIClient
    @EnvironmentObject private var auth: URAuthService
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var customerAPI = URNativeAPI.customer
    @State private var snapshot: RatesSnapshot?
    @State private var openOrder: [String: Any]?
    @State private var rateError = ""
    @State private var orderError = ""
    @State private var loadingRates = false
    @State private var loadingOrder = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                header
                rateCard
                primaryActions
                orderCard
                shortcuts
                if !rateError.isEmpty { retryCard(rateError) { await loadRates() } }
                if !orderError.isEmpty { retryCard(orderError) { await loadOrder() } }
            }.padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 20)
        }
        .background(URColor.ivory.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        .environment(\.layoutDirection, .rightToLeft).refreshable { await refresh() }
        .task(id: auth.isAuthenticated) {
            await customerAPI.resumeCustomerAccount(appEmail: auth.isAuthenticated ? auth.email : nil)
            await refresh()
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await refresh() } } }
    }

    private var header: some View {
        HStack(spacing: 11) {
            URBrandLogo(size: 42)
            VStack(alignment: .leading, spacing: 1) {
                Text("أور جلوبال").font(.title3.weight(.black)).foregroundStyle(URColor.deepNavy)
                Text(auth.isAuthenticated ? "متابعة حسابك وحوالاتك" : "الأسعار والحوالات بمكان واحد").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            NavigationLink { URNativeNotificationView(api: customerAPI) } label: {
                Image(systemName: "bell.badge.fill").font(.title3).foregroundStyle(URColor.deepNavy)
                    .frame(width: 46, height: 46).background(.white, in: Circle()).overlay(Circle().stroke(URColor.hairline))
            }.accessibilityLabel("إشعارات الحساب")
        }
    }

    @ViewBuilder private var rateCard: some View {
        let rate = snapshot?.rates.first { $0.sourceCurrency == "USD" && $0.destinationCurrency == "IQD" }
        let stale = rate.map { $0.staleAfter < Date() } ?? false
        VStack(alignment: .trailing, spacing: 12) {
            HStack {
                if loadingRates { ProgressView().controlSize(.small) }
                if snapshot?.isFromCache == true { statusPill("محفوظ", color: .orange) }
                if stale { statusPill("قديم", color: .red) }
                Spacer()
                Label("الدولار مقابل الدينار العراقي", systemImage: "dollarsign.circle.fill").font(.headline.weight(.black))
            }
            HStack(spacing: 10) { rateValue(title: "بيع", value: rate?.sell); rateValue(title: "شراء", value: rate?.buy) }
            Divider()
            HStack {
                Text(rate.map { $0.sourceCurrency == "USD" && $0.destinationCurrency == "IQD" ? "الوحدة: دينار عراقي لكل 100 دولار" : "الوحدة: \($0.destinationCurrency) لكل \($0.sourceCurrency)" } ?? "الوحدة غير متاحة").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text(rate.map { "وقت المصدر: " + $0.sourceTimestamp.formatted(.dateTime.locale(Locale(identifier: "ar_IQ")).day().month(.abbreviated).year().hour().minute()) } ?? "لا توجد بيانات")
                    .font(.caption2).foregroundStyle(stale ? .red : .secondary)
            }
        }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 19))
            .overlay(RoundedRectangle(cornerRadius: 19).stroke(stale ? Color.red.opacity(0.25) : URColor.hairline))
    }

    private func rateValue(title: String, value: Decimal?) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Text(value?.formatted(.number.grouping(.automatic).precision(.fractionLength(0...2))) ?? "—")
                .font(.system(.title2, design: .rounded, weight: .black)).monospacedDigit().foregroundStyle(URColor.deepNavy)
        }.frame(maxWidth: .infinity, alignment: .trailing).padding(12).background(URColor.premiumGold.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    }

    private var primaryActions: some View {
        HStack(spacing: 10) {
            NavigationLink { CustomerRemittanceView() } label: {
                Label("حوالاتي", systemImage: "clock.arrow.circlepath").frame(maxWidth: .infinity, minHeight: 52)
                    .background(.white, in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(URColor.deepNavy.opacity(0.18)))
            }
            NavigationLink { URNativeTransferForm() } label: {
                Label("حوالة جديدة", systemImage: "plus.circle.fill").frame(maxWidth: .infinity, minHeight: 52).background(URColor.premiumGold, in: RoundedRectangle(cornerRadius: 15))
            }
        }.font(.headline.weight(.black)).foregroundStyle(URColor.deepNavy)
    }

    @ViewBuilder private var orderCard: some View {
        if loadingOrder { HStack { ProgressView(); Text("جاري تحديث طلبك…") }.font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding() }
        else if let order = openOrder {
            NavigationLink { URNativeOrderView(order: order, api: customerAPI) } label: {
                let status = homeText(order, "status")
                VStack(alignment: .trailing, spacing: 10) {
                    HStack { Image(systemName: "chevron.left").foregroundStyle(.secondary); Spacer(); Text("طلبك المفتوح").font(.headline.weight(.black)); Image(systemName: "doc.text.fill").foregroundStyle(URColor.premiumGold) }
                    HStack { Text(homeShortID(homeText(order, "id"))).font(.caption.monospaced()); Spacer(); Text(homeStatus(status)).font(.subheadline.weight(.black)).foregroundStyle(URColor.royalBlue) }
                    Text(homeNextStep(status)).font(.subheadline.weight(.bold)).foregroundStyle(URColor.deepNavy).frame(maxWidth: .infinity, alignment: .trailing)
                }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(URColor.premiumGold.opacity(0.45)))
            }.buttonStyle(.plain)
        } else if !customerAPI.profile.isEmpty {
            HStack { Spacer(); Label("لا توجد حوالة مفتوحة", systemImage: "checkmark.circle.fill") }.font(.subheadline.weight(.bold)).foregroundStyle(URColor.success).padding(14).frame(maxWidth: .infinity).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var shortcuts: some View {
        VStack(alignment: .trailing, spacing: 9) {
            Text("وصول سريع").font(.headline.weight(.black)).foregroundStyle(URColor.deepNavy)
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 9) {
                NavigationLink { RatesView(repository: repository) } label: { shortcut("الأسعار", "chart.line.uptrend.xyaxis") }
                NavigationLink { OfficesView(api: api) } label: { shortcut("المراكز", "mappin.and.ellipse") }
                NavigationLink { CalculatorView(repository: repository) } label: { shortcut("الحاسبة", "function") }
                NavigationLink { SupportView(repository: repository, api: api) } label: { shortcut("الدعم", "headphones") }
            }
        }
    }
    private func shortcut(_ title: String, _ symbol: String) -> some View { HStack { Spacer(); Text(title).font(.subheadline.weight(.bold)); Image(systemName: symbol).foregroundStyle(URColor.premiumGold).frame(width: 28) }.foregroundStyle(URColor.deepNavy).padding(13).frame(minHeight: 50).background(.white, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(URColor.hairline)) }
    private func retryCard(_ text: String, action: @escaping () async -> Void) -> some View { HStack(spacing: 10) { Button("إعادة المحاولة") { Task { await action() } }.font(.caption.weight(.black)); Spacer(); Text(text).font(.caption).multilineTextAlignment(.trailing); Image(systemName: "wifi.exclamationmark") }.foregroundStyle(.red).padding(13).background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 14)) }
    private func statusPill(_ text: String, color: Color) -> some View { Text(text).font(.caption2.weight(.black)).foregroundStyle(color).padding(.horizontal, 8).padding(.vertical, 5).background(color.opacity(0.10), in: Capsule()) }

    private func refresh() async { async let rates: Void = loadRates(); async let order: Void = loadOrder(); _ = await (rates, order) }
    private func loadRates() async { guard !loadingRates else { return }; loadingRates = true; defer { loadingRates = false }; do { snapshot = try await repository.loadRates(); rateError = "" } catch { rateError = "تعذر تحديث الأسعار. بقية الصفحة ما زالت متاحة." } }
    private func loadOrder() async {
        guard !loadingOrder else { return }; loadingOrder = true; defer { loadingOrder = false }
        guard !customerAPI.profile.isEmpty else { openOrder = nil; orderError = ""; return }
        do { let rows = try await customerAPI.request("/api/customer/checkout")["orders"] as? [[String: Any]] ?? []; openOrder = rows.first { !["delivered", "cancelled", "rejected"].contains(homeText($0, "status")) }; orderError = "" }
        catch { orderError = "تعذر تحديث الحوالة المفتوحة. الأسعار والاختصارات ما زالت تعمل." }
    }
}

private func homeText(_ row: [String: Any], _ key: String) -> String { guard let value = row[key], !(value is NSNull) else { return "" }; return String(describing: value) }
private func homeShortID(_ id: String) -> String { id.count > 12 ? "…" + id.suffix(8) : id }
private func homeStatus(_ status: String) -> String { switch status { case "awaiting_payment": return "بانتظار الدفع"; case "payment_review": return "الإثبات قيد المراجعة"; case "needs_more_info": return "مطلوب تصحيح"; case "payment_confirmed": return "تم اعتماد القبض"; case "processing": return "قيد التنفيذ"; default: return status.isEmpty ? "قيد المتابعة" : status } }
private func homeNextStep(_ status: String) -> String { switch status { case "awaiting_payment": return "الخطوة المطلوبة: أرفق إثبات الدفع"; case "payment_review": return "لا يلزم إجراء الآن؛ الإدارة تراجع الإثبات"; case "needs_more_info": return "الخطوة المطلوبة: افتح الطلب وصحح الإثبات"; case "payment_confirmed", "processing": return "تابع حالة تنفيذ الحوالة"; default: return "افتح الطلب لمعرفة الخطوة التالية" } }
