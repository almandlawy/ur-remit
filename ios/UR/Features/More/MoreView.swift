import SwiftUI
import SafariServices

struct MoreView: View {
    let api: any APIClient
    @EnvironmentObject private var auth: URAuthService
    @State private var adminTapCount = 0
    @State private var showAdminLogin = false
    @State private var showTransferCheckout = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        URIconBadge(symbol: "ellipsis", size: 46)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("المزيد")
                                .font(.title2.weight(.black))
                                .foregroundStyle(URColor.deepNavy)
                            Text("حسابك وإعدادات UR")
                                .font(.caption)
                                .foregroundStyle(URColor.deepNavy.opacity(0.60))
                        }
                        Spacer()
                        Button {
                            adminTapCount += 1
                            guard adminTapCount == 5 else { return }
                            adminTapCount = 0
                            showAdminLogin = true
                        } label: {
                            Text("UR")
                                .font(.title.weight(.black))
                                .foregroundStyle(URColor.deepNavy)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("UR")
                    }
                NavigationLink { AccountView() } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "chevron.left").font(.caption.weight(.bold)); Spacer()
                        VStack(alignment: .trailing, spacing: 3) { Text(auth.isAuthenticated ? "حسابي" : "تسجيل الدخول الاختياري").font(.headline.weight(.bold)); Text("احفظ تفضيلاتك وزامن بياناتك").font(.caption).foregroundStyle(.secondary) }
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 38)).foregroundStyle(URColor.royalBlue)
                    }.padding(16).foregroundStyle(URColor.deepNavy).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(URColor.hairline))
                }
                MoreGroup(title: "الخدمات") {
                    Button { showTransferCheckout = true } label: { MoreRow("طلب حوالة والدفع والوصولات", "arrow.left.arrow.right.circle.fill") }
                    Divider()
                    NavigationLink { OfficesView(api: api) } label: { MoreRow("المراكز المعتمدة", "building.2.fill") }
                    Divider(); NavigationLink { DailyReminderView() } label: { MoreRow("تذكير يومي بالأسعار", "bell.badge.fill") }
                    Divider(); NavigationLink { SecurityCenterView() } label: { MoreRow("عن الأسعار", "info.circle.fill") }
                    Divider(); NavigationLink { SecurityCenterView() } label: { MoreRow("مركز الأمان", "lock.shield.fill") }
                }
                MoreGroup(title: "حول UR") {
                    Link(destination: URL(string: "https://urremit.com/privacy")!) { MoreRow("سياسة الخصوصية", "hand.raised.fill") }
                    Divider(); Link(destination: URL(string: "https://urremit.com/terms")!) { MoreRow("الشروط والأحكام", "doc.text.fill") }
                    Divider(); Link(destination: URL(string: "https://urremit.com/contact")!) { MoreRow("اتصل بنا", "phone.fill") }
                }
                Text("UR Remit  •  الإصدار \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")").font(.caption2).foregroundStyle(.secondary).padding(.top, 8)
            }.padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 14)
        }
        .background(URColor.ivory.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showTransferCheckout) {
            URCustomerTransferBrowser().ignoresSafeArea()
        }
        .sheet(isPresented: $showAdminLogin) {
            NavigationStack {
                AdminEntryView()
            }
        }
    }
}

private struct MoreGroup<Content: View>: View {
    let title: String; @ViewBuilder let content: Content
    var body: some View { VStack(alignment: .trailing, spacing: 8) { Text(title).font(.caption.weight(.bold)).foregroundStyle(.secondary).padding(.trailing, 5); VStack(spacing: 0) { content }.padding(.horizontal, 14).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(URColor.hairline)) } }
}

