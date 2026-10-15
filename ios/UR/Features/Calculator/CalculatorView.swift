import SwiftUI

struct SupportView: View {
    let repository: any RatesRepository
    let api: any APIClient
    @EnvironmentObject private var auth: URAuthService
    @ObservedObject private var customerAPI = URNativeAPI.customer
    @State private var tickets: [[String: Any]] = []
    @State private var messages: [[String: Any]] = []
    @State private var orders: [[String: Any]] = []
    @State private var category = "transfer"
    @State private var selectedOrder = ""
    @State private var details = ""
    @State private var notice = ""
    @State private var loading = false
    @State private var sending = false
    @FocusState private var detailsFocused: Bool

    private let categories = [("transfer", "حوالة أو تأخر استلام", "arrow.left.arrow.right"), ("payment", "دفع أو إثبات", "doc.badge.clock"), ("account", "حساب وتسجيل دخول", "person.crop.circle"), ("general", "استفسار عام", "questionmark.circle"), ("fraud", "إبلاغ عن احتيال", "exclamationmark.shield")]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .trailing, spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    Image("SupportHero").resizable().scaledToFill().frame(height: 170).clipped()
                    LinearGradient(colors: [.clear, URColor.deepNavy.opacity(0.96)], startPoint: .top, endPoint: .bottom)
                    HStack(alignment: .bottom) {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("بشنو نساعدك؟").font(.title2.weight(.black))
                            Text("تذكرتك توصل للفريق الصحيح وتبقى مرتبطة بطلبك").font(.caption).foregroundStyle(.white.opacity(0.82))
                        }
                        URBrandLogo(size: 42)
                    }.foregroundStyle(.white).padding(15)
                }.frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                if customerAPI.profile.isEmpty {
                    NavigationLink { URNativeAccountView() } label: { Label("سجّل الدخول لإنشاء ومتابعة تذكرة", systemImage: "person.crop.circle.badge.checkmark").font(.headline.weight(.black)).frame(maxWidth: .infinity, minHeight: 54).background(URColor.premiumGold, in: RoundedRectangle(cornerRadius: 15)).foregroundStyle(URColor.deepNavy) }
                    supportFallback
                } else {
                    categoryGrid
                    newTicketCard
                    HStack { Spacer(); Text("تذاكري").font(.title3.weight(.black)); Image(systemName: "text.bubble.fill").foregroundStyle(URColor.premiumGold) }
                    if loading { ProgressView("جاري تحديث التذاكر…").frame(maxWidth: .infinity).padding() }
                    if tickets.isEmpty && !loading { ContentUnavailableView("لا توجد تذاكر", systemImage: "bubble.left.and.bubble.right", description: Text("بعد حفظ التذكرة بنجاح يظهر رقمها هنا.")) }
                    ForEach(tickets.indices, id: \.self) { index in NavigationLink { SupportTicketDetail(ticket: tickets[index], allMessages: messages, api: customerAPI, reload: { await load() }) } label: { ticketRow(tickets[index]) }.buttonStyle(.plain) }
                    supportFallback
                }
                if !notice.isEmpty { Text(notice).font(.caption.weight(.semibold)).foregroundStyle(notice.hasPrefix("تم") ? URColor.success : .red).frame(maxWidth: .infinity, alignment: .trailing).padding(12).background(.white, in: RoundedRectangle(cornerRadius: 12)) }
            }.padding(14)
        }
        .background(URColor.ivory.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar).environment(\.layoutDirection, .rightToLeft)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("تم") { detailsFocused = false } } }
        .task(id: auth.isAuthenticated) { await customerAPI.resumeCustomerAccount(appEmail: auth.isAuthenticated ? auth.email : nil); await load() }
        .refreshable { await load() }
    }

    private var categoryGrid: some View { LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 9) { ForEach(categories, id: \.0) { item in Button { category = item.0; if item.0 != "transfer" && item.0 != "payment" { selectedOrder = "" } } label: { HStack { Spacer(); Text(item.1).font(.caption.weight(.bold)).multilineTextAlignment(.trailing); Image(systemName: item.2) }.foregroundStyle(category == item.0 ? .white : URColor.deepNavy).padding(12).frame(maxWidth: .infinity, minHeight: 54).background(category == item.0 ? URColor.deepNavy : .white, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(category == item.0 ? URColor.premiumGold : URColor.hairline)) }.buttonStyle(.plain) } } }
    private var newTicketCard: some View { VStack(alignment: .trailing, spacing: 12) {
        if category == "transfer" || category == "payment" { Picker("الطلب المرتبط", selection: $selectedOrder) { Text("اختر طلبك").tag(""); ForEach(orders.indices, id: \.self) { index in Text("طلب " + supportShortID(supportText(orders[index], "id"))).tag(supportText(orders[index], "id")) } }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .trailing); Text("نربط التذكرة بالطلب المختار ولا نطلب منك إعادة كتابة بياناته.").font(.caption2).foregroundStyle(.secondary) }
        Text(categoryPrompt).font(.subheadline.weight(.bold))
        TextEditor(text: $details).focused($detailsFocused).frame(minHeight: 95).padding(8).background(URColor.ivory, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(URColor.hairline)).accessibilityLabel("تفاصيل المشكلة")
        Button(sending ? "جاري الحفظ…" : "إرسال التذكرة") { Task { await submit() } }.buttonStyle(URPrimaryButtonStyle()).disabled(sending || details.trimmingCharacters(in: .whitespacesAndNewlines).count < 5 || ((category == "transfer" || category == "payment") && selectedOrder.isEmpty))
    }.padding(15).background(.white, in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(URColor.hairline)) }
    private var categoryPrompt: String { switch category { case "transfer": return "شنو المشكلة بالحوالة أو الاستلام؟"; case "payment": return "شنو المشكلة بالدفع أو إثباته؟"; case "account": return "اشرح مشكلة الدخول بدون إرسال كلمة مرور أو رمز"; case "fraud": return "اذكر الواقعة بدون مشاركة كلمات المرور"; default: return "اكتب استفسارك باختصار" } }
    private var supportFallback: some View { VStack(alignment: .trailing, spacing: 6) { Text("إذا تعذر نظام التذاكر").font(.subheadline.weight(.black)); Link("افتح قناة التواصل المعتمدة", destination: URL(string: "https://urremit.com/contact")!).font(.subheadline.weight(.bold)); Text("ساعات الخدمة وقنواتها تظهر في صفحة التواصل المعتمدة؛ لا نفترض خدمة 24/7.").font(.caption).foregroundStyle(.secondary) }.padding(14).frame(maxWidth: .infinity, alignment: .trailing).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 14)) }
    private func ticketRow(_ ticket: [String: Any]) -> some View { HStack { Image(systemName: "chevron.left").foregroundStyle(.secondary); Spacer(); VStack(alignment: .trailing, spacing: 4) { Text(supportText(ticket, "subject")).font(.headline.weight(.bold)); Text(supportStatus(supportText(ticket, "status"))).font(.caption.weight(.bold)).foregroundStyle(URColor.royalBlue); Text(supportText(ticket, "id")).font(.caption2.monospaced()).foregroundStyle(.secondary) }; Image(systemName: "bubble.left.and.text.bubble.right.fill").foregroundStyle(URColor.premiumGold) }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(URColor.hairline)) }
    private func load() async { guard !customerAPI.profile.isEmpty else { tickets=[]; messages=[]; orders=[]; return }; loading=true; defer { loading=false }; do { let s=try await customerAPI.request("/api/customer/support"); let c=try await customerAPI.request("/api/customer/checkout"); tickets=s["tickets"] as? [[String:Any]] ?? []; messages=s["messages"] as? [[String:Any]] ?? []; orders=c["orders"] as? [[String:Any]] ?? []; notice="" } catch { notice="تعذر تحميل الدعم الآن. احتفظنا بمدخلاتك." } }
    private func submit() async { guard !sending else { return }; sending=true; defer { sending=false }; do { let key=UUID().uuidString; let result=try await customerAPI.request("/api/customer/support", method:"POST", body:["action":"ticket","category":category,"orderId":selectedOrder,"subject":categories.first(where:{$0.0==category})?.1 ?? "استفسار","description":details], idempotencyKey:key); guard let id=result["id"] as? String else { throw NSError(domain:"URSupport",code:1) }; details=""; notice="تم حفظ التذكرة رقم \(id)"; await load() } catch { notice=error.localizedDescription } }
}

