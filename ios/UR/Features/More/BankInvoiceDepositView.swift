import SwiftUI
import PhotosUI
@preconcurrency import Vision
import PDFKit
import UniformTypeIdentifiers

struct BankInvoiceDepositView: View {
    @ObservedObject private var api = URNativeAPI.customer
    @State private var photo: PhotosPickerItem?
    @State private var showFile = false
    @State private var invoiceName = ""
    @State private var beneficiaryName = ""
    @State private var bankName = ""
    @State private var accountNumber = ""
    @State private var iban = ""
    @State private var swift = ""
    @State private var invoiceReference = ""
    @State private var invoiceAmount = ""
    @State private var invoiceCurrency = "USD"
    @State private var transferAmountUSD = ""
    @State private var method = ""
    @State private var methods: [[String: Any]] = []
    @State private var quote: [String: Any] = [:]
    @State private var order: [String: Any]?
    @State private var busy = false
    @State private var message = ""
    @State private var requestId = UUID().uuidString
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .trailing, spacing: 5) {
                    Label("إيداع فوري لحوالة بنكية", systemImage: "bolt.horizontal.circle.fill").font(.headline.weight(.black))
                    Text("ارفع فاتورة التحويل، راجع البيانات المستخرجة ثم أكمل إثبات الدفع. رفع الفاتورة وحده لا يعني تنفيذ الحوالة.")
                        .font(.caption).foregroundStyle(.white.opacity(0.82))
                }.foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .trailing).padding(16)
                    .background(LinearGradient(colors: [URColor.deepNavy, URColor.royalBlue], startPoint: .topTrailing, endPoint: .bottomLeading), in: RoundedRectangle(cornerRadius: 20))

                VStack(spacing: 10) {
                    HStack {
                        PhotosPicker(selection: $photo, matching: .images) { Label("صورة الفاتورة", systemImage: "photo") }
                        Spacer(); Button { showFile = true } label: { Label("PDF", systemImage: "doc.fill") }
                    }.buttonStyle(.bordered)
                    if !invoiceName.isEmpty { Label(invoiceName, systemImage: "checkmark.circle.fill").font(.caption.weight(.bold)).foregroundStyle(.green) }
                    Text("تتم قراءة الفاتورة على جهازك، ولا تُرسل النسخة الأصلية تلقائياً.").font(.caption2).foregroundStyle(.secondary)
                }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 18))

                VStack(spacing: 11) {
                    TextField("اسم المستفيد", text: $beneficiaryName).focused($focused)
                    TextField("اسم البنك المستلم", text: $bankName).focused($focused)
                    TextField("رقم الحساب", text: $accountNumber).textInputAutocapitalization(.characters).focused($focused)
                    TextField("IBAN", text: $iban).textInputAutocapitalization(.characters).autocorrectionDisabled().focused($focused)
                    TextField("SWIFT / BIC", text: $swift).textInputAutocapitalization(.characters).autocorrectionDisabled().focused($focused)
                    TextField("رقم/مرجع الفاتورة", text: $invoiceReference).focused($focused)
                    HStack { TextField("مبلغ الفاتورة", text: $invoiceAmount).keyboardType(.decimalPad).focused($focused); TextField("العملة", text: $invoiceCurrency).textInputAutocapitalization(.characters).frame(width: 76).focused($focused) }
                    if invoiceCurrency.uppercased() != "USD" {
                        Text("الفاتورة بعملة \(invoiceCurrency.uppercased()). الحوالة البنكية تُسوّى بالدولار؛ راجع واكتب مبلغ التحويل بالدولار ولا نعتمد تحويلاً تلقائياً بلا سعر خادمي موثق.")
                            .font(.caption).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    TextField("مبلغ الحوالة بالدولار USD", text: $transferAmountUSD).keyboardType(.decimalPad).focused($focused)
                    Picker("طريقة الدفع", selection: $method) { Text("اختر طريقة الدفع").tag(""); ForEach(methods.indices, id: \.self) { Text(bankText(methods[$0], "name")).tag(bankText(methods[$0], "id")) } }.pickerStyle(.menu)
                    Button(quote.isEmpty ? "احسب المبلغ والعمولة" : "تحديث الحسبة") { Task { await calculate() } }
                        .buttonStyle(.borderedProminent).tint(URColor.deepNavy).disabled(busy || method.isEmpty)
                }.textFieldStyle(.roundedBorder).padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))

                if !quote.isEmpty {
                    VStack(alignment: .trailing, spacing: 10) {
                        line("المبلغ", bankText(quote, "principal") + " " + bankText(quote, "currency"))
                        line("عمولة الحوالة", bankText(quote, "fee") + " USD")
                        line("الإجمالي المطلوب", bankText(quote, "total") + " " + bankText(quote, "paymentCurrency"))
                        Text("العمولة يحسبها الخادم لكل شريحة 10,000 دولار، ولا تُخصم مرتين عند إعادة المحاولة.").font(.caption2).foregroundStyle(.white.opacity(0.72))
                        Button("تأكيد البيانات والانتقال للدفع") { Task { await submit() } }.buttonStyle(.borderedProminent).tint(URColor.premiumGold).foregroundStyle(URColor.deepNavy).disabled(busy)
                    }.foregroundStyle(.white).padding(18).background(URColor.deepNavy, in: RoundedRectangle(cornerRadius: 20))
                }
                if let order { URNativeInlinePaymentCompletion(order: order, api: api) }
                if !message.isEmpty { Text(message).font(.footnote.weight(.semibold)).foregroundStyle(.red) }
            }.padding()
        }.background(URColor.ivory).navigationTitle("حوالة بنكية فورية").navigationBarTitleDisplayMode(.inline).environment(\.layoutDirection, .rightToLeft)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("تم") { focused = false } } }
            .task { await loadMethods() }.onChange(of: photo) { _, item in Task { await readPhoto(item) } }
            .fileImporter(isPresented: $showFile, allowedContentTypes: [.pdf, .jpeg, .png]) { result in Task { await readFile(result) } }
    }

    private func line(_ title: String, _ value: String) -> some View { HStack { Text(value).fontWeight(.black).environment(\.layoutDirection, .leftToRight); Spacer(); Text(title) } }
    private func loadMethods() async { do { methods = try await api.request("/api/payment-methods")["methods"] as? [[String: Any]] ?? []; if methods.count == 1 { method = bankText(methods[0], "id") } } catch { message = error.localizedDescription } }
    private func calculate() async { guard fieldsReady else { message = "راجع اسم المستفيد والبنك والحساب أو IBAN ومبلغ الحوالة بالدولار"; return }; busy = true; message = ""; defer { busy = false }; do { var c = URLComponents(); c.path = "/api/customer/bank-transfer-deposit"; c.queryItems = [.init(name: "amount", value: bankDigits(transferAmountUSD)), .init(name: "currency", value: "USD"), .init(name: "method", value: method)]; quote = try await api.request(c.string ?? "")["quote"] as? [String: Any] ?? [:] } catch { message = error.localizedDescription } }
    private func submit() async { guard fieldsReady else { message = "راجع البيانات المستخرجة أولاً"; return }; busy = true; message = ""; defer { busy = false }; do { let result = try await api.request("/api/customer/bank-transfer-deposit", method: "POST", body: ["id": requestId, "amount": bankDigits(transferAmountUSD), "currency": "USD", "method": method, "beneficiaryName": beneficiaryName, "bankName": bankName, "accountNumber": accountNumber, "iban": iban, "swift": swift, "invoiceReference": invoiceReference, "invoiceAmount": bankDigits(invoiceAmount), "invoiceCurrency": invoiceCurrency.uppercased()], idempotencyKey: requestId); guard result["success"] as? Bool == true else { throw BankDepositError.message("لم يؤكد الخادم حفظ الطلب") }; let rows = try await api.request("/api/customer/checkout")["orders"] as? [[String: Any]] ?? []; order = rows.first { bankText($0, "id") == requestId }; quote = [:] } catch { message = error.localizedDescription } }
    private var fieldsReady: Bool { beneficiaryName.count >= 3 && bankName.count >= 2 && (!accountNumber.isEmpty || !iban.isEmpty) && Decimal(string: bankDigits(transferAmountUSD)) != nil }
    private func readPhoto(_ item: PhotosPickerItem?) async { do { guard let data = try await item?.loadTransferable(type: Data.self), let image = UIImage(data: data), let cg = image.cgImage else { throw BankDepositError.message("تعذر قراءة الصورة") }; await recognize(cg, name: "تمت قراءة صورة الفاتورة") } catch { message = error.localizedDescription } }
    private func readFile(_ result: Result<URL, Error>) async { do { let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }; if url.pathExtension.lowercased() == "pdf", let page = PDFDocument(url: url)?.page(at: 0) { let image = page.thumbnail(of: CGSize(width: 1800, height: 2400), for: .mediaBox); guard let cg = image.cgImage else { throw BankDepositError.message("تعذر تجهيز PDF") }; await recognize(cg, name: url.lastPathComponent) } else { let data = try Data(contentsOf: url); guard let image = UIImage(data: data), let cg = image.cgImage else { throw BankDepositError.message("الملف غير مدعوم") }; await recognize(cg, name: url.lastPathComponent) } } catch { message = error.localizedDescription } }
    private func recognize(_ image: CGImage, name: String) async { busy = true; message = ""; defer { busy = false }; do { let text = try await BankInvoiceOCR.read(image); let fields = BankInvoiceOCR.extract(text); beneficiaryName = fields.beneficiary.isEmpty ? beneficiaryName : fields.beneficiary; bankName = fields.bank.isEmpty ? bankName : fields.bank; accountNumber = fields.account.isEmpty ? accountNumber : fields.account; iban = fields.iban.isEmpty ? iban : fields.iban; swift = fields.swift.isEmpty ? swift : fields.swift; invoiceReference = fields.reference.isEmpty ? invoiceReference : fields.reference; invoiceAmount = fields.amount.isEmpty ? invoiceAmount : fields.amount; invoiceCurrency = fields.currency.isEmpty ? invoiceCurrency : fields.currency; if fields.currency == "USD" { transferAmountUSD = fields.amount }; invoiceName = name; if text.isEmpty { message = "لم يظهر نص واضح؛ اكتب البيانات يدويًا" } else if fields.missing.isEmpty { message = "تم استخراج البيانات. راجعها قبل حساب العمولة." } else { message = "استخرجنا جزءاً من البيانات. راجع: \(fields.missing.joined(separator: "، "))" } } catch { message = error.localizedDescription } }
}

