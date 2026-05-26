//
//  LiveActivityExtLiveActivity.swift
//  LiveActivityExt
//
//  Created by PapaJi on 26/05/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LiveActivityExtAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LiveActivityExtLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivityExtAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension LiveActivityExtAttributes {
    fileprivate static var preview: LiveActivityExtAttributes {
        LiveActivityExtAttributes(name: "World")
    }
}

extension LiveActivityExtAttributes.ContentState {
    fileprivate static var smiley: LiveActivityExtAttributes.ContentState {
        LiveActivityExtAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: LiveActivityExtAttributes.ContentState {
         LiveActivityExtAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: LiveActivityExtAttributes.preview) {
   LiveActivityExtLiveActivity()
} contentStates: {
    LiveActivityExtAttributes.ContentState.smiley
    LiveActivityExtAttributes.ContentState.starEyes
}
