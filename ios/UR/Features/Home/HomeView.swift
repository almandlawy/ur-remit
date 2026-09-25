import SwiftUI

struct HomeView: View {
    let repository: any RatesRepository

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                URCard {
                    Label("information_only_title", systemImage: "info.circle.fill")
                        .font(.headline).foregroundStyle(URColor.royalBlue)
                    Text("information_only_body").font(.subheadline).foregroundStyle(.secondary)
                }
                RatesView(repository: repository).frame(minHeight: 420)
            }.padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("app_name")
    }
}

