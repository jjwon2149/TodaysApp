import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab: AppTab = .home
    @State private var didStartLaunchSync = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                TabView(selection: $selectedTab) {
                    ForEach(AppTab.allCases) { tab in
                        tabView(for: tab)
                            .tabItem {
                                Label(tab.title, systemImage: tab.systemImage)
                            }
                            .tag(tab)
                    }
                }
                .tint(AppTheme.Colors.accent)
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .task {
            try? await BootstrapService().seedDefaultsIfNeeded()
            await refreshWidgetSnapshot()
            startLaunchSyncIfNeeded()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }

            Task {
                await refreshWidgetSnapshot()
                await CloudKitSyncService.shared.synchronize(trigger: .foreground)
                await refreshWidgetSnapshot()
            }
        }
    }

    private func startLaunchSyncIfNeeded() {
        guard didStartLaunchSync == false else {
            return
        }

        didStartLaunchSync = true
        Task.detached(priority: .background) {
            _ = await ImageStorageService().performLaunchMaintenance()
            await CloudKitSyncService.shared.synchronize(trigger: .launch)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard DailyFrameWidgetDeepLink.isTodayURL(url) else {
            return
        }

        if hasCompletedOnboarding {
            selectedTab = .home
        }

        Task {
            await refreshWidgetSnapshot()
        }
    }

    private func refreshWidgetSnapshot() async {
        try? await WidgetSnapshotService().refreshSnapshot()
    }

    @ViewBuilder
    private func tabView(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            HomeView()
        case .calendar:
            CalendarView()
        case .profile:
            ProfileView()
        }
    }
}
