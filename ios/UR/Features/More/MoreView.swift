import SwiftUI

struct MoreView: View {
    let api: any APIClient
    @EnvironmentObject private var auth: URAuthService
    var body: some View {
        List {
            Section {
                NavigationLink { AccountView() } label: {
                    Label(auth.isAuthenticated ? "my_account" : "optional_sign_in", systemImage: "person.crop.circle")
                }
            } footer: {
                Text("account_optional_notice")
            }
            Section {
                NavigationLink { OfficesView(api: api) } label: { Label("offices", systemImage: "building.2") }
                NavigationLink { AgentVerificationView(api: api) } label: { Label("verify_agent", systemImage: "checkmark.shield") }
                NavigationLink { SecurityCenterView() } label: { Label("security_center", systemImage: "lock.shield") }
            }
            Section {
                Link(destination: URL(string: "https://urremit.com/privacy")!) { Label("privacy_policy", systemImage: "hand.raised") }
                Link(destination: URL(string: "https://urremit.com/terms")!) { Label("terms", systemImage: "doc.text") }
                Link(destination: URL(string: "https://urremit.com/contact")!) { Label("contact", systemImage: "phone") }
            }
            Section { LabeledContent("version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—") }
        }.navigationTitle("more")
    }
}

private struct OfficesView: View {
    let api: any APIClient
    @State private var offices: [Office] = []
    @State private var loading = false
    @State private var failed = false
    @Environment(\.locale) private var locale

    var body: some View {
        List {
            if loading && offices.isEmpty {
                ProgressView("loading_offices").frame(maxWidth: .infinity, alignment: .center)
            } else if failed && offices.isEmpty {
                ContentUnavailableView {
                    Label("offices_load_failed", systemImage: "wifi.exclamationmark")
                } actions: {
                    Button("retry") { Task { await load() } }
                }
            } else if offices.isEmpty {
                ContentUnavailableView("no_offices", systemImage: "building.2")
            }
            ForEach(offices) { office in
                URCard {
                    Label(localized(office.nameArabic, english: office.nameEnglish), systemImage: office.verified ? "checkmark.seal.fill" : "building.2")
                        .font(.headline)
                    Text("\(localized(office.cityArabic, english: office.cityEnglish)), \(localized(office.countryArabic, english: office.countryEnglish))")
                    Text(localized(office.addressArabic, english: office.addressEnglish)).foregroundStyle(.secondary)
                    if let phone = office.phone, let url = URL(string: "tel:\(phone)") {
                        Link("call", destination: url)
                    }
                    if let latitude = office.latitude, let longitude = office.longitude,
                       let url = URL(string: "https://maps.apple.com/?ll=\(latitude),\(longitude)") {
                        Link("open_in_maps", destination: url)
                    }
                }
                .listRowSeparator(.hidden)
            }
            if failed && !offices.isEmpty {
                Label("refresh_failed_showing_saved", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .refreshable { await load() }
        .navigationTitle("offices")
        .task { await load() }
    }

    private func load() async {
        loading = true
        failed = false
        defer { loading = false }
        do { offices = try await api.offices() }
        catch is CancellationError { return }
        catch { failed = true }
    }

    private func localized(_ arabic: String, english: String) -> String {
        locale.language.languageCode?.identifier == "ar" ? arabic : english
    }
}

private struct AgentVerificationView: View {
    let api: any APIClient
    @State private var code = ""
    @State private var result: AgentVerification?
    @State private var loading = false
    @State private var message: String?
    @Environment(\.locale) private var locale

    var body: some View {
        Form {
            Section {
                TextField("agent_code", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button {
                    Task { await verify() }
                } label: {
                    if loading {
                        ProgressView("checking_agent").frame(maxWidth: .infinity)
                    } else {
                        Text("verify").frame(maxWidth: .infinity)
                    }
                }
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).count < 4 || loading)
            }
            if let result {
                Section("verification_result") {
                    Label {
                        Text(result.status == "VERIFIED" ? "verified_agent" : "agent_not_verified")
                    } icon: {
                        Image(systemName: result.status == "VERIFIED" ? "checkmark.seal.fill" : "xmark.shield")
                    }
                    if let name = result.tradeName { Text(name) }
                    if let city = result.city { Text(localized(city.ar, english: city.en)) }
                }
            }
            if let message {
                Section { Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.secondary) }
            }
            Section { Text("agent_safety_notice").font(.footnote) }
        }
        .navigationTitle("verify_agent")
    }

    private func verify() async {
        loading = true
        message = nil
        result = nil
        defer { loading = false }
        do {
            result = try await api.verifyAgent(code: code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
        } catch is CancellationError {
            return
        } catch {
            message = String(localized: "agent_verification_failed")
        }
    }

    private func localized(_ arabic: String, english: String) -> String {
        locale.language.languageCode?.identifier == "ar" ? arabic : english
    }
}

private struct SecurityCenterView: View {
    var body: some View { List {
        Label("security_verify_agent", systemImage: "checkmark.shield")
        Label("security_never_share_codes", systemImage: "number.square")
        Label("security_official_channels", systemImage: "link.badge.plus")
        Link("report_fake_account", destination: URL(string: "https://urremit.com/contact")!)
    }.navigationTitle("security_center") }
}
