import AuthenticationServices
import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var auth: URAuthService
    @State private var appleNonce = URAuthService.randomNonce()

    var body: some View {
        Form {
            if auth.isAuthenticated {
                Section("الحساب") {
                    Label(auth.email ?? "تم تسجيل الدخول", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(URColor.royalBlue)
                    Button("تسجيل الخروج", role: .destructive) {
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
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .disabled(auth.isLoading)

                    Button {
                        Task { await auth.signInWithGoogle() }
                    } label: {
                        Label("المتابعة باستخدام Google", systemImage: "g.circle.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(auth.isLoading)
                } header: {
                    Text("تسجيل الدخول")
                } footer: {
                    Text("اختياري لحفظ تفضيلاتك بأمان ومزامنتها. جميع الخدمات الأساسية تعمل من دون حساب.")
                }
            }

            if auth.isLoading {
                Section { ProgressView("جارٍ إكمال تسجيل الدخول…") }
            }
            if let message = auth.message {
                Section { Label(message, systemImage: "exclamationmark.triangle") }
            }
        }
        .navigationTitle("الحساب")
    }
}
