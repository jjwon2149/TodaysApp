# DailyFrame Growth UX Experiment Backlog

This backlog packages the growth and UX roadmap into release-ready experiment candidates. Until DailyFrame has live experimentation infrastructure, every variant below is a manual variant comparison: one approved build, copy set, or fixture is compared against another through command evidence, smoke notes, existing approved visual artifacts, and local debug metric events.

Experiments are not successful until the target metric threshold is met with QA evidence and metric evidence. Payment work is limited to value-discovery measurement placeholders; this backlog does not implement payment, paywalls, subscriptions, pricing, checkout, or purchase flows.

## Experiment Queue

### Experiment 1: Five-Second First Screen

- Owner: Growth UX
- Manual variant comparison: Manual variant comparison of current multi-page education vs one-page value screen with direct record CTA.
- Hypothesis: If the first visible onboarding screen states "one photo a day, private archive, streak motivation" with one primary action, more new users will start the first record.
- Target metric: `onboarding_start -> first_record_start` conversion.
- Expected metric movement: Increase first-record starts by 10% relative to the prior manual comparison baseline.
- Affected screens: Onboarding, Home entry sheet handoff.
- Implementation files: `DailyFrame/DailyFrame/Features/Onboarding/OnboardingView.swift`; `DailyFrame/DailyFrame/App/RootView.swift`; `DailyFrame/DailyFrame/Features/Home/HomeView.swift`; `DailyFrame/DailyFrame/ko.lproj/Localizable.strings`; `DailyFrame/DailyFrame/en.lproj/Localizable.strings`; `DailyFrame/DailyFrame/ja.lproj/Localizable.strings`.
- Success threshold: At least 70% of fresh-install QA runs reach the first-record editor from the primary onboarding CTA, and local debug events show a 10% lift in `first_record_start` against the comparison baseline.
- QA scenario: Fresh install, launch, tap the primary onboarding CTA once, and verify via simulator state/log transcript that the editor route opens without another navigation choice. Do not capture new screenshots for this workflow.
- QA evidence: Build log, smoke transcript, local debug JSONL sample containing `onboarding_start` and `first_record_start`, plus existing approved App Store/onboarding visual artifact review notes.
- Rollback trigger: Revert the onboarding handoff and copy if the CTA fails to open the editor, if onboarding completion persistence regresses, or if `first_record_start` does not improve after sufficient comparison data.

### Experiment 2: Photo-Only Reassurance

- Owner: Activation
- Manual variant comparison: Manual variant comparison of existing editor guidance vs explicit "photo only is enough" guidance near the save state.
- Hypothesis: If users know memo and mood are optional, more users will save the first entry after selecting a photo.
- Target metric: `photo_selected -> first_record_saved` conversion.
- Expected metric movement: Increase first-record saves by 8% and reduce no-photo save attempts in smoke notes.
- Affected screens: Entry editor empty, photo-ready, saving, and error states.
- Implementation files: `DailyFrame/DailyFrame/Features/EntryEditor/EntryEditorView.swift`; `DailyFrame/DailyFrame/Features/EntryEditor/EntryEditorViewModel.swift`; localized `Localizable.strings` files.
- Success threshold: At least 90% of photo-selected QA attempts can save with no memo or mood, and event logs show an 8% lift in `first_record_saved` after `photo_selected`.
- QA scenario: Open the editor, verify save is disabled before media, select the fixture image, save without memo or mood, and inspect repository/app-state output for exactly one saved entry.
- QA evidence: XCTest or focused command log, non-screenshot UI transcript, app-state dump, and debug JSONL containing `photo_selected` and `first_record_saved`.
- Rollback trigger: Revert editor copy/status changes if save validation becomes ambiguous, duplicate saves appear, or photo-only save completion falls below threshold.

### Experiment 3: Completion Return Action Set

