import SwiftUI

struct AccountDeletedView: View {
    @EnvironmentObject private var auth: URAuthService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(URColor.success)

            VStack(spacing: 10) {
                Text("تم حذف الحساب")
                    .font(.title.bold())
                    .foregroundStyle(URColor.deepNavy)

                Text("Account Deleted")
                    .font(.headline)
                    .foregroundStyle(URColor.deepNavy.opacity(0.6))
            }

            Text("تم حذف حسابك وجميع البيانات المرتبطة به نهائياً.\nYour account and all associated data have been permanently deleted.")
                .font(.subheadline)
                .foregroundStyle(URColor.deepNavy.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                auth.signOutCompletely()
                dismiss()
            } label: {
                Label("العودة لتسجيل الدخول", systemImage: "arrow.right")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(.white)
                    .background(URColor.royalBlue, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(URColor.ivory.ignoresSafeArea())
        .interactiveDismissDisabled()
    }
}

#Preview {
    AccountDeletedView()
        .environmentObject(URAuthService.live)
}
