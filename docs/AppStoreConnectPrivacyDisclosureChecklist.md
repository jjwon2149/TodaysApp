# App Store Connect Privacy Disclosure Checklist

Date: 2026-06-23

Scope: DailyFrame iOS AdMob banner MVP. Re-check this checklist after PHO-78 lands because the final App Store Connect answers must match the SDK version, Info.plist, privacy manifest, ad formats, consent flow, and placements that ship.

This is a release checklist, not legal advice.

## Implementation Assumptions

- Google Mobile Ads SDK is used for AdMob banner ads.
- Google User Messaging Platform is used before ad requests where consent is required.
- MVP is banner-only. Do not ship interstitial, rewarded, native, or app-open ads.
- MVP does not request App Tracking Transparency and does not introduce IDFA-dependent personalized ad tracking.
- DailyFrame does not send private entries, photos, image files, or memos to Google for ads.
- If consent is unavailable or ads cannot be requested, the ad slot collapses.
- If UMP reports that privacy options are required, expose `Profile > Privacy and storage > Ad privacy choices` before live ads ship.

## App Store Connect Questionnaire

- Confirm that App Store Connect no longer says DailyFrame has no third-party SDK advertising data collection.
- Disclose Google AdMob as a third-party advertising SDK.
- Review and disclose data types collected by the Google Mobile Ads SDK, based on the final SDK privacy manifest and Google's current disclosure guidance:
  - Location: coarse location derived from IP address, if applicable in App Store Connect.
  - Identifiers: device identifiers, including advertising identifiers where available and app- or developer-bounded identifiers.
  - Usage Data: advertising data and product interaction data.
  - Diagnostics: crash data and performance data.
  - Other Data: IP address or other SDK data not mapped elsewhere by App Store Connect.
- Mark data uses that apply to the final implementation, including third-party advertising, advertising measurement, analytics, product personalization, fraud prevention, security, and performance diagnostics where applicable.
- Do not answer "No" to tracking until the final ad personalization settings, UMP configuration, Apple tracking definition, and SDK privacy manifest have been reviewed together.
- If the release changes to IDFA-based personalized advertising, add ATT implementation, add `NSUserTrackingUsageDescription`, update privacy/support copy, and update App Store Connect tracking answers before submission.
- If mediation, advanced reporting, experiments, or additional ad formats are added later, repeat the disclosure review for every additional SDK or optional feature.

## UMP and Privacy Options

- Create and maintain the required Privacy & messaging configuration in AdMob.
- On every launch, refresh consent information before ad requests where required.
- Before requesting ads, confirm the SDK can request ads.
- If privacy options are required, provide a user-accessible entry point at `Profile > Privacy and storage > Ad privacy choices`.
- If privacy options are not required for the user's region/configuration, no extra in-app privacy options button is required, but the release notes/checklist should record that UMP returned no requirement.

## Info.plist and SDK Checks

- Add `GADApplicationIdentifier` for the DailyFrame AdMob app.
- Add `SKAdNetworkItems` using Google's current iOS AdMob list at implementation time.
- Keep the release banner ad unit in configuration/build settings rather than hardcoding it in user-facing docs.
- Debug/simulator builds must use Google's iOS banner test ad unit only.
- Verify there is no `NSUserTrackingUsageDescription` or `AppTrackingTransparency` usage unless the release explicitly changes the ATT policy.

## Placement and Format Checks

- Allowed format for MVP: banner only.
- Forbidden formats: interstitial, rewarded, native, app-open.
- Forbidden placements: EntryEditor, camera capture, photo picker, save completion, widget, and immediate deep-link entry.
- No-fill, offline, consent-blocked, or SDK failure states must collapse the ad slot and leave no empty UI.

## Public Documentation Checks

- `privacy.md` discloses Google AdMob, UMP consent handling, SKAdNetwork, no ATT in MVP, and Google policy links.
- `support.md` includes a user-facing ads/privacy FAQ.
- In-app Profile privacy copy is localized for supported languages.
- Public docs do not include provider secrets or user data.

## Official References

- Google AdMob iOS setup: https://developers.google.com/admob/ios/quick-start
- Google AdMob iOS UMP privacy setup: https://developers.google.com/admob/ios/privacy
- Google AdMob iOS app store data disclosure: https://developers.google.com/admob/ios/privacy/data-disclosure
- Google AdMob iOS privacy strategies and SKAdNetwork: https://developers.google.com/admob/ios/privacy/strategies
- Apple App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/
