import SwiftUI

/// Hidden admin entry point: reachable by tapping the version row 5 times on the More screen (in any
/// build, including the App Store one — this used to be DEBUG-only and effectively unusable once the
/// backend it depended on was unreachable outside the developer's Wi-Fi).
struct AdminAccessView: View {
    let api: any APIClient
    @StateObject private var session = AdminSessionStore()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch session.screen {
                case .unlocked:
                    AdminRatesView(api: api, session: session)
                case .loginForm:
                    AdminLoginFormView(session: session)
                case .pinUnlock:
                    AdminPINUnlockView(session: session)
                case .setUpPIN:
                    AdminPINSetupView(session: session)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") { dismiss() }
                }
                if session.isAuthenticated {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("admin_sign_out", role: .destructive) { session.signOut() }
                    }
                }
            }
        }
    }
}

/// Full email/password sign-in against Supabase Auth — required the first time on a device, or any
/// time the operator chooses "use email instead" from the PIN screen.
private struct AdminLoginFormView: View {
    @ObservedObject var session: AdminSessionStore
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        Form {
            Section {
                Text("admin_login_notice").font(.footnote).foregroundStyle(.secondary)
            }
            Section("admin_credentials") {
                TextField("email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .accessibilityLabel(Text("email"))
                SecureField("password", text: $password)
                    .accessibilityLabel(Text("password"))
            }
            if let message = session.message {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.secondary)
                }
            }
            Section {
                Button {
                    Task { await session.signIn(email: email, password: password) }
                } label: {
                    if session.isLoading {
                        ProgressView("admin_signing_in").frame(maxWidth: .infinity)
                    } else {
                        Text("admin_sign_in").frame(maxWidth: .infinity)
                    }
                }
                .disabled(session.isLoading || email.isEmpty || password.isEmpty)

                Button("admin_forgot_password") {
                    Task { await session.requestPasswordReset(email: email) }
                }
                .disabled(session.isLoading || email.isEmpty)
                .font(.footnote)
            } footer: {
                Text("admin_forgot_password_hint")
            }
        }
        .navigationTitle("admin_panel")
    }
}

/// Quick unlock: only the 4-6 digit local PIN is checked (no network round-trip unless the stored
/// Supabase session has expired, in which case it's silently refreshed with the stored refresh token).
private struct AdminPINUnlockView: View {
    @ObservedObject var session: AdminSessionStore
    @State private var pin = ""

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.shield").font(.system(size: 44)).foregroundStyle(.tint)
            Text("admin_enter_pin").font(.headline)
            SecureField("admin_pin_placeholder", text: $pin)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title2)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                .onChange(of: pin) { _, newValue in
                    if newValue.count >= 6 { Task { await session.unlock(withPIN: newValue) } }
                }
                .accessibilityLabel(Text("admin_enter_pin"))
            if let message = session.message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
            Button("admin_unlock") { Task { await session.unlock(withPIN: pin) } }
                .disabled(session.isLoading || pin.count < 4)
            Button("admin_use_email_instead") { session.useEmailInstead() }
                .font(.footnote)
            Spacer()
        }
        .padding()
        .navigationTitle("admin_panel")
    }
}

/// Shown once, right after the first successful email/password sign-in on a device.
private struct AdminPINSetupView: View {
    @ObservedObject var session: AdminSessionStore
    @State private var pin = ""
    @State private var confirmPIN = ""

    private var pinsMatch: Bool { !pin.isEmpty && pin == confirmPIN }

    var body: some View {
        Form {
            Section {
                Text("admin_setup_pin_notice").font(.footnote).foregroundStyle(.secondary)
            }
            Section("admin_pin_placeholder") {
                SecureField("admin_pin_placeholder", text: $pin).keyboardType(.numberPad)
                SecureField("admin_confirm_pin", text: $confirmPIN).keyboardType(.numberPad)
            }
            if let message = session.message {
                Section { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }
            Section {
                Button("admin_save_pin") { session.setUpPIN(pin) }
                    .disabled(!pinsMatch || pin.count < 4)
            }
        }
        .navigationTitle("admin_panel")
    }
}
