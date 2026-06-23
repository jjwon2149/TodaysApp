import GoogleMobileAds
import SwiftUI
import UIKit

struct BannerAdView: View {
    @EnvironmentObject private var adsService: AdsService
    @State private var loadState: BannerAdLoadState = .idle

    var body: some View {
        if adsService.canRequestAds, let adUnitID = AdConfiguration.bannerAdUnitID {
            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)
                let adSize = largeAnchoredAdaptiveBanner(width: width)

                BannerAdContainer(adUnitID: adUnitID, adSize: adSize) { nextState in
                    loadState = nextState
                }
                .frame(width: adSize.size.width, height: loadState.height)
                .frame(maxWidth: .infinity)
            }
            .frame(height: loadState.height)
            .clipped()
            .accessibilityHidden(loadState.isLoaded == false)
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
