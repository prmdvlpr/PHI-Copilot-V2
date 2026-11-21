# PHI Daily Check validation

## v2 checkout

All 51 portable engine and chat checks passed with Swift 6.2.4 on Linux. Both targets’ sources passed Swift syntax parsing. The Xcode target references, shared schemes, workspace XML, and bundled dataset passed structural checks. Xcode, the Apple SDKs, and Apple Intelligence are required to verify Apple builds and model behavior.

Run the existing portable check with `sh check-engine.sh`. It covers engine behavior and the deterministic chat evidence, consent, follow-up, token estimate, and screening of structured chat output. Typed Foundation Models generation still requires Xcode and an eligible device to verify.

For iOS, build the **PHIDailyCheck** scheme on a Mac and verify the four tabs. In Ask PHI, send a recovery question followed by “What does that mean?” Test the **AI unavailable** demo scenario, change replay days during a pending reply, revoke HRV access, and use **New chat** to reset the estimate. On an eligible iPhone with Apple Intelligence enabled, repeat with optional AI enabled and check that the response source and the figures agree with Insights.

## Baseline archive validation — 14 November 2026

The following results were recorded before v2.

## Verified

- Xcode 27.2 (27B52), iPhoneSimulator27.2 SDK.
- Generic iOS Simulator **Debug build succeeded** with signing disabled. Built arm64 and x86_64; no package downloads required.
- 21 Foundation-only engine checks passed, including separate medians and deltas, exclusion of today, insufficient calendar history, missing HRV, consent opt-out, empty input, non-finite values, duplicate latest day, input ordering, and deterministic explanation without AI.
- Baseline fixture: RHR 60 bpm and SDNN 52 ms from 14 historical days; changed day: RHR 67 bpm and SDNN 42 ms.

Build command (project directory):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project PHIDailyCheck.xcodeproj -scheme PHIDailyCheck \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/phi-dailycheck-build \
  CODE_SIGNING_ALLOWED=NO build
```

The command selects Xcode for that command only; it does not change the Mac's global developer directory.

## Not verified

Simulator launch, on-screen layout, VoiceOver interaction, and physical-device execution have not been tested. The session could compile with the installed SDK, but could not communicate with CoreSimulator services. A successful generic build is not a runtime/UI test.

No Apple Health integration, physiological validation, or AI model inference was performed. This is a demo, not a medical decision tool.

## Manual flow to verify in Xcode

1. Fresh app → Consent → allow both metrics → changed day values 67/60 bpm and 42/52 ms.
2. Explanation uses those same figures; context choice does not change the measurements.
3. Access data → disable HRV → return to Today/Explanation: HRV figures omitted.
4. Disable resting HR → Today/Explanation show fallback, not a replacement HRV insight.
5. Restore both toggles and select each demo scenario: steady, missing HRV, short history, no data, no AI.
6. Confirm long text, larger accessibility text, light/dark appearance and iPad widths fit before presentation.

## Pembaruan profil workshop — 14 November 2026

- Generic iOS Simulator Debug build versi profil berhasil (arm64 dan x86_64), termasuk resource JSON yang dibundel.
- 30 engine checks lulus; pemeriksaan tambahan meliputi dua profil, 60 hari masing-masing, replay tanpa future samples, baseline per metrik dan fallback hari awal.
- 120 record RHR/SDNN pada resource dicocokkan terhadap nilai asli daily_summary.csv secara independen melalui Python; tidak ada nilai yang diubah.
- Adi/Tom hari 44: RHR 65.6 vs median 61.05 bpm; SDNN 42.6 vs 51.35 ms.
- Hanna/Maya hari 30: RHR 52.0 vs median 51.75 bpm; SDNN 75.2 vs 72.45 ms. UI membulatkan tampilan satu desimal; perhitungan mempertahankan presisi.
- UI runtime, perpindahan profil di simulator dan perangkat fisik belum diuji. Belum ada target watchOS.

## Apple Intelligence integration — 14 November 2026

Current source includes FoundationModels on-device generation behind iOS 26 availability and explicit app opt-in. Earlier no-AI statements describe the initial prototype.

- Generic iOS Simulator Debug build succeeded on Xcode 27.2 for arm64 and x86_64 with deployment minimum iOS 17 and guarded iOS 26 APIs. No macro sandbox settings were changed.
- 38 engine/policy checks passed. Added tests cover input evidence, opted-out HRV omission, numeric-output rejection, basic clinical-keyword rejection, empty output and insufficient-evidence rejection. These are deterministic policy tests, not tests of the language model.
- Actual SystemLanguageModel generation, availability statuses on devices, supported languages, refusal behavior, request cancellation, timeout and UI transitions still require device testing. No successful AI inference is claimed by this build.
- Verify on iPhone: opt in → Adi day 44 → Explanation → Generate; inspect source/language and compare to computed facts. Revoke HRV/switch to Hanna/change replay during generation and verify old results disappear. Test noAI demo mode, unavailable device, cancellation and fallback.
- App's model-output screen is heuristic. It does not guarantee factual correctness, proper trend interpretation, or clinical safety. A successful screen is labeled as draft AI, with deterministic evidence still visible.

## English UI update — 14 November 2026

All four experiences, demo controls, accessibility/chart labels, rule-based text and availability/error states translated to English. English is requested explicitly from Apple Intelligence; English support is checked before generation. Numeric logic and data are unchanged. Generic iOS Simulator Debug build succeeded; 38 existing engine/policy checks passed. Layout and generated AI output have not been verified on a running device.

## Apple Watch target — 14 November 2026

- Added standalone English watchOS 10+ target and shared scheme PHIDailyCheckWatch. Four required experiences, Adi/Hanna replay, consent, evidence and fallback are implemented using Swift rules.
- Generic watchOS Simulator Debug build succeeded on WatchSimulator27.2 SDK. Existing iOS Simulator Debug build also succeeded after the project changes.
- Built Watch Info.plist verified WKApplication=true and WKWatchOnly=true. Bundled workshop JSON is byte-identical in Watch app, iPhone app and project resource. Shared engine source is compiled into both targets.
- Existing 38 engine/policy checks were not rerun: no numerical engine or policy code changed in this update.
- Watch UI rendering, physical Watch installation, accessibility and runtime navigation have NOT been tested; CoreSimulator service access remains unavailable in this session. No phone-watch sync, sensor capture or Watch AI inference has been implemented or claimed.

### Manual Watch checks

Fresh launch → Consent → Continue → Adi day44 values → Why this insight. Demo & access → Hanna day30, then day10 for insufficient history. Disable HRV and confirm omitted evidence; disable resting HR and confirm primary fallback. Restart consent should return to the root consent screen. Test smallest supported Watch display and accessibility text size before presenting.

## One-screen Watch summary — 14 November 2026

User requested a circular, glanceable Watch summary with full details on iPhone. Replaced multi-screen Watch evidence/explanation navigation with a compact summary after consent. Ring displays resting HR and a qualitative status, with SDNN beneath; no invented percentage score. Settings/consent remain available through a gear sheet. Insufficient data appears within the same summary.

Generic watchOS Simulator Debug build succeeded. No shared numerical, dataset, policy or iPhone source changed; existing engine tests not repeated. Runtime visual fit on actual Watch sizes and accessibility text remains unverified. ViewThatFits uses a scroll alternative when the compact stack does not fit. No automatic iPhone handoff or synchronization is claimed.
