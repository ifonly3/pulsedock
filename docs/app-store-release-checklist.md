# App Store Release Checklist

> Last checked against Apple documentation on 2026-06-19.

This project is a native macOS app, `Pulse Dock`, with a WidgetKit extension. The release path below is for Mac App Store distribution through App Store Connect.

## 1. Current Project Readiness

- Xcode project: `PulseDock.xcodeproj`
- App target: `PulseDock`
- Widget extension target: `PulseDockWidgetExtension`
- Minimum macOS version: `14.0`
- Default generated bundle IDs in the Xcode project today:
  - App: `com.ifonly3.pulsedock`
  - Widget: `com.ifonly3.pulsedock.widget`
- Release script: `scripts/archive-app-store.sh`
- Local packaging script: `scripts/package-app.sh`
- Source folders: `Sources/PulseDockApp` and `Sources/PulseDockWidget`
- App Store archive output: `dist/PulseDock.xcarchive`
- Export output: `dist/AppStore`
- App sandbox is enabled for both the app and widget extension.
- App Group entitlement is declared for both targets with suite `group.com.ifonly3.pulsedock`.
- Pre-submit provisioning gate: register `group.com.ifonly3.pulsedock` in Apple Developer Portal, enable it for both app and widget Bundle IDs, and regenerate App Store provisioning profiles.
- Local adhoc signing verifies entitlement shape only; functional App Group sharing must be verified with Xcode automatic signing, TestFlight, or an App Store-signed archive.
- No temporary sandbox exception entitlements are currently declared.
- Privacy manifests are included in both targets:
  - App: `Resources/App/PrivacyInfo.xcprivacy`
  - Widget: `Resources/Widget/PrivacyInfo.xcprivacy`
- Current privacy manifest posture:
  - App: Disk Space `85F4.1`, UserDefaults `CA92.1`, System Boot Time `35F9.1`
  - Widget: Disk Space `85F4.1`, UserDefaults `CA92.1`, System Boot Time `35F9.1`
  - Both targets declare no collected data and no tracking.

## 2. Inputs We Need Before Upload

- Apple Developer Program membership for the publishing account.
- App Store Connect team ID, used as `DEVELOPMENT_TEAM`.
- Final production bundle IDs:
  - App: `APP_BUNDLE_IDENTIFIER`
  - Widget: `WIDGET_BUNDLE_IDENTIFIER`, normally `${APP_BUNDLE_IDENTIFIER}.widget`
- App Store app name, SKU, primary language, category, price, and availability.
- Do not submit as a global English-localized app until scripts/audit-localization.sh reports zero Swift Chinese string findings. App Store metadata/screenshots must also be available in English.
- Support URL: `https://ifonly3.github.io/pulsedock/support/`
- Privacy policy URL: `https://ifonly3.github.io/pulsedock/privacy-policy/`
- Copyright holder string.
- App Review contact information.
- 1 to 10 Mac screenshots, in `.png`, `.jpg`, or `.jpeg`.
- Decision on EU availability and Digital Services Act trader status.

## 3. Apple Account And App Store Connect Setup

1. Enroll in the Apple Developer Program if the publishing account has not already done so. Apple lists the program as a $99 annual membership.
2. In App Store Connect, make sure the Account Holder has signed the latest agreements. Apple does not allow a new app record until the latest agreement is signed.
3. Create or confirm the two Bundle IDs in Certificates, Identifiers & Profiles:
   - `APP_BUNDLE_IDENTIFIER`
   - `WIDGET_BUNDLE_IDENTIFIER`
4. Enable only the capabilities needed by the project. For the current build, keep this lean:
   - App Sandbox
   - WidgetKit extension through the extension target
5. In App Store Connect, create a new app record:
   - Platform: `macOS`
   - Name: final App Store name
   - Primary language: likely Simplified Chinese if the product page is Chinese-first
   - Bundle ID: `APP_BUNDLE_IDENTIFIER`
   - SKU: stable internal SKU, for example `pulse-dock-macos`
6. Fill pricing and availability.
7. If distributing in the EU, complete trader status before submission.