- Owner: Retention
- Manual variant comparison: Manual variant comparison of return-home-only completion vs reward plus primary reminder, secondary calendar, and skip actions.
- Hypothesis: If completion offers a clear next return action after value is delivered, more activated users will enable reminders or return on day 1.
- Target metric: `completion_viewed -> reminder_enabled` and `completion_viewed -> d1_return`.
- Expected metric movement: Increase reminder action taps by 15% and D1 return by 5%.
- Affected screens: Entry editor completion state, notification permission prompt handoff, calendar detail routing.
- Implementation files: `DailyFrame/DailyFrame/Features/EntryEditor/EntryEditorView.swift`; `DailyFrame/DailyFrame/Features/EntryEditor/EntryEditorViewModel.swift`; `DailyFrame/DailyFrame/Services/Notification/NotificationService.swift`; localized `Localizable.strings` files.
- Success threshold: 80% of completion QA runs expose all three actions, reminder permission is requested only after tapping the reminder action, and `d1_return` improves by 5% in local comparison logs.
- QA scenario: Save the first record, inspect completion text/action state without screenshots, trigger reminder denial, and verify the app remains usable and calendar routing opens the saved day.
- QA evidence: Focused test log, static behavior assertion JSON, simulator launch transcript, and debug JSONL containing `completion_viewed`, `reminder_enabled`, and later `d1_return`.
- Rollback trigger: Revert the completion action set if notification permission appears before explicit intent, calendar routing breaks, or D1 return fails to improve with QA-confirmed behavior.

### Experiment 4: Friendly Empty States

- Owner: Core UX
- Manual variant comparison: Manual variant comparison of neutral empty states vs beginner copy with one next action per state.
- Hypothesis: If empty states explain what happened and the next action, new users will navigate to the core action more confidently.
- Target metric: `visit -> first_record_start` conversion, plus smoke pass rate for empty Home/Calendar/Profile states.
- Expected metric movement: Increase first-record starts by 5% and reduce empty-state confusion notes in QA.
- Affected screens: Home empty/recent empty, Calendar empty/early month, Profile notification and backup states.
- Implementation files: `DailyFrame/DailyFrame/Features/Home/HomeView.swift`; `DailyFrame/DailyFrame/Features/Calendar/CalendarView.swift`; `DailyFrame/DailyFrame/Features/Profile/ProfileView.swift`; localized `Localizable.strings` files.
- Success threshold: 100% of reviewed empty/loading/error states name a user-readable state and one recovery or next action, with no implementation-leak copy in production strings.
- QA scenario: Fresh install and existing-data smoke runs inspect Home, Calendar, and Profile state text through source/localization checks and simulator logs, without screenshot capture.
- QA evidence: Localization key completeness diff, visible-copy leak scan, non-screenshot static UI state audit JSON, and smoke transcript.
- Rollback trigger: Revert copy/state changes if localization parity breaks, primary CTAs become unreachable, or implementation-leak wording returns.

### Experiment 5: Calendar First-Week Framing

- Owner: Retention
- Manual variant comparison: Manual variant comparison of standard month grid explanation vs first-week progress framing for Day 1, Day 3, and Day 7.
- Hypothesis: If the calendar frames the first week as progress rather than an empty archive, activated users will return to fill more days.
- Target metric: `first_record_saved -> d7_return`.
- Expected metric movement: Increase D7 return by 5%.
- Affected screens: Home milestone card, Calendar early-month empty and filled states.
- Implementation files: `DailyFrame/DailyFrame/Features/Home/HomeView.swift`; `DailyFrame/DailyFrame/Features/Home/HomeViewModel.swift`; `DailyFrame/DailyFrame/Features/Calendar/CalendarView.swift`; `DailyFrame/DailyFrame/Services/Streak/StreakService.swift`; localized `Localizable.strings` files.
- Success threshold: D7 return improves by 5% and smoke evidence confirms Day 1/3/7 copy does not conflict with streak/freeze policy.
- QA scenario: Seed local entries for day offsets 1, 3, and 7; inspect computed milestone state and localized copy through test/log artifacts.
- QA evidence: View-model/domain test log, seeded repository dump, event JSONL with `d7_return`, and smoke notes.
- Rollback trigger: Revert milestone framing if streak counts become inconsistent, D7 return does not improve, or first-week copy increases confusion in smoke notes.

