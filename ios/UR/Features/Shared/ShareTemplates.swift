import SwiftUI

enum ShareTemplate: String, CaseIterable, Identifiable {
    case classic, midnight, gold, minimal, social
    var id: String { rawValue }
    var title: String { ["classic":"كلاسيكي", "midnight":"ليلي", "gold":"ذهبي", "minimal":"بسيط", "social":"اجتماعي"][rawValue]! }
}

struct ShareTemplateCard: View {
    let template: ShareTemplate
    let title: String
    let value: String
    var body: some View {
        let dark = template == .midnight || template == .social
        ZStack {
            LinearGradient(colors: template == .gold ? [URColor.premiumGold, URColor.royalBlue] : dark ? [Color.black, URColor.royalBlue] : [URColor.ivory, URColor.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 18) {
                Text("UR | أور").font(.largeTitle.weight(.black))
                Text(title).font(.title2.weight(.bold))
                Text(value).font(.system(size: 48, weight: .black, design: .rounded)).monospacedDigit()
                Text("urremit.com").font(.caption.weight(.bold))
            }.foregroundStyle(dark || template == .gold ? .white : URColor.deepNavy).padding()
        }.frame(width: 500, height: 500).clipShape(RoundedRectangle(cornerRadius: template == .minimal ? 0 : 30))
    }
}

struct ShareTemplatesGallery: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(ShareTemplate.allCases) { template in
                    VStack {
                        ShareTemplateCard(template: template, title: "USD / IQD", value: "—")
                            .scaleEffect(0.56).frame(width: 280, height: 280)
                        Text(template.title).font(.headline.weight(.bold)).foregroundStyle(URColor.deepNavy)
                    }
                }
            }.padding(18)
        }
        .background(URColor.ivory.ignoresSafeArea())
        .navigationTitle("قوالب المشاركة")
        .navigationBarTitleDisplayMode(.inline)
    }
}
