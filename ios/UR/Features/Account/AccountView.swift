import AuthenticationServices
import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var auth: URAuthService
    @State private var appleNonce = URAuthService.randomNonce()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                URPageTitle(title: "حسابي", subtitle: "تسجيل الدخول اختياري", symbol: "person.crop.circle.fill")
                Image(systemName: auth.isAuthenticated ? "checkmark.seal.fill" : "person.crop.circle.fill")
                    .font(.system(size: 68)).foregroundStyle(auth.isAuthenticated ? URColor.success : URColor.royalBlue).padding(.top, 12)

                if auth.isAuthenticated {
                    Text("تم تسجيل الدخول").font(.title3.weight(.black)).foregroundStyle(URColor.deepNavy)
                    Text(auth.email ?? "حساب UR").font(.subheadline).foregroundStyle(.secondary)
                    NavigationLink {
                        DeleteAccountView()
                    } label: {
                        Label("حذف الحساب", systemImage: "trash.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(URColor.error)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(URColor.error.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }
                    Button("تسجيل الخروج", role: .destructive) { Task { await auth.signOut() } }
                        .font(.subheadline.weight(.bold)).frame(maxWidth: .infinity, minHeight: 48).background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                } else {
                    Text("احفظ تفضيلاتك بأمان").font(.title3.weight(.black)).foregroundStyle(URColor.deepNavy)
                    Text("جميع الأسعار والحاسبة والتتبع والمراكز تعمل بدون إنشاء حساب.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    URCard {
                        VStack(spacing: 12) {
                            SignInWithAppleButton(.signIn) { request in
                                appleNonce = URAuthService.randomNonce(); auth.prepareAppleRequest(request, nonce: appleNonce)
                            } onCompletion: { result in
                                if case let .success(authorization) = result { Task { await auth.signInWithApple(authorization: authorization, nonce: appleNonce) } }
                            }
                            .signInWithAppleButtonStyle(.black).frame(height: 50).disabled(auth.isLoading)
                            Button { Task { await auth.signInWithGoogle() } } label: {
                                HStack(spacing: 10) {
                                    GoogleLogoMark(size: 20)
                                    Text("المتابعة باستخدام Google")
                                }
                            }
                            .buttonStyle(GoogleSignInButtonStyle()).disabled(auth.isLoading)
                        }
                    }
                }
                if auth.isLoading { ProgressView("جارٍ إكمال تسجيل الدخول…") }
                if let message = auth.message { Label(message, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.secondary).padding() }
                Label("لن نطلب منك تسجيل الدخول للاطلاع على خدمات UR الأساسية.", systemImage: "lock.shield.fill").font(.caption).foregroundStyle(URColor.deepNavy.opacity(0.60)).padding()
            }.padding(14)
        }
        .background(URColor.ivory.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline)
    }
}