private struct MoreRow: View {
    let title: String; let symbol: String
    init(_ title: String, _ symbol: String) { self.title = title; self.symbol = symbol }
    var body: some View { HStack { Image(systemName: "chevron.left").font(.caption2.weight(.bold)).foregroundStyle(.secondary); Spacer(); Text(title).font(.subheadline.weight(.semibold)); Image(systemName: symbol).foregroundStyle(URColor.premiumGold).frame(width: 28) }.foregroundStyle(URColor.deepNavy).frame(height: 52) }
}

struct OfficesView: View {
    let api: any APIClient
    @State private var offices: [Office] = Self.fallbackOffices
    @State private var isLoading = true
    @State private var isOffline = false

    private static let fallbackOffices: [Office] = [
        Office(id: UUID(uuidString: "23D82D9A-BD74-4E5D-9FD9-70AE08CFB701")!, publicCode: "UR-DXB-HQ", nameArabic: "المكتب الإداري - دبي", nameEnglish: "Dubai Administrative Office", countryArabic: "الإمارات العربية المتحدة", countryEnglish: "United Arab Emirates", cityArabic: "دبي", cityEnglish: "Dubai", addressArabic: "داماك بزنس تاور 4، الوحدة 2405، دبي مارينا", addressEnglish: "DAMAC Business Tower 4, Unit 2405, Dubai Marina", latitude: nil, longitude: nil, phone: nil, whatsapp: nil, verified: true),
        Office(id: UUID(uuidString: "75BB6446-599F-4C57-815A-45FCD72B39FD")!, publicCode: "UR-BGW-01", nameArabic: "نقطة تمويل أور - بغداد", nameEnglish: "UR Funding Point - Baghdad", countryArabic: "العراق", countryEnglish: "Iraq", cityArabic: "بغداد", cityEnglish: "Baghdad", addressArabic: "حي البلديات، شارع الصحفيين، بغداد", addressEnglish: "Al-Baladiyat, Al-Sahafiyin Street, Baghdad", latitude: nil, longitude: nil, phone: nil, whatsapp: nil, verified: true)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                URPageTitle(title: "مراكزنا", subtitle: "مراكز ووكلاء UR المعتمدون", symbol: "mappin.and.ellipse")
                HStack(spacing: 12) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("الدليل الرسمي المباشر").font(.subheadline.weight(.black))
                        Text(isOffline ? "نعرض الدليل المحفوظ لحين عودة الاتصال" : "أي مكتب يُضاف إلى نظام UR يظهر هنا تلقائياً").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(spacing: 5) {
                        URIconBadge(symbol: "building.2.crop.circle.fill", size: 48)
                        Text(offices.count == 2 ? "مركزان" : "\(offices.count) مراكز")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(URColor.deepNavy)
                    }
                }
                .padding(14).background(URColor.premiumGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                if isOffline {
                    HStack(spacing: 10) {
                        Button("إعادة المحاولة") { Task { await loadOffices() } }.font(.caption.weight(.bold)).foregroundStyle(URColor.royalBlue)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) { Text("الاتصال غير متاح").font(.caption.weight(.bold)); Text("يمكنك متابعة تصفح المراكز المحفوظة").font(.caption2).foregroundStyle(.secondary) }
                        Image(systemName: "wifi.slash").foregroundStyle(.orange)
                    }
                    .padding(11)
                    .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(.orange.opacity(0.22)))
                } else if isLoading {
                    HStack { ProgressView(); Text("تحديث دليل المراكز…").font(.caption).foregroundStyle(.secondary) }.padding(.vertical, 4)
                }
                ForEach(offices) { office in
                    OfficeCard(office: office)
                }
                NavigationLink { ServiceDestinationsView() } label: {
                    HStack { Image(systemName: "chevron.left"); Spacer(); VStack(alignment: .trailing, spacing: 3) { Text("شبكة الأسعار العالمية").font(.headline.weight(.bold)); Text("دول ومدن تتوفر لها معلومات سعرية إرشادية").font(.caption).foregroundStyle(.secondary) }; Image(systemName: "globe.europe.africa.fill").font(.title2).foregroundStyle(URColor.premiumGold) }
                        .foregroundStyle(URColor.deepNavy).padding(16).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(URColor.hairline))
                }
            }.padding(14)
        }
        .background(URColor.ivory.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        .task { await loadOffices() }
    }

    private func loadOffices() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let remote = try await api.offices()
            if !remote.isEmpty { offices = remote }
            isOffline = false
        } catch {
            if offices.isEmpty { offices = Self.fallbackOffices }
            isOffline = true
        }
    }
}

