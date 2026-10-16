import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var page = 0

    private let pages = [
        ("أسعار موثوقة", "تابع أسعار UR ومصدرها ووقت تحديثها بوضوح.", "chart.line.uptrend.xyaxis"),
        ("حوالتك خطوة بخطوة", "أنشئ الطلب وارفع الإثبات وتابع القبض والتسليم من حساب واحد.", "arrow.left.arrow.right.circle.fill"),
        ("تنبيهات وخدمات ذكية", "اختر تنبيهات الأسعار وشارك بطاقات واضحة دون أرقام تقديرية مضللة.", "bell.badge.fill")
    ]

    var body: some View {
        ZStack {
            URColor.ivory.ignoresSafeArea()
            VStack(spacing: 24) {
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        VStack(spacing: 22) {
                            Image(systemName: pages[index].2)
                                .font(.system(size: 64, weight: .bold))
                                .foregroundStyle(URColor.premiumGold)
                                .frame(width: 130, height: 130)
                                .background(URColor.royalBlue, in: RoundedRectangle(cornerRadius: 34))
                            Text(pages[index].0).font(.largeTitle.weight(.black)).foregroundStyle(URColor.deepNavy)
                            Text(pages[index].1).font(.title3).multilineTextAlignment(.center).foregroundStyle(URColor.deepNavy.opacity(0.72)).padding(.horizontal, 28)
                        }.tag(index)
                    }
                }.tabViewStyle(.page(indexDisplayMode: .always))

                Button(page == pages.count - 1 ? "ابدأ الآن" : "التالي") {
                    if page == pages.count - 1 { isPresented = false }
                    else { withAnimation { page += 1 } }
                }.buttonStyle(URPrimaryButtonStyle()).padding(.horizontal, 24)

                if page < pages.count - 1 {
                    Button("تخطي") { isPresented = false }.foregroundStyle(URColor.deepNavy)
                }
            }.padding(.vertical, 24)
        }
    }
}
