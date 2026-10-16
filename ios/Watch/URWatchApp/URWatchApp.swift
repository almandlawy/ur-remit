import SwiftUI

@main struct URWatchApp: App {
    var body: some Scene { WindowGroup { URWatchRatesView() } }
}

struct URWatchRatesView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("UR").font(.largeTitle.weight(.black)).foregroundStyle(.yellow)
            Text("USD / IQD").font(.headline)
            Text("افتح تطبيق iPhone لتحديث السعر").font(.caption).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }.padding()
    }
}
