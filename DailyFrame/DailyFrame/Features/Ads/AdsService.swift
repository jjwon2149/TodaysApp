import Combine
import Foundation
import GoogleMobileAds

@MainActor
final class AdsService: ObservableObject {
    enum Readiness: Equatable {
        case idle
        case gatheringConsent
        case ready
        case unavailable(String)
    }

    static let shared = AdsService()

    @Published private(set) var readiness: Readiness = .idle

    var canRequestAds: Bool {
        readiness == .ready
    }

    var isPrivacyOptionsRequired: Bool {
        AdsConsentManager.shared.isPrivacyOptionsRequired
    }

    private var prepareTask: Task<Void, Never>?
    private var isMobileAdsStarted = false

    private init() {}

    func prepareForLaunch() {
        guard prepareTask == nil else {
            return
        }

        readiness = .gatheringConsent
        MobileAds.shared.requestConfiguration.setPublisherFirstPartyIDEnabled(false)

        prepareTask = Task { [weak self] in
            await self?.gatherConsentAndStartIfAllowed()
        }
    }

    func presentPrivacyOptionsForm() async throws {
        try await AdsConsentManager.shared.presentPrivacyOptionsForm()

        if AdsConsentManager.shared.canRequestAds {
            startMobileAdsIfNeeded()
            readiness = .ready
        } else {
            readiness = .unavailable("Consent is not available for ad requests.")
        }
    }

    private func gatherConsentAndStartIfAllowed() async {
        let consentError = await AdsConsentManager.shared.gatherConsent()

        if let consentError, AdsConsentManager.shared.canRequestAds == false {
            readiness = .unavailable(consentError.localizedDescription)
            return
        }

        guard AdsConsentManager.shared.canRequestAds else {
            readiness = .unavailable("Consent is not available for ad requests.")
            return
        }

        startMobileAdsIfNeeded()
        readiness = .ready
    }

    private func startMobileAdsIfNeeded() {
        guard isMobileAdsStarted == false else {
            return
        }

        isMobileAdsStarted = true
        MobileAds.shared.start()
    }
}
