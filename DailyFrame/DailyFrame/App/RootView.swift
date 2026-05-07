import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab: AppTab = .home
    @State private var didStartLaunchMediaMaintenance = false

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
            startLaunchMediaMaintenanceIfNeeded()
        }
    }

    private func startLaunchMediaMaintenanceIfNeeded() {
        guard didStartLaunchMediaMaintenance == false else {
            return
        }

        didStartLaunchMediaMaintenance = true
        Task.detached(priority: .background) {
            _ = await ImageStorageService().performLaunchMaintenance()
        }
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