private struct SupportTicketDetail: View {
    let ticket: [String: Any]; let allMessages: [[String: Any]]; @ObservedObject var api: URNativeAPI; let reload: () async -> Void
    @State private var reply=""; @State private var notice=""; @State private var busy=false
    @FocusState private var replyFocused: Bool
    private var rows: [[String:Any]] { allMessages.filter { supportText($0,"ticket_id") == supportText(ticket,"id") } }
    var body: some View { List { Section { LabeledContent("رقم التذكرة", value:supportText(ticket,"id")); LabeledContent("الحالة", value:supportStatus(supportText(ticket,"status"))); if !supportText(ticket,"order_id").isEmpty { LabeledContent("الطلب", value:supportShortID(supportText(ticket,"order_id"))) }; Text(supportText(ticket,"description")) }
        Section("التسلسل الزمني") { ForEach(rows.indices,id:\.self) { i in VStack(alignment:.trailing,spacing:5) { Text(supportText(rows[i],"sender_role") == "customer" ? "أنت" : "فريق أور").font(.caption.weight(.black)).foregroundStyle(URColor.royalBlue); Text(supportText(rows[i],"message")).frame(maxWidth:.infinity,alignment:.trailing) }.padding(.vertical,4) } }
        Section("رد جديد") { TextField("اكتب ردك…",text:$reply,axis:.vertical).focused($replyFocused).lineLimit(2...5); Button(busy ? "جاري الإرسال…" : "إرسال الرد") { Task { await send("reply") } }.disabled(busy || reply.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty); if supportText(ticket,"status") == "closed" { Button("إعادة فتح المشكلة") { Task { await send("reopen") } }.disabled(busy) }; if !notice.isEmpty { Text(notice).foregroundStyle(.red) } }
    }.navigationTitle("تفاصيل التذكرة").environment(\.layoutDirection,.rightToLeft)
        .toolbar { ToolbarItemGroup(placement:.keyboard) { Spacer(); Button("تم") { replyFocused = false } } }
    }
    private func send(_ action:String) async { busy=true; defer{busy=false}; do { _=try await api.request("/api/customer/support",method:"POST",body:["action":action,"ticketId":supportText(ticket,"id"),"message":reply],idempotencyKey:UUID().uuidString); reply=""; await reload(); notice="تم الإرسال" } catch { notice=error.localizedDescription } }
}

