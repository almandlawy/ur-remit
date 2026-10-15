import SwiftUI

/// شاشة الترحيب — تظهر عند فتح التطبيق لمدة ~1.2 ثانية
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var logoScale: CGFloat = 0.58
    @State private var logoOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var glowOpacity: Double = 0.18
    @State private var logoOffset: CGFloat = 38
    @State private var orbitRotation = -24.0
    @State private var titleTracking: CGFloat = 8

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

            decorativeLines

            Circle()
                .fill(
                    RadialGradient(
                        colors: [URColor.premiumGold.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 200
                    )
                )
                .frame(width: 460, height: 460)
                .opacity(glowOpacity)

            Ellipse()
                .stroke(
                    AngularGradient(colors: [.clear, URColor.premiumGold.opacity(0.75), .clear, .white.opacity(0.25), .clear], center: .center),
                    lineWidth: 1.2
                )
                .frame(width: 430, height: 170)
                .rotationEffect(.degrees(orbitRotation))
                .blur(radius: 0.2)

            launchParticles

            VStack(spacing: 22) {
                Image("URLaunch3DStrong")
                    .resizable().scaledToFit()
                    .frame(maxWidth: 370)
                    .shadow(color: Color.blue.opacity(0.48), radius: 28, y: 12)
                    .shadow(color: URColor.premiumGold.opacity(0.28), radius: 18, x: 10, y: -2)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .offset(y: logoOffset)
                .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(logoOffset) * 0.20), axis: (x: 1, y: -0.25, z: 0))

                VStack(spacing: 8) {
                    Text("UR GLOBAL")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .tracking(titleTracking)
                        .foregroundStyle(.white)
                    Rectangle().fill(LinearGradient(colors: [.clear, URColor.premiumGold, .clear], startPoint: .leading, endPoint: .trailing)).frame(width: 190, height: 1)
                    Text("أور جلوبال · معكم في كل وجهة")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.92))

                    Text("TRUST CONNECTS THE WORLD")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(2.2)
                        .foregroundStyle(URColor.premiumGold)
                }
                .opacity(taglineOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.15, dampingFraction: 0.76)) {
                logoScale = 1.0
                logoOpacity = 1.0
                logoOffset = 0
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.65)) {
                taglineOpacity = 1.0
                titleTracking = 3.2
            }
            if !reduceMotion {
                withAnimation(.linear(duration: 5.0)) { orbitRotation = 336 }
                withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) { glowOpacity = 0.72 }
            }
        }
    }

    private var launchParticles: some View {
        Canvas { context, size in
            let points: [(Double, Double, Double)] = [
                (0.12, 0.20, 2.2), (0.83, 0.17, 1.7), (0.91, 0.38, 2.5),
                (0.18, 0.68, 1.5), (0.76, 0.74, 2.0), (0.31, 0.84, 1.2),
                (0.67, 0.28, 1.1), (0.07, 0.46, 1.4), (0.88, 0.87, 1.6)
            ]
            for point in points {
                let rect = CGRect(x: size.width * point.0, y: size.height * point.1, width: point.2, height: point.2)
                context.fill(Path(ellipseIn: rect), with: .color(URColor.premiumGold.opacity(0.62)))
            }
        }.ignoresSafeArea().accessibilityHidden(true)
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