### Experiment 6: Permission Recovery Copy

- Owner: Trust and Safety
- Manual variant comparison: Manual variant comparison of generic permission failure copy vs explicit recovery copy for camera, photos, and notifications.
- Hypothesis: If permission-denied states explain recovery without blocking the habit loop, fewer users abandon first record creation.
- Target metric: `first_record_start -> photo_selected` conversion and smoke pass rate for denied permissions.
- Expected metric movement: Increase photo selection recovery by 5% after a denied permission event.
- Affected screens: Entry editor camera/library paths, Profile notification status, completion reminder denial state.
- Implementation files: `DailyFrame/DailyFrame/Features/EntryEditor/EntryEditorView.swift`; `DailyFrame/DailyFrame/Features/EntryEditor/CameraCaptureView.swift`; `DailyFrame/DailyFrame/Features/Profile/ProfileView.swift`; `DailyFrame/DailyFrame/Services/Notification/NotificationService.swift`; localized `Localizable.strings` files.
- Success threshold: 100% of denied camera/photos/notification scenarios preserve app usability and offer one clear recovery path; event logs show 0 private permission tokens or identifiers.
- QA scenario: Force denied permission states, verify recovery copy through logs/static text scans, and confirm record creation remains possible through the alternate photo source.
- QA evidence: Permission-state transcript, privacy scan, focused test or simulator command log, and local event sample where only status tokens are recorded.
- Rollback trigger: Revert recovery copy/flow changes if denied permissions block save, expose sensitive details, or create new hard-to-dismiss prompts.

### Experiment 7: Local Debug Funnel Coverage

- Owner: Measurement
- Manual variant comparison: Manual variant comparison of no local funnel log vs debug-only JSONL funnel log.
- Hypothesis: If the team can inspect a privacy-safe local funnel, growth changes will be shipped with fewer unmeasured regressions.
- Target metric: Presence and validity of required event sequence from visit through activation, return, share placeholder, and payment placeholder.
- Expected metric movement: Increase measurable QA runs from 0% to 100% for the defined funnel events.
- Affected screens: App launch/root, Onboarding, Home, Entry editor, Completion, Profile reminder surface.
- Implementation files: `DailyFrame/DailyFrame/Services/Growth/GrowthEventLogger.swift`; `DailyFrame/DailyFrameTests/GrowthEventLoggerTests.swift`; `docs/growth-event-schema.md`.
- Success threshold: 100% of smoke runs produce a valid debug JSONL sample in Debug builds, Release builds remain no-op, and privacy scans find 0 content, identifiers, tokens, or location payload fields.
- QA scenario: Run focused logger tests and parse the JSONL sample for allowed event names, property allowlists, date formats, and release no-op behavior.
- QA evidence: `xcodebuild` test log, parsed schema JSON, JSONL sample privacy check, release build log, and privacy scan.
- Rollback trigger: Disable or remove logging if Release builds write events, privacy rules are violated, or JSONL validation becomes unreliable.

### Experiment 8: App Store Message Continuity

- Owner: Growth Marketing
- Manual variant comparison: Manual variant comparison of existing screenshot headline sequence vs headline sequence aligned to in-app first screen and completion promise.
- Hypothesis: If the App Store promise matches the first in-app value screen, more installs will proceed to onboarding completion and first-record start.
- Target metric: Store-facing install-to-`onboarding_start` proxy and `onboarding_start -> first_record_start` conversion in QA builds.
- Expected metric movement: Increase first-record starts by 5% among runs using the aligned copy set.
- Affected screens: App Store screenshot copy, Onboarding first screen, Home primary CTA, Completion reward copy.
- Implementation files: `AppStoreScreenshots/`; `README.md`; `DailyFrame/DailyFrame/Features/Onboarding/OnboardingView.swift`; localized `Localizable.strings` files.
- Success threshold: 100% of copy matrix rows confirm the same private one-photo promise across screenshot notes, onboarding, Home, and completion; local debug events do not regress.
- QA scenario: Review existing approved App Store visual artifacts and in-app copy matrix side by side without screenshot capture; future human App Store image review may happen outside this workflow.
- QA evidence: Copy matrix, existing approved visual artifact review notes, no-screenshot compliance scan, and event comparison log.
- Rollback trigger: Revert screenshot/headline copy if the in-app promise diverges from the store promise or conversion metrics regress.

