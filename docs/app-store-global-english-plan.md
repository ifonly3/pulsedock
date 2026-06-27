# Pulse Dock Global English Release Plan

> Last checked against Apple documentation on 2026-06-26.

## Goal

Ship Pulse Dock globally with English as the reliable App Store and in-app fallback language, while preserving Simplified Chinese as a supported localization. This is not just an App Store Connect copy pass: the binary, WidgetKit extension, screenshots, support/privacy pages, review notes, tests, and build/run verification all need to agree.

## Current State

- Project shape: SwiftPM package `PulseDock`, generated Xcode project `PulseDock.xcodeproj`, app scheme `PulseDock`.
- Source folders: `Sources/PulseDockApp`, `Sources/PulseDockWidget`, and `Sources/SharedMetrics`.
- Binary localization state: `Resources/AppInfo.plist` and `Resources/WidgetInfo.plist` now declare `CFBundleDevelopmentRegion = en` and `CFBundleLocalizations = [en, zh-Hans]`.
- String resources: app/widget string catalogs, shared `.lproj/*.strings`, and app/widget InfoPlist `.strings` resources are present. Current Swift sources audit clean after the app, widget, SharedMetrics, AppKit menu, and dashboard extraction work.
- Xcode project generator: `scripts/generate-xcodeproj.rb` includes `development_region = en`, `known_regions = [en, zh-Hans, Base]`, and the app/widget catalogs, shared `.lproj/*.strings`, and app/widget InfoPlist `.strings` resources.
- Existing guardrail: `scripts/audit-localization.sh` now exits `0` for the current Swift sources. It uses `rg` when available and falls back to a portable Swift-source scan when `ripgrep` (`rg`) is unavailable.
- Current localization inventory: `docs/app-store-localization-inventory.md` records 0 Swift Han-character matching lines in `Sources/PulseDockApp`, `Sources/PulseDockWidget`, and `Sources/SharedMetrics`.
- Screenshots: five current Mac screenshots are preserved under `docs/app-store/screenshots/zh-Hans/`. English screenshots under `docs/app-store/screenshots/en/` remain pending, and default screenshot validation should fail until the expected five English PNGs exist.
- App Store release checklist still blocks global submission until App Store metadata and screenshots are available in English; the Swift-source localization audit gate is currently passing.
- Build/run entrypoint: no project-local `script/build_and_run.sh` or `.codex/environments/environment.toml` is currently present.

## Apple Constraints To Respect

- App Store Connect metadata localization is separate from binary localization in Xcode. Apple explicitly distinguishes App Store metadata languages from languages added to the app binary.
- If English is the only App Store Connect metadata language, that English metadata can appear across App Store countries or regions; if additional localizations exist, Apple selects the best language match and falls back to the primary language when needed.
- Mac screenshots are required and must use one of Apple's supported 16:10 sizes: `1280x800`, `1440x900`, `2560x1600`, or `2880x1800`.
- If the App Store app record already exists with `zh-Hans` as primary and has been approved, changing primary language later has extra App Review and screenshot approval constraints. If the app record is still pre-submission, choose English as primary before the first global submission.

References:

