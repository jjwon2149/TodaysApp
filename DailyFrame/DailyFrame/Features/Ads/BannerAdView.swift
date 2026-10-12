import GoogleMobileAds
import SwiftUI
import UIKit

struct BannerAdView: View {
    @EnvironmentObject private var adsService: AdsService
    @State private var loadState: BannerAdLoadState = .idle
    @State private var availableWidth: CGFloat = 0

    private let onVisibilityChange: (Bool) -> Void

    init(onVisibilityChange: @escaping (Bool) -> Void = { _ in }) {
        self.onVisibilityChange = onVisibilityChange
    }

    var body: some View {
        if adsService.canRequestAds, let adUnitID = AdConfiguration.bannerAdUnitID {
            GeometryReader { proxy in
                if proxy.size.width >= AdSizeBanner.size.width {
                    BannerAdContainer(adUnitID: adUnitID, adSize: AdSizeBanner) { nextState in
                        loadState = nextState
                        onVisibilityChange(nextState.isLoaded)
                    }
                    .frame(width: AdSizeBanner.size.width, height: AdSizeBanner.size.height)
                    .frame(maxWidth: .infinity)
                    .opacity(loadState.isLoaded ? 1 : 0)
                }
                Color.clear
                    .allowsHitTesting(false)
                    .onAppear { availableWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in
                        availableWidth = width
                        if width < AdSizeBanner.size.width {
                            loadState = .idle
                            onVisibilityChange(false)
                        }
                    }
            }
            .frame(height: availableWidth >= AdSizeBanner.size.width ? loadState.height : 0)
            .clipped()
            .accessibilityHidden(!(loadState.isLoaded) || availableWidth < AdSizeBanner.size.width)
            .padding(.top, loadState.isLoaded && availableWidth >= AdSizeBanner.size.width ? 8 : 0)
            .onAppear {
                onVisibilityChange(loadState.isLoaded)
            }
            .onDisappear {
                onVisibilityChange(false)
            }
        } else {
            EmptyView()
                .onAppear {
                    onVisibilityChange(false)
                }
        }
    }
}

private enum BannerAdLoadState: Equatable {
    case idle
    case loading
    case loaded(height: CGFloat)
    case failed

    var height: CGFloat {
        switch self {
        case .loaded(let height):
            height
        case .idle, .loading, .failed:
            0
        }
    }

    var isLoaded: Bool {
        if case .loaded = self {
            return true
        }

        return false
    }
}

private struct BannerAdContainer: UIViewRepresentable {
    let adUnitID: String
    let adSize: AdSize
    let onLoadStateChange: (BannerAdLoadState) -> Void

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: adSize)
        bannerView.delegate = context.coordinator
        context.coordinator.loadIfNeeded(bannerView, adUnitID: adUnitID, adSize: adSize)
        return bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        context.coordinator.onLoadStateChange = onLoadStateChange
        context.coordinator.loadIfNeeded(uiView, adUnitID: adUnitID, adSize: adSize)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoadStateChange: onLoadStateChange)
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        var onLoadStateChange: (BannerAdLoadState) -> Void

        private var lastLoadedAdUnitID: String?
        private var lastLoadedAdSize: CGSize?

        init(onLoadStateChange: @escaping (BannerAdLoadState) -> Void) {
            self.onLoadStateChange = onLoadStateChange
        }

        func loadIfNeeded(_ bannerView: BannerView, adUnitID: String, adSize: AdSize) {
            let size = adSize.size
            guard lastLoadedAdUnitID != adUnitID || lastLoadedAdSize != size else {
                return
            }

            lastLoadedAdUnitID = adUnitID
            lastLoadedAdSize = size

            bannerView.adUnitID = adUnitID
            bannerView.adSize = adSize
            bannerView.rootViewController = UIApplication.shared.dailyFrameTopViewController

            onLoadStateChange(.loading)
            bannerView.load(Request())
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            onLoadStateChange(.loaded(height: bannerView.adSize.size.height))
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            onLoadStateChange(.failed)
        }
    }
}

private extension UIApplication {
    var dailyFrameTopViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController?
            .dailyFrameTopMostPresentedViewController
    }
}

private extension UIViewController {
    var dailyFrameTopMostPresentedViewController: UIViewController {
        if let presentedViewController {
            return presentedViewController.dailyFrameTopMostPresentedViewController
        }

        if let navigationController = self as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return visibleViewController.dailyFrameTopMostPresentedViewController
        }

        if let tabBarController = self as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return selectedViewController.dailyFrameTopMostPresentedViewController
        }

        return self
    }
}

extension View {
    func bottomBanner(on surface: BannerAdPlacementPolicy.Surface) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            if BannerAdPlacementPolicy.permitsBanner(on: surface) {
                BannerAdView()
                    .background(AppTheme.Colors.background)
                    .accessibilityLabel(Text("profile.ad.banner.accessibility_label"))
                    .accessibilityHint(Text("profile.ad.banner.accessibility_hint"))
            }
        }
    }
}