private enum BankDepositError: LocalizedError { case message(String); var errorDescription: String? { if case .message(let value) = self { value } else { nil } } }
private func bankText(_ object: [String: Any], _ key: String) -> String { if let value = object[key] as? String { return value }; if let value = object[key] as? NSNumber { return value.stringValue }; return "" }
private func bankDigits(_ value: String) -> String { value.replacingOccurrences(of: "٫", with: ".").replacingOccurrences(of: ",", with: "").filter { $0.isNumber || $0 == "." } }

enum BankInvoiceOCR {
    struct Fields { var beneficiary = ""; var bank = ""; var account = ""; var iban = ""; var swift = ""; var reference = ""; var amount = ""; var currency = ""; var missing: [String] { [(beneficiary.isEmpty ? "اسم المستفيد" : nil), (bank.isEmpty ? "اسم البنك" : nil), (iban.isEmpty && account.isEmpty ? "الحساب/IBAN" : nil), (swift.isEmpty ? "SWIFT/BIC" : nil), (amount.isEmpty ? "المبلغ" : nil), (currency.isEmpty ? "العملة" : nil)].compactMap { $0 } } }
    static func read(_ image: CGImage) async throws -> String { try await withCheckedThrowingContinuation { continuation in let request = VNRecognizeTextRequest { request, error in if let error { continuation.resume(throwing: error); return }; let lines = (request.results as? [VNRecognizedTextObservation])?.compactMap { $0.topCandidates(1).first?.string } ?? []; continuation.resume(returning: lines.joined(separator: "\n")) }; request.recognitionLevel = .accurate; request.recognitionLanguages = ["pl-PL", "en-US", "ar"]; request.usesLanguageCorrection = true; DispatchQueue.global(qos: .userInitiated).async { do { try VNImageRequestHandler(cgImage: image).perform([request]) } catch { continuation.resume(throwing: error) } } } }
    static func extract(_ text: String) -> Fields {
        var f = Fields(); let upper = text.uppercased(); let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        f.iban = validIBAN(in: upper)
        f.swift = swiftCode(in: upper)
        f.account = f.iban.isEmpty ? labeled(["ACCOUNT NUMBER", "ACCOUNT NO", "A/C", "رقم الحساب"], lines) : f.iban
        f.bank = labeled(["BANK NAME", "BENEFICIARY BANK", "NAME OF BANK", "اسم البنك", "البنك المستلم"], lines)
        if f.bank.isEmpty, let bankLine = lines.first(where: { $0.range(of: "\\b[A-Za-z0-9.-]*BANK\\b", options: [.regularExpression, .caseInsensitive]) != nil && !$0.localizedCaseInsensitiveContains("Bank Account") }) { f.bank = bankLine }
        f.beneficiary = labeled(["BENEFICIARY NAME", "ACCOUNT NAME", "اسم المستفيد", "صاحب الحساب"], lines)
        if f.beneficiary.isEmpty { f.beneficiary = value(after: ["SPRZEDAWCA / SELLER", "SELLER", "SUPPLIER"], in: lines) }
        f.reference = firstCapture("(?:PROFORMA INVOICE (?:NO\\.?|NUMBER)|INVOICE (?:NO\\.?|NUMBER))\\s*[:#-]?\\s*([A-Z0-9][A-Z0-9./-]*)", upper)
        if f.reference.isEmpty { f.reference = firstCapture("FAKTURA PROFORMA NUMER\\s*[:#-]?\\s*([A-Z0-9][A-Z0-9./-]*)", upper) }
        let due = firstCapture("(?:DO ZAPŁATY\\s*/\\s*TOTAL DUE|AMOUNT DUE|TOTAL GROSS PRICE|INVOICE TOTAL)\\s*[:]?\\s*([0-9][0-9 .,'’]*[0-9]|[0-9]+)[ \\t]*(USD|EUR|GBP|AED|IQD|CNY|RMB)", upper)
        if !due.isEmpty { let pieces = due.split(separator: "|").map(String.init); f.amount = decimal(pieces[0]); if pieces.count > 1 { f.currency = pieces[1] == "RMB" ? "CNY" : pieces[1] } }
        if f.amount.isEmpty { let raw = labeled(["TOTAL DUE", "AMOUNT DUE", "INVOICE TOTAL", "DO ZAPŁATY", "المبلغ النهائي", "الإجمالي"], lines); f.amount = decimal(raw); f.currency = currency(in: raw) }
        if f.currency.isEmpty { f.currency = currency(in: upper) }
        return f
    }
    private static func validIBAN(in text: String) -> String { let compact = text.replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression); let lengths = ["PL":28,"DE":22,"GB":22,"AE":23,"IQ":23,"FR":27,"IT":27,"ES":24,"NL":18,"BE":16,"CH":21,"SA":24]; for (country,length) in lengths { guard let regex = try? NSRegularExpression(pattern: "\(country)[0-9]{2}[A-Z0-9]{\(length - 4)}") else { continue }; let ns = compact as NSString; for result in regex.matches(in: compact, range: NSRange(location: 0, length: ns.length)) { let candidate = ns.substring(with: result.range); if ibanChecksum(candidate) { return candidate } } }; return "" }
    private static func ibanChecksum(_ value: String) -> Bool { let moved = String(value.dropFirst(4)) + String(value.prefix(4)); var remainder = 0; for scalar in moved.unicodeScalars { let digits = scalar.value >= 65 ? String(scalar.value - 55) : String(Character(String(scalar))); for digit in digits.compactMap(\.wholeNumberValue) { remainder = (remainder * 10 + digit) % 97 } }; return remainder == 1 }
    private static func swiftCode(in text: String) -> String { let banned:Set<String> = ["PROFORMA","INVOICE","TRANSFER","ACCOUNT","PAYMENT","BENEFICIARY"]; let pattern = "\\b[A-Z]{4}[A-Z]{2}[A-Z0-9]{2}(?:[A-Z0-9]{3})?\\b"; guard let regex = try? NSRegularExpression(pattern: pattern) else { return "" }; let ns=text as NSString; let matches=regex.matches(in:text,range:NSRange(location:0,length:ns.length)).map { ns.substring(with:$0.range) }; return matches.first { !banned.contains($0) && ["PL","GB","DE","AE","IQ","US","CH","FR","IT","ES","NL","BE","SA"].contains(String($0.dropFirst(4).prefix(2))) } ?? "" }
    private static func value(after labels:[String], in lines:[String]) -> String { for (index,line) in lines.enumerated() where labels.contains(where: { line.localizedCaseInsensitiveContains($0) }) { if index + 1 < lines.count { return lines[index + 1] } }; return "" }
    private static func labeled(_ labels: [String], _ lines: [String]) -> String { for (index,line) in lines.enumerated() { for label in labels where line.localizedCaseInsensitiveContains(label) { let value = line.replacingOccurrences(of: label, with: "", options: .caseInsensitive).trimmingCharacters(in: CharacterSet(charactersIn: " :-—|\t")); if !value.isEmpty { return value }; if index + 1 < lines.count { return lines[index + 1] } } }; return "" }
    private static func firstCapture(_ pattern:String,_ text:String)->String { guard let regex=try? NSRegularExpression(pattern:pattern),let result=regex.firstMatch(in:text,range:NSRange(text.startIndex...,in:text)) else{return ""}; if result.numberOfRanges == 3 { return "\((text as NSString).substring(with:result.range(at:1)))|\((text as NSString).substring(with:result.range(at:2)))" }; return result.numberOfRanges > 1 ? (text as NSString).substring(with:result.range(at:1)) : "" }
    private static func decimal(_ value:String)->String { var raw=value.replacingOccurrences(of:" ",with:"").replacingOccurrences(of:"'",with:"").replacingOccurrences(of:"’",with:""); if raw.contains(",") && raw.contains(".") { if raw.lastIndex(of:",")! > raw.lastIndex(of:".")! { raw=raw.replacingOccurrences(of:".",with:"").replacingOccurrences(of:",",with:".") } else { raw=raw.replacingOccurrences(of:",",with:"") } } else if raw.contains(",") { raw=raw.replacingOccurrences(of:",",with:".") }; return raw.filter { $0.isNumber || $0 == "." } }
    private static func currency(in value:String)->String { for code in ["USD","EUR","GBP","AED","IQD","CNY","RMB"] where value.uppercased().contains(code) { return code == "RMB" ? "CNY" : code }; return "" }
    private static func match(_ pattern: String, _ text: String) -> String { guard let range = text.range(of: pattern, options: .regularExpression) else { return "" }; return String(text[range]) }
    private static func labeled(_ labels: [String], _ text: String) -> String { for line in text.components(separatedBy: .newlines) { for label in labels where line.localizedCaseInsensitiveContains(label) { let value = line.replacingOccurrences(of: label, with: "", options: .caseInsensitive).trimmingCharacters(in: CharacterSet(charactersIn: " :-—\t")); if !value.isEmpty { return value } } }; return "" }
}
