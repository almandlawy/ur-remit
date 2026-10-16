import ActivityKit
import SwiftUI
import WidgetKit

struct URTransferAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable { var status: String; var progress: Double }
    var reference: String
}

@main struct URLiveActivityBundle: WidgetBundle {
    var body: some Widget { URTransferLiveActivity() }
}

struct URTransferLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: URTransferAttributes.self) { context in
            HStack { Image(systemName: "arrow.left.arrow.right.circle.fill"); VStack(alignment: .leading) { Text("حوالة UR").bold(); Text(context.state.status) }; Spacer(); Text(context.attributes.reference).font(.caption) }
                .padding().activityBackgroundTint(Color(red: 0.012, green: 0.08, blue: 0.21)).foregroundStyle(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text("UR").bold() }
                DynamicIslandExpandedRegion(.center) { Text(context.state.status) }
                DynamicIslandExpandedRegion(.trailing) { Text("\(Int(context.state.progress * 100))%") }
            } compactLeading: { Text("UR") } compactTrailing: { Image(systemName: "arrow.left.arrow.right") } minimal: { Text("UR") }
        }
    }
}