### Experiment 9: Win-Back Restart State

- Owner: Retention
- Manual variant comparison: Manual variant comparison of existing missed-day state vs warm restart/freeze explanation with "start again today" CTA.
- Hypothesis: If missed-day copy is restart-oriented instead of punitive, more users will create a record after a missed day.
- Target metric: Missed-day `visit -> first_record_start` conversion and `first_record_saved` after a missed day.
- Expected metric movement: Increase missed-day first-record starts by 8%.
- Affected screens: Home streak summary, mission state, Calendar missed-day context, completion after restart.
- Implementation files: `DailyFrame/DailyFrame/Features/Home/HomeView.swift`; `DailyFrame/DailyFrame/Features/Home/HomeViewModel.swift`; `DailyFrame/DailyFrame/Services/Streak/StreakService.swift`; `DailyFrame/DailyFrame/Services/Persistence/StreakStateRepository.swift`; localized `Localizable.strings` files.
- Success threshold: Seeded missed-day fixtures preserve correct streak/freeze policy and improve restart starts by 8% in comparison data.
- QA scenario: Seed consecutive, missed-day-with-freeze, and missed-day-reset states; inspect streak output, Home copy, and event log without screenshot capture.
- QA evidence: Streak test log, seeded app-state dump, local event JSONL, and smoke transcript.
- Rollback trigger: Revert win-back copy/state changes if streak policy output changes unexpectedly, freeze behavior regresses, or restart conversion does not improve.

### Experiment 10: Share Card Intent Placeholder

- Owner: Growth UX
- Manual variant comparison: Manual variant comparison of no share affordance vs disabled/share-card mock intent after completion, gated behind a later approved flag.
- Hypothesis: If users express intent to share a private achievement card after completion, a future share feature may be worth building after retention stabilizes.
- Target metric: `completion_viewed -> share_tapped` placeholder event.
- Expected metric movement: Establish a non-zero share intent baseline without affecting activation or D1 return.
- Affected screens: Completion state only, after retention action clarity is stable.
- Implementation files: `DailyFrame/DailyFrame/Features/EntryEditor/EntryEditorView.swift`; `DailyFrame/DailyFrame/Services/Growth/GrowthEventLogger.swift`; `docs/growth-event-schema.md`; future share-card design docs if separately approved.
- Success threshold: Placeholder intent can be measured in 100% of debug QA runs with no exported content, no share target, no recipient, and no change to first-record save completion.
- QA scenario: In a future flagged build, tap the share placeholder and verify only `share_tapped` with allowlisted properties is recorded; no public feed, account, or network behavior is added.
- QA evidence: Flag/config note, local JSONL privacy check, source scan for no network/public-feed implementation, and completion smoke transcript.
- Rollback trigger: Remove the placeholder if it distracts from reminder/calendar actions, decreases D1 return, records content or recipients, or requires social/account infrastructure.

### Experiment 11: Payment Value-Discovery Placeholder

- Owner: Product
- Manual variant comparison: Manual variant comparison of no payment prompt vs non-purchase value-discovery link in a future research-only surface.
- Hypothesis: If users tap a value-discovery placeholder after experiencing the habit loop, pricing research may be justified later without adding payment implementation now.
- Target metric: `payment_interest_tapped` placeholder event after activation and return.
- Expected metric movement: Establish a research-only interest baseline while keeping activation, retention, and trust metrics stable.
- Affected screens: Future Profile or backup/value discovery surface only; not onboarding and not first completion.
- Implementation files: `DailyFrame/DailyFrame/Features/Profile/ProfileView.swift`; `DailyFrame/DailyFrame/Services/Growth/GrowthEventLogger.swift`; `docs/growth-event-schema.md`; future product research doc if separately approved.
- Success threshold: Placeholder can be measured in 100% of debug QA runs after activation with no paywall, product ID, price, subscription, purchase flow, purchase verification, SDK, or payment provider integration.
- QA scenario: Static scope scan plus debug event validation proves no payment implementation exists and only `payment_interest_tapped` with allowlisted placeholder properties is recorded.
- QA evidence: Scope scan, privacy scan, debug JSONL sample, and release no-op build log.
- Rollback trigger: Remove the placeholder if it appears before activation, reduces trust/retention, or introduces any payment implementation dependency.

