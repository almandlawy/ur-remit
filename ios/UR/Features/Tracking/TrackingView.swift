import SwiftUI

struct TrackingView: View {
    private enum TrackingMode: String, CaseIterable, Identifiable {
        case transfer = "متابعة الحوالة"
        case receipt = "متابعة الإيصال"
        var id: String { rawValue }
        var symbol: String { self == .transfer ? "arrow.left.arrow.right.circle.fill" : "doc.text.magnifyingglass" }
    }

    let api: any APIClient
    @Environment(\.openURL) private var openURL
    @FocusState private var referenceFocused: Bool
    @State private var mode: TrackingMode = .transfer
    @State private var reference = ""
    @State private var result: TransferTracking?
    @State private var message = ""
    @State private var loading = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                heroBanner
                modePicker
                trackingForm
                if loading { loadingCard }
                if let result { resultCard(result) }
                if !message.isEmpty { errorCard }
                supportCard
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(URColor.ivory.ignoresSafeArea())
        .navigationTitle("حوالاتي")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroBanner: some View {
        ZStack(alignment: .trailing) {
            Image("MyTransfersHero")
                .resizable().scaledToFill()
                .frame(height: 188).frame(maxWidth: .infinity).clipped()
            LinearGradient(colors: [.clear, URColor.deepNavy.opacity(0.35), URColor.deepNavy.opacity(0.96)], startPoint: .leading, endPoint: .trailing)
            VStack(alignment: .trailing, spacing: 7) {
                Label("UR GLOBAL", systemImage: "shield.checkered")
                    .font(.caption.weight(.black)).foregroundStyle(URColor.premiumGold)
                Text("حوالاتي").font(.system(size: 31, weight: .black, design: .rounded))
                Text("متابعة الحوالات والإيصالات\nبوضوح وأمان من مكان واحد")
                    .font(.subheadline.weight(.semibold)).multilineTextAlignment(.trailing).foregroundStyle(.white.opacity(0.84))
                HStack(spacing: 6) {
                    heroPill("تحديث مباشر", "bolt.fill")
                    heroPill("تتبّع آمن", "lock.shield.fill")
                }
            }
            .foregroundStyle(.white).padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(URColor.premiumGold.opacity(0.42)))
        .shadow(color: URColor.deepNavy.opacity(0.18), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
    }

    private func heroPill(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 9, weight: .bold)).padding(.horizontal, 9).frame(height: 25)
            .background(.white.opacity(0.13), in: Capsule())
    }

    private var modePicker: some View {
        HStack(spacing: 7) {
            ForEach(TrackingMode.allCases) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { mode = item; message = ""; result = nil }
                    referenceFocused = true
                } label: {
                    Label(item.rawValue, systemImage: item.symbol)
                        .font(.system(size: 12, weight: .black)).frame(maxWidth: .infinity).frame(height: 42)
                        .foregroundStyle(mode == item ? .white : URColor.deepNavy)
                        .background(mode == item ? URColor.royalBlue : .white.opacity(0.86), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5).background(URColor.deepNavy.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    private var trackingForm: some View {
        URCard {
            VStack(alignment: .trailing, spacing: 13) {
                HStack(spacing: 10) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(mode == .transfer ? "رقم الحوالة" : "رقم الإيصال").font(.headline.weight(.black)).foregroundStyle(URColor.deepNavy)
                        Text("موجود أعلى إيصال UR ويبدأ عادةً بـ UR-").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: mode.symbol).font(.system(size: 26, weight: .bold)).foregroundStyle(URColor.premiumGold)
                        .frame(width: 48, height: 48).background(URColor.deepNavy, in: RoundedRectangle(cornerRadius: 14))
                }

                HStack(spacing: 10) {
                    if !reference.isEmpty {
                        Button { reference = ""; result = nil; message = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain)
                    }
                    TextField("UR-XXXXXXXX", text: $reference)
                        .focused($referenceFocused).textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .multilineTextAlignment(.center).font(.system(size: 20, weight: .black, design: .monospaced))
                        .onChange(of: reference) { _, newValue in
                            reference = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }.prefix(11))
                        }
                    Image(systemName: validReference ? "checkmark.seal.fill" : "number.square.fill")
                        .foregroundStyle(validReference ? URColor.success : URColor.premiumGold)
                }
                .padding(.horizontal, 14).frame(height: 58).background(URColor.ivory, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(validReference ? URColor.success.opacity(0.5) : URColor.hairline, lineWidth: 1.2))

                Button { referenceFocused = false; Task { await track() } } label: {
                    HStack {
                        if loading { ProgressView().tint(.white) }
                        Text(loading ? "جارٍ التحقق…" : mode.rawValue)
                        Image(systemName: "arrow.left")
                    }
                }
                .buttonStyle(URPrimaryButtonStyle()).disabled(loading || !validReference)

                if !reference.isEmpty && !validReference {
                    Label("اكتب UR- وبعدها 8 أحرف أو أرقام", systemImage: "info.circle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView().tint(URColor.royalBlue)
            VStack(alignment: .trailing, spacing: 2) {
                Text("نراجع آخر حالة").font(.subheadline.weight(.black))
                Text("الاتصال الآمن بخدمة التتبع…").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16).background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 16))
    }

    private func resultCard(_ transfer: TransferTracking) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(statusLabel(transfer.status)).font(.headline.weight(.black))
                    Text(transfer.reference).font(.caption.monospaced().weight(.bold)).opacity(0.74)
                }
                Spacer()
                Image(systemName: statusSymbol(transfer.status)).font(.system(size: 25, weight: .bold))
                    .frame(width: 48, height: 48).background(.white.opacity(0.17), in: Circle())
            }
            .foregroundStyle(.white).padding(16).background(statusColor(transfer.status))

            VStack(spacing: 14) {
                routeSummary(transfer)
                statusTimeline(transfer.status)
                Divider()
                detail("آخر تحديث", transfer.lastUpdate.formatted(date: .abbreviated, time: .shortened), "clock.fill")
                if let estimated = transfer.estimatedCompletion {
                    detail("الوقت المتوقع", estimated.formatted(date: .abbreviated, time: .shortened), "calendar.badge.clock")
                }
                ShareLink(item: shareText(transfer)) {
                    Label("مشاركة تفاصيل المتابعة", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.bold)).foregroundStyle(URColor.royalBlue).frame(maxWidth: .infinity).frame(height: 42)
                        .background(URColor.royalBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(16).background(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 19)).overlay(RoundedRectangle(cornerRadius: 19).stroke(URColor.hairline))
        .shadow(color: URColor.deepNavy.opacity(0.08), radius: 12, y: 5)
    }

    private func routeSummary(_ transfer: TransferTracking) -> some View {
        HStack(spacing: 10) {
            location(transfer.origin, "نقطة الإرسال", "paperplane.fill")
            Image(systemName: "arrow.left").font(.headline.weight(.black)).foregroundStyle(URColor.premiumGold)
            location(transfer.destination, "الوجهة", "mappin.and.ellipse")
        }
    }

    private func location(_ name: String, _ caption: String, _ symbol: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).foregroundStyle(URColor.royalBlue)
            Text(name).font(.subheadline.weight(.black)).lineLimit(1)
            Text(caption).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 82).background(URColor.ivory, in: RoundedRectangle(cornerRadius: 13))
    }

    private func statusTimeline(_ status: String) -> some View {
        let steps = ["ISSUED", "ASSIGNED", "READY_FOR_PICKUP", "COMPLETED"]
        let activeIndex = steps.firstIndex(of: status) ?? (status == "COMPLETED" ? 3 : 0)
        return HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                VStack(spacing: 5) {
                    ZStack {
                        Circle().fill(index <= activeIndex ? URColor.royalBlue : URColor.deepNavy.opacity(0.10)).frame(width: 25, height: 25)
                        Image(systemName: index < activeIndex ? "checkmark" : statusSymbol(step)).font(.system(size: 9, weight: .black))
                            .foregroundStyle(index <= activeIndex ? .white : .secondary)
                    }
                    Text(shortStatus(step)).font(.system(size: 8, weight: .bold)).lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                if index < steps.count - 1 {
                    Rectangle().fill(index < activeIndex ? URColor.royalBlue : URColor.deepNavy.opacity(0.10)).frame(height: 2).offset(y: -8)
                }
            }
        }
    }

    private var errorCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .trailing, spacing: 3) {
                Text("ما حصلنا نتيجة").font(.subheadline.weight(.black)).foregroundStyle(URColor.deepNavy)
                Text(message).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
            Spacer()
            Image(systemName: "exclamationmark.magnifyingglass").font(.title2).foregroundStyle(.orange)
        }
        .padding(16).background(.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.orange.opacity(0.23)))
    }

    private var supportCard: some View {
        Button {
            guard let url = URL(string: "https://wa.me/971551754032?text=%D9%85%D8%B1%D8%AD%D8%A8%D8%A7%D9%8B%20%D8%AF%D8%B9%D9%85%20UR%20Global%D8%8C%20%D8%A3%D8%AD%D8%AA%D8%A7%D8%AC%20%D9%85%D8%B3%D8%A7%D8%B9%D8%AF%D8%A9%20%D8%A8%D8%AA%D8%AA%D8%A8%D8%B9%20%D8%AD%D9%88%D8%A7%D9%84%D8%A9") else { return }
            openURL(url)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("تحتاج مساعدة؟").font(.subheadline.weight(.black))
                    Text("تواصل مع دعم أور عبر واتساب دبي").font(.caption).opacity(0.78)
                }
                Spacer()
                Image(systemName: "message.fill").font(.title2)
            }
            .foregroundStyle(.white).padding(16)
            .background(LinearGradient(colors: [Color(red: 0.03, green: 0.60, blue: 0.32), Color(red: 0.02, green: 0.42, blue: 0.23)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(.plain)
    }

    private func detail(_ label: String, _ value: String, _ symbol: String) -> some View {
        HStack {
            Text(value).foregroundStyle(URColor.deepNavy).fontWeight(.semibold)
            Spacer()
            Label(label, systemImage: symbol).foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private var validReference: Bool { reference.range(of: #"^UR-[A-Z0-9]{8}$"#, options: .regularExpression) != nil }

    private func track() async {
        loading = true; message = ""; result = nil
        defer { loading = false }
        do { result = try await api.track(reference: reference) }
        catch { message = "تأكد من رقم UR ثم حاول مرة ثانية، أو تواصل مع الدعم إذا استمرت المشكلة." }
    }

    private func statusLabel(_ value: String) -> String {
        ["ISSUED":"تم إصدار الحوالة","ASSIGNED":"تم تعيين جهة التنفيذ","READY_FOR_PICKUP":"جاهزة للاستلام","COMPLETED":"تم تسليم الحوالة","CANCELLED":"الحوالة ملغاة","REFUNDED":"تم استردادها","HELD":"قيد المراجعة"][value] ?? value
    }

    private func shortStatus(_ value: String) -> String {
        ["ISSUED":"صدرت","ASSIGNED":"تعيين","READY_FOR_PICKUP":"جاهزة","COMPLETED":"مكتملة"][value] ?? value
    }

    private func statusSymbol(_ value: String) -> String {
        switch value {
        case "COMPLETED": return "checkmark.seal.fill"
        case "HELD": return "exclamationmark.shield.fill"
        case "CANCELLED", "REFUNDED": return "xmark.octagon.fill"
        case "READY_FOR_PICKUP": return "shippingbox.fill"
        case "ASSIGNED": return "person.crop.circle.badge.checkmark"
        default: return "doc.badge.clock"
        }
    }

    private func statusColor(_ value: String) -> Color {
        switch value {
        case "COMPLETED": return URColor.success
        case "HELD": return .orange
        case "CANCELLED", "REFUNDED": return URColor.error
        default: return URColor.royalBlue
        }
    }

    private func shareText(_ transfer: TransferTracking) -> String {
        """
        UR Global — متابعة الحوالة
        الرقم: \(transfer.reference)
        الحالة: \(statusLabel(transfer.status))
        من: \(transfer.origin)
        إلى: \(transfer.destination)
        آخر تحديث: \(transfer.lastUpdate.formatted(date: .abbreviated, time: .shortened))
        """
    }
}
