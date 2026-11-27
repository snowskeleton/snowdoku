import SwiftUI

@main
struct SnowdokuApp: App {
    @State private var stats = StatsStore()
    @State private var campaign = CampaignProgress()

    var body: some Scene {
        WindowGroup {
            RootView(stats: stats, campaign: campaign)
                .environment(stats)
                .environment(campaign)
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
