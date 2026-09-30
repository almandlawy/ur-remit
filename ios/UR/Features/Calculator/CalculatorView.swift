import SwiftUI

enum TransferAmount {
    static func positiveDecimal(from text: String, locale: Locale) -> Decimal? {
        guard let amount = Decimal(string: text, locale: locale), amount > 0 else { return nil }
        return amount
    }
}

struct SupportView: View {
    let repository: any RatesRepository
    let api: any APIClient
    @State private var expandedFAQ: Int? = nil

    private let faqs: [(String, String)] = [
        ("شلون تتحدث الأسعار؟", "أسعار الصرف تُسحب من مصدر UR الرسمي وتتحدث تلقائياً كل دقيقة تقريباً. إذا انقطع الاتصال يعرض التطبيق آخر سعر محفوظ مع توضيح وقت آخر تحديث."),
        ("الحاسبة تعطي مبلغ نهائي؟", "لا، حاسبة العملات تقديرية فقط لمساعدتك على فهم القيمة التقريبية. السعر الفعلي والعمولة يُحددان عند التنفيذ الفعلي عبر أحد مراكز UR المعتمدة."),
        ("شلون أتأكد أن الوكيل معتمد؟", "استخدم صفحة «تحقق من وكيل» ضمن قسم المزيد وأدخل رمز الوكيل — لا تسلم أي مبلغ إلا بعد ظهور حالة «وكيل معتمد» بوضوح."),
        ("هل التطبيق ينفذ حوالات؟", "لا، هذا التطبيق معلوماتي بالكامل: يعرض الأسعار ومراكز UR، ولا يقوم بمعالجة أو تنفيذ أي معاملة مالية داخل التطبيق نفسه.")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                URPageTitle(title: "الدعم والمعلومات", subtitle: "نساعدك على فهم الأسعار", symbol: "headphones")
                NavigationLink { RatesView(repository: repository) } label: { SupportRow(title: "دليل الأسعار", detail: "تصفح أسعار الدول والمدن", symbol: "chart.bar.fill", color: URColor.royalBlue) }
                NavigationLink { CalculatorView(repository: repository) } label: { SupportRow(title: "حاسبة العملات", detail: "قارن القيمة بشكل تقديري", symbol: "function", color: URColor.premiumGold) }
                NavigationLink { OfficesView(api: api) } label: { SupportRow(title: "معلومات التواصل", detail: "الدليل العام ومعلومات المراكز", symbol: "info.circle.fill", color: URColor.success) }
                URCard {
                    VStack(alignment: .trailing, spacing: 12) {
                        Text("تحتاج مساعدة مباشرة؟").font(.headline.weight(.black)).foregroundStyle(URColor.deepNavy)
                        Text("فريق UR جاهز للإجابة عن استفسارات الأسعار والمعلومات العامة.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                        HStack(spacing: 10) {
                            Link(destination: URL(string: "https://urremit.com/contact")!) { Label("راسلنا", systemImage: "message.fill").frame(maxWidth: .infinity, minHeight: 43).background(URColor.deepNavy, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white) }
                            Link(destination: URL(string: "https://urremit.com/contact")!) { Label("اتصل بنا", systemImage: "phone.fill").frame(maxWidth: .infinity, minHeight: 43).background(URColor.premiumGold, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white) }
                        }.font(.caption.weight(.bold))
                    }
                }
                VStack(alignment: .trailing, spacing: 10) {
                    HStack { Spacer(); Text("الأسئلة الشائعة").font(.headline.weight(.black)).foregroundStyle(URColor.deepNavy) }
                    ForEach(faqs.indices, id: \.self) { index in
                        FAQRow(question: faqs[index].0, answer: faqs[index].1, isExpanded: expandedFAQ == index) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                expandedFAQ = expandedFAQ == index ? nil : index
                            }
                        }
                    }
                }
                HStack(spacing: 9) { Image(systemName: "info.circle"); Text("التطبيق معلوماتي ولا ينفذ أو يعالج أي معاملة مالية.") }
                    .font(.caption).foregroundStyle(URColor.deepNavy.opacity(0.65)).padding(14)
            }
            // Extra bottom padding clears the custom floating bottom navigation bar.
            .padding(14).padding(.bottom, 96 - 14)
        }
        .background(URColor.ivory.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
    }
}

private struct FAQRow: View {
    let question: String
    let answer: String
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Button(action: toggle) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(question).font(.subheadline.weight(.bold)).foregroundStyle(URColor.deepNavy).multilineTextAlignment(.trailing)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(question)
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(isExpanded ? "موسّع" : "مطوي")
            if isExpanded {
                Text(answer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(URColor.hairline))
    }
}



private struct SupportRow: View {
    let title: String; let detail: String; let symbol: String; let color: Color
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "chevron.left").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) { Text(title).font(.headline.weight(.bold)); Text(detail).font(.caption).foregroundStyle(.secondary) }
            Image(systemName: symbol).font(.system(size: 20, weight: .bold)).foregroundStyle(.white).frame(width: 46, height: 46).background(color, in: RoundedRectangle(cornerRadius: 14))
        }
        .foregroundStyle(URColor.deepNavy).padding(15).background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(URColor.hairline))
    }
}

struct CalculatorView: View {
    let repository: any RatesRepository
    @State private var rates: [Rate] = []
    @State private var selectedRateID: UUID?
    @State private var amount = ""
    @State private var loading = true
    @State private var loadFailed = false
    @State private var isFromCache = false
    @State private var cacheWriteFailed = false
    @State private var hasLoadedOnce = false
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isAmountFieldFocused: Bool