- Apple: [Localize app information](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information)
- Apple: [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- Apple: [Required, localizable, and editable properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties)
- Apple: [String Catalog localization](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)

## Release Strategy

Recommended v1 global strategy:

1. Make English the primary release language for App Store Connect and the binary fallback.
2. Keep `zh-Hans` as a secondary localization so the existing Chinese product experience is not lost.
3. Treat every user-facing string as localizable, including widget copy, menu items, settings rows, accessibility labels, placeholder text, status text, review-facing docs, and screenshot text.
4. Do not claim global English support until the app can be launched in English with no Chinese UI text except deliberate brand/legal names.

Fallback strategy if timing is tight:

1. Keep `zh-Hans` only.
2. Limit App Store availability to Chinese-language storefront expectations.
3. Do not market or submit as a global English-localized app.

## Implementation Tracks

### Track 0: Preflight, Tooling, And Generator Spike

This track records the localization preflight and generator-resource wiring that now underpin the global English release gate.

Deliverables:

- Keep `scripts/audit-localization.sh` runnable on every expected development machine:
  - use `rg` when present for faster local scans,
  - fall back to the portable `find` + Perl scan when `rg` is unavailable,
  - missing `rg` is non-blocking and must not cause an unexplained `exit 2` in normal onboarding.
- Add a preflight check to the plan and release checklist:

```bash
scripts/audit-localization.sh 2> .build/localization-audit.txt
swift test --filter LocalizationGate
```

The audit command should run normally whether or not `rg` is installed. The focused `LocalizationGate` tests cover the portable fallback path.

- Run an audit inventory before estimating implementation:

```bash
scripts/audit-localization.sh 2> .build/localization-audit.txt || true
```

Current result is captured in `docs/app-store-localization-inventory.md`: the audit exits `0` with 0 line-based Swift Han-character findings.

- Summarize the inventory by source area:
  - `Sources/PulseDockApp`
  - `Sources/PulseDockWidget`
  - `Sources/SharedMetrics`
  - SwiftUI view labels and titles
  - AppKit menu strings
  - Widget strings
  - accessibility strings
  - shared formatting/status strings
- Verify the committed generator layout:
  - generate `PulseDock.xcodeproj`,
  - build the `PulseDock` scheme,
  - inspect `project.pbxproj` for `knownRegions`, `developmentRegion`, resource file references, and copy phases,
  - inspect the built app bundle for localized resources under `Contents/Resources`.
- Keep the generator outcome in this document as the resource-layout record.

Generator spike acceptance:

```bash
DERIVED_DATA_DIR=.build/xcode-derived-data
rm -rf "$DERIVED_DATA_DIR"
scripts/generate-xcodeproj.rb
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Release -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED_DATA_DIR" CODE_SIGNING_ALLOWED=NO build
find "$DERIVED_DATA_DIR/Build/Products/Release/Pulse Dock.app/Contents/Resources" -print | grep -E 'PulseDockApp|InfoPlist|\.lproj|\.strings'
find "$DERIVED_DATA_DIR/Build/Products/Release/Pulse Dock.app/Contents/PlugIns" -path '*.appex/Contents/Resources*' -print | grep -E 'PulseDockWidget|InfoPlist|\.lproj|\.strings'
```

For the current baseline, empty `PulseDockApp.xcstrings` and `PulseDockWidget.xcstrings` may not emit target-specific `PulseDockApp.strings` or `PulseDockWidget.strings` files in the built bundle yet. Treat successful catalog wiring/build plus the expected `.lproj` resources as the baseline; target-specific catalog output files should appear once strings are added or extracted.

Generator spike outcome from Explorer Agent C:

- `xcodeproj` 1.27.0 can add `.xcstrings` as ordinary file references/resources, and Xcode 26.5 compiles non-empty catalogs into localized `.strings` files in the built bundle.
- Do not put multiple files named `Localizable.xcstrings` into one target. Xcode fails with duplicate `Localizable` catalogs.
- Use distinct catalog/table names for target-owned catalogs: `PulseDockApp.xcstrings` and `PulseDockWidget.xcstrings`.
- For shared strings, prefer SwiftPM-compatible `.lproj/*.strings` initially, such as `SharedMetrics.strings` under `Sources/SharedMetrics/Resources/en.lproj` and `Sources/SharedMetrics/Resources/zh-Hans.lproj`.
- `.lproj/*.strings` can be ordinary resources, but `PBXVariantGroup` is canonical in generated Xcode projects. Do not mix ordinary resource refs and variant groups for the same output.
- Set generator localization metadata explicitly: `development_region = en` and `known_regions = [en, zh-Hans, Base]`.
- SwiftPM behavior differs for `.xcstrings`; `.lproj/*.strings` plus `defaultLocalization: "en"` is safer for `SharedMetrics` tests.
- Current generator wiring includes the app/widget `.xcstrings`, app/widget InfoPlist `.strings`, shared `SharedMetrics.strings`, `development_region = en`, and `known_regions = [en, zh-Hans, Base]`.

### Track 1: Binary Localization

Current status and remaining guardrails:

- Target-specific string catalogs with distinct catalog/table names are present:
  - `Sources/PulseDockApp/Resources/PulseDockApp.xcstrings`
  - `Sources/PulseDockWidget/Resources/PulseDockWidget.xcstrings`
- Shared string resources using SwiftPM-compatible `.lproj/*.strings` are present:
  - `Sources/SharedMetrics/Resources/en.lproj/SharedMetrics.strings`
  - `Sources/SharedMetrics/Resources/zh-Hans.lproj/SharedMetrics.strings`
- Info.plist localization resources for app and widget display names, copyright, privacy/support URL labels where applicable are present:
  - `Resources/App/en.lproj/InfoPlist.strings`
  - `Resources/App/zh-Hans.lproj/InfoPlist.strings`
  - `Resources/Widget/en.lproj/InfoPlist.strings`
  - `Resources/Widget/zh-Hans.lproj/InfoPlist.strings`
- `Resources/AppInfo.plist` and `Resources/WidgetInfo.plist` declare:
  - `CFBundleDevelopmentRegion = en`
  - `CFBundleLocalizations = [en, zh-Hans]`
  - keep `CFBundleName` and `CFBundleDisplayName` as `Pulse Dock` / `Pulse Dock Widget` unless localized display names are explicitly desired.
- `scripts/generate-xcodeproj.rb` includes localization resources in both app and widget targets.
- Current Swift sources audit clean after replacing hard-coded user-facing strings with localization keys across:
  - App menus: About, Settings, Support, Privacy Policy, Hide/Quit labels.
  - Dashboard sidebar and page titles.
  - Settings page rows.
  - Metric labels, status labels, missing-data text, trend/history text.
  - Shared formatting labels in `SharedMetrics`.
  - Widget display name, description, header labels, placeholder/loading text, accessibility labels.
- Preserve nonlocalizable values:
  - Bundle identifiers.
  - File names and process names.
  - Metric units and SI/binary unit symbols where the symbol itself is standard.
  - Brand name `Pulse Dock`, unless marketing decides to translate it.

Engineering note:

- Prefer `String(localized:)`, `LocalizedStringResource`, or SwiftUI-localized `Text` keys depending on call site.
- Do not scan localization resource files for this gate once `zh-Hans` files exist; the audit should keep scanning Swift sources only and use `\p{Script=Han}` so Han punctuation such as `·` does not create false positives.
- Do not change `MetricSnapshot` coding keys, persisted field names, or legacy decode behavior while replacing display strings. Shared model text should move behind localization APIs without changing stored JSON keys or Codable compatibility.

Current source audit gate:

- Use `docs/app-store-localization-inventory.md` as the Track 1 baseline: 0 line-based Swift findings currently remain.
- `Sources/PulseDockApp`, `Sources/PulseDockWidget`, and `Sources/SharedMetrics` currently audit at zero Swift Han-character matches.
- Keep Codable keys, stored JSON field names, and legacy decode behavior unchanged while preserving the clean `Sources/SharedMetrics` audit state.
- Keep `AppDelegate.swift`, `SystemDashboardWidget.swift`, `MetricsStore.swift`, and `DashboardView.swift` at zero Swift Han-character matches during later cleanup.

### Track 2: Localization Tests And Audit Gates

Deliverables:

- Keep `scripts/audit-localization.sh` verifying that it:
  - scans Swift source for Chinese literals,
  - ignores `zh-Hans` localization resources,
  - uses `rg` when available and the portable `find` + Perl fallback when `rg` is unavailable,
  - fails on unlocalized `Text("中文")`, `Button("中文")`, `.description("中文")`, and accessibility labels in Swift.
- Add a dedicated test file, not another block inside `MetricFormattingTests.swift`:
  - `Tests/SharedMetricsTests/LocalizationGateTests.swift`
- Add tests in `LocalizationGateTests.swift` for:
  - `CFBundleLocalizations` includes both `en` and `zh-Hans`.
  - `CFBundleDevelopmentRegion` is `en` for global release.
  - app/widget string catalog files and shared `.lproj/*.strings` files exist.
  - generator includes localization resources.
  - `scripts/audit-localization.sh` is part of the release checklist.
  - App Store metadata docs include English copy.
  - screenshot validator supports English screenshot directories.
- Keep model/Codable compatibility tests near existing metric tests:
  - add or preserve round-trip tests for `MetricSnapshot`,
  - explicitly protect legacy aliases such as running-app `runningApps` to `topProcesses` decode behavior,
  - verify localization changes do not alter persisted JSON field names.
- Add a local English launch smoke checklist:
  - launch under a clean user account or temporary language setting,
  - verify main window, menu bar popover, settings, history, and widget have English UI.

Regression note:

- Earlier RED checks for English resources, generator support, and localized strings should now be green. New gate tests should fail only for genuinely unimplemented release gates.

Acceptance gate:

```bash
scripts/audit-localization.sh
swift test --filter LocalizationGate
swift test
```

### Track 3: App Store Connect English Metadata

Recommended primary language:

- English (U.S.) unless marketing wants a different English locale.

Draft English metadata:

- App name: `Pulse Dock`
- Subtitle: `Local system monitor for your Mac`
- Promotional text: `Track CPU, memory, storage, network, power, thermal, display, and widget status using on-device macOS signals.`
- Keywords: `system monitor,mac widget,cpu,memory,disk,network,battery,thermal,menu bar,status`
- Category: `Utilities`
- Description:

```text
Pulse Dock is a native macOS system monitor built for quick, calm visibility into your Mac.

Open the dashboard for detailed CPU, memory, storage, network, power, thermal, display, GPU, uptime, and running app status. Use the menu bar popover for quick checks, and add the WidgetKit extension to your desktop for glanceable system status.

Pulse Dock samples public on-device macOS signals. It does not create accounts, collect personal data, track users, send analytics, or perform remote network probes.
```

- What's New for 1.0:

```text
Initial release of Pulse Dock for macOS, including the dashboard, menu bar popover, and desktop widgets.
```

- App Review notes:

```text
Pulse Dock is a local macOS system monitor. It samples public on-device system metrics such as CPU, memory, disk, network path/counters, battery/thermal state, display, and GPU capability data. It stores local settings, sanitized trend history, and a compact latest widget snapshot in UserDefaults/App Group UserDefaults. It does not create accounts, collect personal data, track users, send analytics, or perform remote network probes. The WidgetKit extension displays local metrics on a system-scheduled timeline.
```

App Store Connect checklist:

- Set primary language to English before the first global submission if possible.
- Add `zh-Hans` metadata as a secondary localization if keeping Chinese users supported.
- Ensure privacy policy URL and support URL are live and English-readable.
- Keep app privacy answers aligned with the current no-collection posture.
- Confirm availability, EU DSA trader status, age rating, and export compliance before submission.

### Track 4: English Screenshots

Deliverables:

- Capture English screenshots at one supported Mac size, preferably `2880x1800` for App Store quality or `1440x900` for easier local capture.
- Recommended folder structure:

```text
docs/app-store/screenshots/en/
  01-overview.png
  02-cpu-memory.png
  03-network-storage.png
  04-widget-popover.png
  05-settings-history.png

docs/app-store/screenshots/zh-Hans/
  01-overview.png
  02-cpu-memory.png
  03-network-storage.png
  04-widget-popover.png
  05-settings-history.png
```

- `scripts/validate-app-store-screenshots.sh` supports locale-specific directories and requires the expected five screenshots for `en` before global release.
- Preserve the migrated Chinese screenshot baseline while adding English assets:
  - keep current `docs/app-store/screenshots/zh-Hans/01-overview.png` through `05-settings-history.png` for Chinese metadata,
  - leave no uploadable screenshots in the flat root directory,
  - keep only `.gitkeep` or a short README in `docs/app-store/screenshots/`.
- Screenshot validation defaults:
  - for global release, default `SCREENSHOT_LOCALE=en` and `SCREENSHOT_DIR=docs/app-store/screenshots/$SCREENSHOT_LOCALE`,
  - allow `SCREENSHOT_LOCALE=zh-Hans` or an explicit `SCREENSHOT_DIR` override for locale-specific validation.
- Current status: `docs/app-store/screenshots/en/` contains no uploadable English PNGs yet, so default screenshot validation is expected to fail until `01-overview.png` through `05-settings-history.png` are captured.
- Verify screenshots contain no Chinese UI text in the English set.
- Upload English screenshots to the English App Store Connect localization.
- Upload Chinese screenshots only if shipping `zh-Hans` metadata.

Acceptance gate:

```bash
SCREENSHOT_LOCALE=en scripts/validate-app-store-screenshots.sh
SCREENSHOT_LOCALE=zh-Hans scripts/validate-app-store-screenshots.sh
```

### Track 5: Support, Privacy, And Web Pages

Deliverables:

- Ensure these URLs return HTTP 200:
  - `https://ifonly3.github.io/pulsedock/privacy-policy/`
  - `https://ifonly3.github.io/pulsedock/support/`
- Keep the English privacy policy accurate:
  - on-device sampling,
  - local settings/history/widget snapshot,
  - App Group UserDefaults,
  - no accounts,
  - no tracking,
  - no analytics,
  - no remote probes.
- Add optional `zh-Hans` support/privacy pages only if App Store metadata includes Chinese localizations.
- Add a release gate that verifies these URLs before archive/upload.

Acceptance gate:

```bash
curl --max-time 15 -L -I https://ifonly3.github.io/pulsedock/privacy-policy/
curl --max-time 15 -L -I https://ifonly3.github.io/pulsedock/support/
```

### Track 6: Build, Run, And Review Verification

Deliverables:

- Add `script/build_and_run.sh` as the stable local run entrypoint:
  - kill existing `Pulse Dock`,
  - regenerate `PulseDock.xcodeproj`,
  - build/package with `scripts/package-app.sh`,
  - launch `dist/Pulse Dock.app`,
  - support `--verify`, `--logs`, and `--telemetry`.
- Add `.codex/environments/environment.toml` so Codex desktop has a Run action.
- Keep App Store archive path unchanged:

```bash
APP_BUNDLE_IDENTIFIER=com.ifonly3.pulsedock \
WIDGET_BUNDLE_IDENTIFIER=com.ifonly3.pulsedock.widget \
DEVELOPMENT_TEAM=ABCDE12345 \
scripts/archive-app-store.sh
```

Verification sequence:

```bash
scripts/audit-localization.sh
swift test
DERIVED_DATA_DIR=.build/xcode-derived-data
rm -rf "$DERIVED_DATA_DIR"
scripts/generate-xcodeproj.rb
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Release -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED_DATA_DIR" CODE_SIGNING_ALLOWED=NO build
find "$DERIVED_DATA_DIR/Build/Products/Release/Pulse Dock.app/Contents/Resources" -print | grep -E 'PulseDockApp|InfoPlist|\.lproj|\.strings'
find "$DERIVED_DATA_DIR/Build/Products/Release/Pulse Dock.app/Contents/PlugIns" -path '*.appex/Contents/Resources*' -print | grep -E 'PulseDockWidget|InfoPlist|\.lproj|\.strings'
scripts/package-app.sh
SCREENSHOT_LOCALE=en scripts/validate-app-store-screenshots.sh
SCREENSHOT_LOCALE=zh-Hans scripts/validate-app-store-screenshots.sh
```

Manual QA:

- Launch in English and inspect all major pages.
- Confirm menu bar popover is English.
- Confirm WidgetKit gallery and widget families are English.
- Confirm support/privacy links open English pages.
- Confirm screenshots match the English UI.
- Run a TestFlight pass on a clean Mac before public submission.

## Remaining Implementation Order

1. Keep `scripts/audit-localization.sh` and generator resource checks in release verification.
2. Add or preserve localization gate and Codable compatibility tests for `MetricSnapshot` and running app legacy key behavior.
3. Update App Store metadata docs with final English copy.
4. Capture English screenshots into `docs/app-store/screenshots/en/`, keep the Chinese screenshot baseline in `docs/app-store/screenshots/zh-Hans/`, and validate both directories.
5. Add build/run helper and Codex Run action.
6. Run full verification and TestFlight.

## Definition Of Done

- `CFBundleDevelopmentRegion = en`.
- `CFBundleLocalizations` includes `en` and `zh-Hans`.
- No Chinese user-facing text remains in Swift sources.
- `scripts/audit-localization.sh` works with `rg` when present and with the tested portable fallback when `rg` is unavailable.
- Generator support for distinct app/widget `.xcstrings`, shared `.lproj/*.strings`, `knownRegions`, and copied bundle resources is proven by the spike and committed.
- English string catalogs cover app and widget strings, and English `SharedMetrics.strings` covers shared metric formatting.
- English App Store metadata is complete.
- English privacy/support URLs are live.
- English screenshots pass validation.
- Existing Chinese screenshots are preserved under `docs/app-store/screenshots/zh-Hans/`; the flat screenshot root no longer contains uploadable assets.
- Screenshot validation defaults to `SCREENSHOT_LOCALE=en`, supports `SCREENSHOT_LOCALE=zh-Hans` or explicit `SCREENSHOT_DIR`, and fails by default until the five English screenshots exist.
- `swift test` passes.
- Xcode Release build for `PulseDock` passes.
- TestFlight on a clean Mac passes for app, menu bar popover, and widget.

## Explicit Non-Goals

- Do not add machine-translated additional languages beyond English and Simplified Chinese in this pass.
- Do not add analytics, crash reporting, accounts, or notification permissions as part of localization.
- Do not change the product name unless marketing explicitly decides to localize `Pulse Dock`.
- Do not submit globally while only App Store metadata is English but the binary still contains Chinese UI.
