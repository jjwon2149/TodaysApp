import Foundation

enum AdConfiguration {
    static let debugBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"

    private static let bannerAdUnitIDInfoKey = "DFBannerAdUnitID"

    static var bannerAdUnitID: String? {
        #if DEBUG
        debugBannerAdUnitID
        #else
        configuredBannerAdUnitID
        #endif
    }

    private static var configuredBannerAdUnitID: String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: bannerAdUnitIDInfoKey) as? String else {
            return nil
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false, value.contains("$(") == false else {
            return nil
        }

        return value
    }
}
