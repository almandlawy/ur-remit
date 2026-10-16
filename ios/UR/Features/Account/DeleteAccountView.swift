import SwiftUI

struct DeleteAccountView: View {
    @EnvironmentObject private var auth: URAuthService
    @Environment(\.dismiss) private var dismiss

    @State private var confirmText = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    private let confirmKeyword = "DELETE"

    private var canDelete: Bool {
        confirmText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == confirmKeyword
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {

                URPageTitle(
                    title: "Delete Account",
                    subtitle: "هذا الإجراء نهائي ولا يمكن التراجع عنه",
                    symbol: "trash.fill"
                )

                URCard {
                    VStack(alignment: .trailing, spacing: 12) {
                        warningRow("سيتم حذف حسابك وكل بياناتك المرتبطة به نهائياً.",
                                   icon: "person.crop.circle.badge.xmark")
                        Divider()
                        warningRow("ستفقد الوصول إلى المفضلة، التنبيهات، والتذكيرات.",
                                   icon: "star.slash.fill")
                        Divider()
                        warningRow("لا يمكن استرجاع الحساب أو بياناته بعد الحذف.",
                                   icon: "exclamationmark.triangle.fill")
                    }
                }

                URCard {
                    VStack(alignment: .trailing, spacing: 12) {
                        Text("لحذف الحساب، اكتب **\(confirmKeyword)** في الحقل أدناه:")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(URColor.deepNavy)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        TextField(confirmKeyword, text: $confirmText)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.center)
                            .font(.title3.weight(.black))
                            .padding(14)
                            .background(URColor.ivory, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(canDelete ? URColor.error : URColor.hairline, lineWidth: 1)
                            )

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(URColor.error)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .background(URColor.error.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                Button {
                    Task { await performDelete() }
                } label: {
                    if isDeleting {
                        ProgressView().tint(.white)
                    } else {
                        Label("Delete My Account Permanently", systemImage: "trash.fill")
                    }
                }
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(.white)
                .background(
                    canDelete ? URColor.error : URColor.deepNavy.opacity(0.25),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .disabled(!canDelete || isDeleting)

                Button("Cancel") { dismiss() }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(URColor.royalBlue)
                    .padding(.top, 4)
                    .disabled(isDeleting)
            }
            .padding(14)
        }
        .background(URColor.ivory.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .interactiveDismissDisabled(isDeleting)
        .fullScreenCover(isPresented: $showSuccess) {
            AccountDeletedView()
                .environmentObject(auth)
        }
    }

    private func warningRow(_ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Spacer()
            Text(text)
                .font(.subheadline)
                .foregroundStyle(URColor.deepNavy)
                .multilineTextAlignment(.trailing)
            Image(systemName: icon)
                .font(.body.weight(.bold))
                .foregroundStyle(URColor.error)
                .frame(width: 26)
        }
    }

    private func performDelete() async {
        guard canDelete else { return }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        do {
            try await auth.deleteAccount()
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