    /// Auto-refresh so admin rate updates reach the app without a manual pull-to-refresh.
    private static let autoRefreshInterval: TimeInterval = 60
    private let autoRefreshTimer = Timer.publish(every: autoRefreshInterval, on: .main, in: .common).autoconnect()

    private var selectedRate: Rate? { rates.first { $0.id == selectedRateID } }
    private var result: Decimal? {
        guard let rate = selectedRate,
              let value = TransferAmount.positiveDecimal(from: amount, locale: locale),
              let exchange = rate.sell ?? rate.buy else { return nil }
        return value * exchange
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                URPageTitle(title: "حاسبة العملات", subtitle: "مقارنة تقديرية حسب آخر سعر", symbol: "function")
                URCard {
                    VStack(alignment: .trailing, spacing: 14) {
                        Text("زوج العملات").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        Picker("المسار", selection: $selectedRateID) {
                            Text("اختر المسار").tag(UUID?.none)
                            ForEach(rates) { Text($0.displayName(locale: locale)).tag(Optional($0.id)) }
                        }.pickerStyle(.menu).tint(URColor.deepNavy).frame(maxWidth: .infinity, alignment: .trailing)
                        Divider()
                        Text("المبلغ بالدولار").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        HStack { Text("USD").font(.headline.weight(.black)).foregroundStyle(URColor.premiumGold); TextField("0.00", text: $amount).keyboardType(.decimalPad).font(.title2.weight(.bold)).multilineTextAlignment(.trailing).focused($isAmountFieldFocused).accessibilityLabel(Text("amount_to_convert")) }
                    }
                }
                if let rate = selectedRate, let result {
                    VStack(spacing: 9) {
                        Text("القيمة التقديرية").font(.caption).foregroundStyle(.white.opacity(0.70))
                        Text(result.formatted(.number.grouping(.automatic))).font(.system(size: 38, weight: .black, design: .rounded)).monospacedDigit()
                        Text(rate.destinationCurrency).font(.headline.weight(.bold)).foregroundStyle(URColor.premiumGold)
                        Divider().overlay(.white.opacity(0.20))
                        HStack { Text((rate.sell ?? rate.buy ?? 0).formatted()); Spacer(); Text("سعر الصرف") }.font(.caption).foregroundStyle(.white.opacity(0.72))
                        if isFromCache {
                            HStack { Image(systemName: "wifi.slash"); Text("أنت تشاهد آخر أسعار محفوظة") }.font(.caption2).foregroundStyle(.white.opacity(0.65))
                        }
                        if cacheWriteFailed {
                            HStack { Image(systemName: "externaldrive.badge.exclamationmark"); Text("تعذر حفظ الأسعار للاستخدام دون اتصال") }.font(.caption2).foregroundStyle(.white.opacity(0.65))
                        }
                        if rate.isStale() {
                            HStack { Image(systemName: "clock.badge.exclamationmark"); Text("قد يكون السعر قديماً") }.font(.caption2).foregroundStyle(.orange)
                        }
                    }
                    .foregroundStyle(.white).padding(20).frame(maxWidth: .infinity).background(URColor.deepNavy, in: RoundedRectangle(cornerRadius: 18))
                }
                if selectedRate != nil && !amount.isEmpty && result == nil {
                    Text("الرجاء إدخال مبلغ صحيح أكبر من صفر").font(.caption).foregroundStyle(.secondary)
                }
                if loadFailed && !rates.isEmpty {
                    VStack(spacing: 8) {
                        Label("تعذر تحديث الأسعار، تُعرض آخر بيانات محفوظة", systemImage: "wifi.exclamationmark").font(.caption).foregroundStyle(.secondary)
                        Button("إعادة المحاولة") { Task { await loadRates() } }.buttonStyle(URPrimaryButtonStyle())
                    }
                } else if loading {
                    ProgressView("جارٍ تحميل الأسعار…").padding()
                } else if rates.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: loadFailed ? "wifi.exclamationmark" : "function").font(.system(size: 34)).foregroundStyle(.secondary)
                        Text(loadFailed ? "تعذر تحميل الأسعار" : "لا توجد أسعار متاحة حالياً").font(.subheadline.weight(.bold))
                        Button("إعادة المحاولة") { Task { await loadRates() } }.buttonStyle(URPrimaryButtonStyle())
                    }.padding()
                }
                Text("الحسبة معلوماتية وتقريبية فقط، وقد يختلف السعر الفعلي حسب السوق والوقت.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding(14)
        }
        .background(URColor.ivory.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .numericKeyboardDoneToolbar(focused: $isAmountFieldFocused)
        .onTapGesture { isAmountFieldFocused = false }
        .task {
            await loadRates()
            hasLoadedOnce = true
        }
        .refreshable { await loadRates() }
        .onChange(of: scenePhase) { _, newPhase in
            guard hasLoadedOnce, newPhase == .active else { return }
            Task { await loadRates() }
        }
        .onReceive(autoRefreshTimer) { _ in
            guard hasLoadedOnce, scenePhase == .active else { return }
            Task { await loadRates() }
        }
    }

    private func loadRates() async {
        // Only show the full-screen loading state on the very first fetch; background
        // auto-refreshes (foreground/periodic) should update silently without flicker.
        if rates.isEmpty { loading = true }
        loadFailed = false
        defer { loading = false }
        do {
            let snapshot = try await repository.loadRates()
            rates = snapshot.rates.filter { $0.buy != nil || $0.sell != nil }
            if selectedRateID == nil { selectedRateID = rates.first?.id }
            isFromCache = snapshot.isFromCache
            cacheWriteFailed = snapshot.cacheWriteFailed
        } catch is CancellationError {
            return
        } catch {
            loadFailed = true
        }
    }
}