## 4. Product Page Metadata

Prepare these before the first binary upload finishes processing:

- App name: `Pulse Dock`.
- Subtitle: short positioning line.
- Description: explain that it is a local macOS system monitor with app and widgets.
- Keywords: system monitor, widget, CPU, memory, disk, network, status, macOS.
- Category: likely `Utilities`.
- Support URL: `https://ifonly3.github.io/pulsedock/support/`, a public page with contact channel.
- Privacy policy URL: `https://ifonly3.github.io/pulsedock/privacy-policy/`, a public page that matches the current no-collection posture.
- Pre-submit gate: after publishing the docs, both GitHub Pages URLs must return HTTP 200 before submitting the App Store version.
- Current external publishing blocker as of 2026-06-25: both GitHub Pages URLs returned HTTP 404 to `curl --max-time 15 -L -I`; publish the pages and re-run the check before App Store submission.
- Marketing URL: optional.
- Promotional text: optional.
- Copyright: legal owner and year.
- Age rating: answer the updated App Store Connect age-rating questionnaire.
- Review notes:

```text
Pulse Dock is a local macOS system monitor. It samples public on-device system metrics such as CPU, memory, disk, network path/counters, battery/thermal, display, and GPU capability data. It stores local settings, sanitized trend history, and a compact latest widget snapshot in UserDefaults/App Group UserDefaults. It does not create accounts, collect personal data, track users, send analytics, or perform remote network probes. The WidgetKit extension displays local metrics on a system-scheduled timeline.
```

## 5. Screenshots And App Icon

Apple currently requires 1 to 10 screenshots for Mac apps. Use one supported 16:10 size consistently:

- `2880 x 1800`
- `2560 x 1600`
- `1440 x 900`
- `1280 x 800`

Recommended screenshot set:

1. `01-overview.png`: main dashboard overview.
2. `02-cpu-memory.png`: CPU and memory-focused detail view.
3. `03-network-storage.png`: network and storage-focused detail view.
4. `04-widget-popover.png`: menu bar widget/popover.
5. `05-settings-history.png`: settings or history view.

Place final screenshots in `docs/app-store/screenshots/`.

Validate the final screenshot set before upload:

```bash
scripts/validate-app-store-screenshots.sh
```

The app icon is generated by `scripts/generate-app-icon.swift` and included as `Resources/AppIcon.icns`. Before submission, visually inspect the icon in Finder, Dock, and App Store Connect after upload.

## 6. Privacy, Data, And Review Risk

App Store Connect privacy answers should match the current implementation:

- Data collection answer: "No, we do not collect data from this app", assuming no third-party SDKs, analytics, crash reporters, or remote telemetry are added.
- Tracking: no.
- Privacy policy URL: `https://ifonly3.github.io/pulsedock/privacy-policy/`.
- Export compliance: `ITSAppUsesNonExemptEncryption` is declared as `false` in the app Info.plist for the current no-custom-cryptography build.
- User privacy choices URL: optional because the app currently does not collect data.

Keep these checks before every release:

- If any third-party SDK is added, review its privacy manifest and data practices.
- If any outbound probe, analytics, crash reporting, remote config, or account feature is added, update both App Store Connect privacy answers and the in-repo privacy manifests.
- If new required-reason APIs are introduced, update `PrivacyInfo.xcprivacy` for the app and/or widget.
- If any sandbox temporary exception entitlement is added, write review-facing usage information for the entitlement.
- Avoid claims that the app measures system data Apple does not expose. For unavailable metrics, the UI should keep showing "未报告" instead of invented values.
- Local notifications are deferred to a future opt-in feature. If implemented later, update user-facing copy, permission-flow testing, support/privacy docs, and App Store Connect metadata before submission.

## 7. Local Verification Before Archive

Latest local verification on 2026-06-25:

