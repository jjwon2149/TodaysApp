import SwiftUI

@main
struct DailyFrameApp: App {
    @StateObject private var adsService = AdsService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(adsService)
                .task {
                    adsService.prepareForLaunch()
                }
        }
    }
}