private func supportText(_ row:[String:Any],_ key:String)->String { guard let value=row[key],!(value is NSNull) else{return ""}; return String(describing:value) }
private func supportShortID(_ value:String)->String { value.count > 10 ? String(value.suffix(8)) : value }
private func supportStatus(_ value:String)->String { switch value { case "open": return "مفتوحة"; case "waiting_customer": return "ننتظر ردك"; case "in_progress": return "قيد المتابعة"; case "closed": return "مغلقة"; default:return value } }

struct CalculatorView: View {
    let repository: any RatesRepository
    @State private var rates: [Rate] = []
    @State private var selectedRateID: UUID?
    @State private var amount = ""
    @State private var loading = true
    @State private var isReverse = false

    private var selectedRate: Rate? { rates.first { $0.id == selectedRateID } }
    private var result: Decimal? {
        guard let rate = selectedRate, let value = Decimal(string: amount), let exchange = rate.sell ?? rate.buy else { return nil }
        return isReverse ? value / exchange : value * exchange
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
                            ForEach(rates) { Text($0.routeNameArabic).tag(Optional($0.id)) }
                        }.pickerStyle(.menu).tint(URColor.deepNavy).frame(maxWidth: .infinity, alignment: .trailing)
                        Divider()
                        HStack {
                            Button { withAnimation { isReverse.toggle(); amount = "" } } label: {
                                Label("تبديل", systemImage: "arrow.up.arrow.down.circle.fill")
                            }.buttonStyle(.bordered).tint(URColor.royalBlue)
                            Spacer()
                            Text(isReverse ? "المبلغ بالعملة المحلية" : "المبلغ بالدولار").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        }
                        HStack { Text(isReverse ? (selectedRate?.destinationCurrency ?? "LOCAL") : "USD").font(.headline.weight(.black)).foregroundStyle(URColor.premiumGold); TextField("0.00", text: $amount).keyboardType(.decimalPad).font(.title2.weight(.bold)).multilineTextAlignment(.trailing) }
                    }
                }
                if let rate = selectedRate, let result {
                    VStack(spacing: 9) {
                        Text("القيمة التقديرية").font(.caption).foregroundStyle(.white.opacity(0.70))
                        Text(result.formatted(.number.grouping(.automatic))).font(.system(size: 38, weight: .black, design: .rounded)).monospacedDigit()
                        Text(isReverse ? "USD" : rate.destinationCurrency).font(.headline.weight(.bold)).foregroundStyle(URColor.premiumGold)
                        Divider().overlay(.white.opacity(0.20))
                        HStack { Text((rate.sell ?? rate.buy ?? 0).formatted()); Spacer(); Text("سعر الصرف") }.font(.caption).foregroundStyle(.white.opacity(0.72))
                    }
                    .foregroundStyle(.white).padding(20).frame(maxWidth: .infinity).background(URColor.deepNavy, in: RoundedRectangle(cornerRadius: 18))
                }
                Text("الحسبة معلوماتية وتقريبية فقط، وقد يختلف السعر الفعلي حسب السوق والوقت.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding(14)
        }
        .background(URColor.ivory.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline)
        .task { defer { loading = false }; rates = ((try? await repository.loadRates())?.rates ?? []).filter { $0.buy != nil || $0.sell != nil }; selectedRateID = rates.first?.id }
    }
}