- `swift build` passed.
- `swift test` passed with 256 Swift Testing tests.
- `scripts/generate-xcodeproj.rb` regenerated `PulseDock.xcodeproj`.
- `scripts/package-app.sh` produced `dist/Pulse Dock.app`.
- App and widget binaries are universal (`x86_64 arm64`).
- `codesign --verify --deep --strict --verbose=2 "dist/Pulse Dock.app"` passed.
- App and widget each include one `PrivacyInfo.xcprivacy`.
- `scripts/validate-app-store-screenshots.sh` validated 5 screenshots.
- Launch smoke test passed from a clean process state using bundle id `local.pulsedock`.

Run these before making the App Store archive:

```bash
swift test
```

```bash
scripts/package-app.sh
```

Manually launch `dist/Pulse Dock.app` and verify:

- The app opens without crash.
- Dashboard values update.
- Missing data states are clear and not misleading.
- Widget extension is visible and loads.
- No account, network, or permission prompt appears unexpectedly.
- App name and icon are final.

## 8. Archive And Export

Set release environment variables. Replace values before running:

```bash
export APP_BUNDLE_IDENTIFIER="com.ifonly3.pulsedock"
export WIDGET_BUNDLE_IDENTIFIER="com.ifonly3.pulsedock.widget"
export DEVELOPMENT_TEAM="ABCDE12345"
export MARKETING_VERSION="1.0.0"
export CURRENT_PROJECT_VERSION="1"
```

Create the App Store archive and export:

```bash
scripts/archive-app-store.sh
```

The script will:

- Regenerate the app icon.
- Regenerate `PulseDock.xcodeproj` with the release bundle IDs, version, build number, and team ID.
- Archive scheme `PulseDock` for `generic/platform=macOS`.
- Export with `method = app-store-connect`.
- Write outputs to `dist/PulseDock.xcarchive` and `dist/AppStore`.

After archive/export, check signing and sandbox entitlements:

```bash
codesign -dv --verbose=4 "dist/PulseDock.xcarchive/Products/Applications/Pulse Dock.app"
```

```bash
codesign -d --entitlements :- "dist/PulseDock.xcarchive/Products/Applications/Pulse Dock.app"
```

```bash
codesign -d --entitlements :- "dist/PulseDock.xcarchive/Products/Applications/Pulse Dock.app/Contents/PlugIns/PulseDockWidgetExtension.appex"
```

Remove and verify quarantine attributes before upload:

```bash
xattr -dr com.apple.quarantine "dist/PulseDock.xcarchive"
```

```bash
xattr -lr "dist/PulseDock.xcarchive" | rg "com.apple.quarantine"
```

Expected result for the last command: no output.

## 9. Upload Build

Upload the exported artifact from `dist/AppStore` using one of:

- Xcode Organizer
- Transporter
- `xcrun altool`
- App Store Connect API / Transporter command-line flow

After upload:

1. Wait for Apple processing email.
2. In App Store Connect, open the macOS app version.
3. Select the processed build in the Build section.
4. Complete export compliance questions.
5. Complete app privacy answers and publish them.
6. Upload screenshots.
7. Complete age rating, pricing, availability, and review notes.

## 10. TestFlight

Before first public App Store submission, run a short TestFlight pass:

- Add internal testers first.
- Install on a clean Mac, ideally one not used for development.
- Verify the main app, menu bar behavior, and widget.
- Confirm no hidden debug UI, placeholder text, or test bundle IDs remain.
- Confirm the privacy policy and support links are live and both GitHub Pages URLs return HTTP 200.

## 11. Submit For Review

1. In App Store Connect, select the app version.
2. Verify the selected build.
3. Click `Add for Review`.
4. Open the draft submission.
5. Click `Submit for Review`.
6. Watch App Review messages and reply quickly if they ask about system metrics, sandbox behavior, or privacy.

## 12. Release After Approval

Choose one release option:

- Manual release after approval.
- Automatic release after approval.
- Scheduled release date.

For the first release, manual release is safer. It gives time to re-check the product page, screenshots, availability, and pricing after approval.

## 13. Official References

- Apple Developer Program: https://developer.apple.com/programs/
- Add a new app record: https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/
- Upload builds: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- Manage app privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- Screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- App Sandbox information: https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-sandbox-information/
- Submit an app: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/
- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Upcoming requirements: https://developer.apple.com/news/upcoming-requirements/
