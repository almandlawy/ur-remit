import SwiftUI

/// شاشة الترحيب — تظهر عند فتح التطبيق لمدة ~1.2 ثانية
struct SplashView: View {
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        ZStack {
            // خلفية متدرجة
            LinearGradient(
                colors: [
                    URColor.deepNavy,
                    URColor.royalBlue,
                    URColor.deepNavy
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // نقشة ذهبية خفيفة
            decorativeLines

            // هالة ذهبية متحركة
            Circle()
                .fill(
                    RadialGradient(
                        colors: [URColor.premiumGold.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .opacity(glowOpacity)

            VStack(spacing: 20) {
                // الشعار
                HStack(spacing: 12) {
                    Text("UR")
                        .font(.system(size: 90, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Rectangle()
                        .fill(URColor.premiumGold)
                        .frame(width: 3, height: 70)

                    Text("أور")
                        .font(.system(size: 72, weight: .black))
                        .foregroundStyle(.white)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // النص تحت الشعار
                VStack(spacing: 6) {
                    Text("معكم في كل وجهة")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white.opacity(0.92))

                    Text("WITH YOU EVERYWHERE")
                        .font(.caption2.weight(.bold))
                        .tracking(2.5)
                        .foregroundStyle(URColor.premiumGold)
                }
                .opacity(taglineOpacity)
            }
        }
        .onAppear {
            // حركة ظهور الشعار
            withAnimation(.spring(response: 0.7, dampingFraction: 0.65)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.9).delay(0.25)) {
                taglineOpacity = 1.0
            }
            // نبض الهالة
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                glowOpacity = 0.7
            }
        }
    }

    // نقشة ذهبية على الخلفية
    private var decorativeLines: some View {
        Canvas { context, size in
            let goldOpacity = 0.08
            for i in 0..<6 {
                var path = Path()
                let y = size.height * (0.15 + Double(i) * 0.14)
                path.move(to: CGPoint(x: 0, y: y))
                path.addCurve(
                    to: CGPoint(x: size.width, y: y + 30),
                    control1: CGPoint(x: size.width * 0.35, y: y - 40),
                    control2: CGPoint(x: size.width * 0.65, y: y + 60)
                )
                context.stroke(
                    path,
                    with: .color(URColor.premiumGold.opacity(goldOpacity)),
                    lineWidth: 1
                )
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    SplashView()
}
