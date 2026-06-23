import Foundation
import UserMessagingPlatform

@MainActor
final class AdsConsentManager {
    static let shared = AdsConsentManager()

    var canRequestAds: Bool {
        ConsentInformation.shared.canRequestAds
    }

    var isPrivacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    private init() {}

    func gatherConsent() async -> Error? {
        let parameters = RequestParameters()

        let requestConsentError = await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                continuation.resume(returning: error)
            }
        }

        if let requestConsentError {
            return requestConsentError
        }

        do {
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
            return nil
        } catch {
            return error
        }
    }

    func presentPrivacyOptionsForm() async throws {
        try await ConsentForm.presentPrivacyOptionsForm(from: nil)
    }
}