private struct OfficeCard: View {
    let office: Office

    var body: some View {
        URCard {
            VStack(alignment: .trailing, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    if office.verified {
                        Label("معتمد", systemImage: "checkmark.seal.fill").font(.caption2.weight(.bold)).foregroundStyle(URColor.success)
                            .padding(.horizontal, 9).padding(.vertical, 6).background(URColor.success.opacity(0.09), in: Capsule())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(office.nameArabic).font(.headline.weight(.black)).foregroundStyle(URColor.deepNavy)
                        Text(office.publicCode).font(.caption2.monospaced().weight(.semibold)).foregroundStyle(.secondary)
                    }
                    URIconBadge(symbol: office.countryArabic == "العراق" ? "building.columns.fill" : "building.2.fill", size: 48, tint: .white, background: URColor.royalBlue)
                }
                Divider()
                Label("\(office.cityArabic)، \(office.countryArabic)", systemImage: "mappin.circle.fill").font(.subheadline.weight(.bold)).foregroundStyle(URColor.deepNavy)
                Text(office.addressArabic).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing).frame(maxWidth: .infinity, alignment: .trailing)
                HStack(spacing: 8) {
                    if let phone = office.phone, let url = URL(string: "tel:\(phone)") {
                        Link(destination: url) { Label("اتصال", systemImage: "phone.fill").frame(maxWidth: .infinity, minHeight: 40).background(URColor.deepNavy, in: RoundedRectangle(cornerRadius: 11)).foregroundStyle(.white) }
                    }
                    if let latitude = office.latitude, let longitude = office.longitude,
                       let mapURL = URL(string: "https://maps.apple.com/?ll=\(latitude),\(longitude)") {
                        Link(destination: mapURL) { Label("الخريطة", systemImage: "map.fill").frame(maxWidth: .infinity, minHeight: 40).background(URColor.premiumGold, in: RoundedRectangle(cornerRadius: 11)).foregroundStyle(URColor.deepNavy) }
                    }
                }.font(.caption.weight(.bold))
            }
        }
    }
}

private struct ServiceDestinationsView: View {
    private let groups: [(String, String, [String])] = [
        ("العراق", "🇮🇶", ["بغداد", "أربيل", "السليمانية", "البصرة", "الموصل", "كربلاء"]),
        ("الخليج", "🏙️", ["دبي", "السعودية", "الكويت", "قطر", "البحرين", "سلطنة عُمان"]),
        ("تركيا — نقاط خدمة", "🇹🇷", ["إسطنبول", "أنقرة", "غازي عنتاب"]),
        ("سوريا — المحافظات", "🇸🇾", ["دمشق", "ريف دمشق", "حلب", "حمص", "حماة", "اللاذقية", "طرطوس", "إدلب", "درعا", "السويداء", "دير الزور", "الرقة", "الحسكة", "القنيطرة"]),
        ("الشرق الأوسط", "🌍", ["طهران", "مشهد", "قم", "الأردن", "بيروت", "مصر"]),
        ("دولية", "🌐", ["مصر", "الصين", "بريطانيا", "فرنسا", "ألمانيا", "كندا"])
    ]
    var body: some View {
        ScrollView { VStack(spacing: 12) {
            URPageTitle(title: "شبكة الأسعار", subtitle: "معلومات إرشادية حسب الدولة والمدينة", symbol: "globe.europe.africa.fill")
            ForEach(groups, id: \.0) { group in
                URCard { VStack(alignment: .trailing, spacing: 10) {
                    HStack { Spacer(); Text(group.0).font(.headline.weight(.black)); Text(group.1).font(.title3) }
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 8) {
                        ForEach(group.2, id: \.self) { Text($0).font(.caption.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 36).background(URColor.ivory, in: RoundedRectangle(cornerRadius: 10)) }
                    }
                } }
            }
            Text("هذه قائمة معلومات سعرية وليست عرضًا لتنفيذ حوالة أو معاملة مالية. قد تتغير الأسعار حسب السوق والوقت.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
        }.padding(14) }.background(URColor.ivory.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline)
    }
}

