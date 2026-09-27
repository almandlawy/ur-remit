import AuthenticationServices
import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var auth: URAuthService
    @State private var appleNonce = URAuthService.randomNonce()

    var body: some View {
        Form {
            if auth.isAuthenticated {
                Section("account") {
                    Label(auth.email ?? String(localized: "signed_in"), systemImage: "checkmark.seal.fill")
                        .foregroundStyle(URColor.royalBlue)
                    Button("sign_out", role: .destructive) {
                        Task { await auth.signOut() }
                    }
                }
            } else {
                Section {
                    SignInWithAppleButton(.signIn) { request in
                        appleNonce = URAuthService.randomNonce()
                        auth.prepareAppleRequest(request, nonce: appleNonce)
                    } onCompletion: { result in
                        if case let .success(authorization) = result {
                            Task { await auth.signInWithApple(authorization: authorization, nonce: appleNonce) }
                        } else if case let .failure(error) = result,
                                  (error as? ASAuthorizationError)?.code != .canceled {
                            auth.message = String(localized: "apple_sign_in_failed")
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .disabled(auth.isLoading)

                    Button {
                        Task { await auth.signInWithGoogle() }
                    } label: {
                        Label("continue_with_google", systemImage: "g.circle.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(auth.isLoading)
                } header: {
                    Text("sign_in")
                } footer: {
                    Text("optional_account_notice")
                }
            }

            if auth.isLoading {
                Section { ProgressView("completing_sign_in") }
            }
            if let message = auth.message {
                Section { Label(message, systemImage: "exclamationmark.triangle") }
            }
        }
        .navigationTitle("account")
    }
}
