import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

struct WelcomeView: View {
    @EnvironmentObject private var auth: URAuthService
    @State private var nonce = ""

    var body: some View {
        ZStack {
            URColor.ivory.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer(minLength: 30)

                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Text("UR").font(.system(size: 60, weight: .black, design: .rounded))
                            Rectangle().fill(URColor.premiumGold).frame(width: 2, height: 50)
                            Text("أور").font(.system(size: 48, weight: .black))
                        }
                        .foregroundStyle(URColor.deepNavy)

                        Text("معكم في كل وجهة").font(.title3.weight(.bold))
                            .foregroundStyle(URColor.deepNavy.opacity(0.75))

                        Text("WITH YOU EVERYWHERE").font(.caption2.weight(.bold))
                            .tracking(2.5).foregroundStyle(URColor.premiumGold)
                    }
                    .padding(.bottom, 20)

                    Button { auth.continueAsGuest() } label: {
                        Label("Continue as Guest", systemImage: "arrow.right.circle.fill")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(URColor.deepNavy, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }

                    Text("استخدم التطبيق بدون حساب").font(.caption).foregroundStyle(.secondary)

                    HStack {
                        Rectangle().fill(URColor.hairline).frame(height: 1)
                        Text("أو").font(.caption).foregroundStyle(.secondary)
                        Rectangle().fill(URColor.hairline).frame(height: 1)
                    }.padding(.vertical, 8)

                    URCard {
                        VStack(spacing: 14) {
                            Text("سجّل الدخول لمزامنة بياناتك عبر الأجهزة")
                                .font(.caption).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            SignInWithAppleButton(.signIn) { request in
                                nonce = URAuthService.randomNonce()
                                auth.prepareAppleRequest(request, nonce: nonce)
                            } onCompletion: { result in
                                switch result {
                                case .success(let auth):
                                    Task { await self.auth.signInWithApple(authorization: auth, nonce: nonce) }
                                case .failure:
                                    self.auth.message = "تعذر إكمال تسجيل الدخول."
                                }
                            }
                            .signInWithAppleButtonStyle(.black).frame(height: 50).cornerRadius(12)

                            GoogleSignInButton(viewModel: GoogleSignInButtonViewModel(scheme: .light, style: .wide, state: .normal)) {
                                Task { await auth.signInWithGoogle() }
                            }
                            .frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)
                            .accessibilityLabel("تسجيل الدخول باستخدام Google")
                        }
                    }

                    Text("بالمتابعة أنت توافق على سياسة الخصوصية والشروط.")
                        .font(.caption2).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.top, 8)

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: auth.message)
    }
}