struct AgentVerificationView: View {
    let api: any APIClient
    @State private var code = ""
    @State private var result: AgentVerification?
    @State private var loading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                URPageTitle(title: "تحقق من وكيل", subtitle: "تأكد من الاعتماد قبل تسليم المبلغ", symbol: "checkmark.shield.fill")
                URCard { VStack(alignment: .trailing, spacing: 12) {
                    Text("رمز الوكيل").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    TextField("أدخل الرمز", text: $code).autocorrectionDisabled().textInputAutocapitalization(.characters).multilineTextAlignment(.center).padding().background(URColor.ivory, in: RoundedRectangle(cornerRadius: 12))
                    Button(loading ? "جارٍ التحقق…" : "تحقق الآن") { Task { await verify() } }.buttonStyle(URPrimaryButtonStyle()).disabled(code.count < 4 || loading)
                } }
                if let result { Label(result.status == "VERIFIED" ? "وكيل معتمد" : "الوكيل غير معتمد", systemImage: result.status == "VERIFIED" ? "checkmark.seal.fill" : "xmark.shield.fill").font(.title3.weight(.black)).foregroundStyle(result.status == "VERIFIED" ? URColor.success : .red).padding(20).frame(maxWidth: .infinity).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 16)) }
                Label("لا تسلم أي مبلغ إلا بعد ظهور حالة «وكيل معتمد».", systemImage: "exclamationmark.shield.fill").font(.caption).foregroundStyle(.secondary).padding()
            }.padding(14)
        }.background(URColor.ivory.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline)
    }
    private func verify() async { loading = true; defer { loading = false }; result = try? await api.verifyAgent(code: code) }
}

struct SecurityCenterView: View {
    var body: some View {
        ScrollView { VStack(spacing: 12) {
            URPageTitle(title: "عن الأسعار", subtitle: "معلومات مهمة قبل استخدام البيانات", symbol: "info.circle.fill")
            SafetyRow("الأسعار المعروضة إرشادية وليست عرضًا ملزمًا", "chart.line.uptrend.xyaxis")
            SafetyRow("قد تتغير الأسعار حسب السوق والوقت", "clock.fill")
            SafetyRow("التطبيق لا ينفذ أو يعالج معاملات مالية", "checkmark.shield.fill")
            Link(destination: URL(string: "https://urremit.com/contact")!) { Label("الإبلاغ عن حساب مزيف", systemImage: "exclamationmark.bubble.fill").frame(maxWidth: .infinity, minHeight: 48).background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.red).font(.subheadline.weight(.bold)) }
        }.padding(14) }.background(URColor.ivory.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline)
    }
}

private struct SafetyRow: View {
    let title: String; let symbol: String
    init(_ title: String, _ symbol: String) { self.title = title; self.symbol = symbol }
    var body: some View { HStack { Spacer(); Text(title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.trailing); Image(systemName: symbol).font(.title3).foregroundStyle(URColor.success).frame(width: 42, height: 42).background(URColor.success.opacity(0.10), in: RoundedRectangle(cornerRadius: 12)) }.foregroundStyle(URColor.deepNavy).padding(14).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(URColor.hairline)) }
}


private struct URCustomerTransferBrowser: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: URL(string: "https://www.urremit.com/customer/transfers")!)
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
