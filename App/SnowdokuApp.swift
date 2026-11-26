import SwiftUI

@main
struct SnowdokuApp: App {
    @State private var stats = StatsStore()

    var body: some Scene {
        WindowGroup {
            RootView(stats: stats)
                .environment(stats)
        }
        #if os(macOS)
        .defaultSize(width: 900, height: 900)
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .frame(width: 460)
        }
        #endif
    }
}