### Experiment 12: Backup and Widget Value Discovery

- Owner: Lifecycle
- Manual variant comparison: Manual variant comparison of Profile-only discovery vs contextual value hints after users have at least one saved entry.
- Hypothesis: If backup and widget value are introduced after the first entry exists, users will understand archive value without increasing first-run friction.
- Target metric: `d1_return -> d7_return` and smoke pass rate for backup/widget surfaces.
- Expected metric movement: Increase D7 return by 3% among activated users without reducing first-record completion.
- Affected screens: Profile archive summary, widget snapshot/deep link path, backup export affordance.
- Implementation files: `DailyFrame/DailyFrame/Features/Profile/ProfileView.swift`; `DailyFrame/DailyFrame/Services/Export/ExportService.swift`; `DailyFrame/DailyFrame/Services/Widget/WidgetSnapshotService.swift`; `DailyFrame/DailyFrameShared/DailyFrameWidgetSnapshot.swift`; `docs/BackupExportQA.md`.
- Success threshold: 100% of existing-data smoke runs show backup/widget discovery copy only after local value exists, and no first-run onboarding or editor metric regresses.
- QA scenario: Seed one or more entries, validate Profile backup/widget copy, export smoke, widget snapshot JSON, and deep-link handling through logs/state dumps.
- QA evidence: Export manifest/log, widget snapshot JSON, deep-link smoke transcript, and local event comparison.
- Rollback trigger: Revert discovery hints if they appear before activation, break backup/widget behavior, or reduce first-record completion.

## Release Gate

Before any experiment ships, record a release-gate entry with all required artifacts. A missing artifact means the experiment is not ready, even if implementation is complete.

| Gate | Required evidence | Pass condition |
| --- | --- | --- |
| Build | `xcodebuild build` or `xcodebuild test` log from the approved single simulator/device policy for the task | Command exits 0 and success markers are present. |
| Smoke | `docs/qa-smoke-checklist.md` transcript or equivalent CLI/state transcript | Launch, create, save, home reflection, calendar, notifications, and relaunch checks pass for the affected scope. |
| Visual QA | Review of existing approved visual artifacts, design notes, or future human App Store screenshot review notes | No new screenshot capture is required or allowed by this Task 8 workflow; visual approval must cite existing approved artifacts or a future human review outside this execution. |
| Metric event validation | Parsed local debug JSONL and schema check | Required event names, funnel stages, and allowlisted properties are present with no malformed rows. |
| Privacy scan | Static scan over changed docs/source and JSONL sample | No photo content, memo text, identifiers, tokens, location, provider URLs, public feed, account, backend, analytics SDK, or payment implementation is introduced. |
| Rollback readiness | Linked rollback trigger for the experiment | Rollback condition is concrete and maps to owned files or a feature flag/config note. |

## Backlog Operating Rules

- Keep the product private-first and local-first. Do not add public feed, followers, accounts, backend sync, external analytics SDKs, attribution SDKs, or payment implementation from this backlog alone.
- Treat `share_tapped` and `payment_interest_tapped` as debug measurement placeholders only until a separate approved plan defines product behavior.
- Use manual variant comparison wording in plans, PRs, and QA notes until live experiment assignment, segmentation, and analysis infrastructure exists.
- Do not mark an experiment successful without metric data, smoke evidence, release-gate evidence, and rollback readiness.
- For this Task 8 execution specifically, no screenshots are created, captured, or inspected as QA evidence.
