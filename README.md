# Pulse Dock

Pulse Dock is a native macOS system monitor with a desktop WidgetKit extension. It shows local CPU, memory, storage, network, battery, thermal, display, GPU, uptime, and running app status using public macOS APIs.

The app is designed for a quiet macOS utility workflow: a dashboard window for deeper inspection, a menu bar popover for quick checks, and system widgets for glanceable desktop status.

## Status

- Native macOS app target: `SystemDashboard`
- Widget extension target: `SystemDashboardWidgetExtension`
- Minimum macOS version: `14.0`
- Intended production bundle IDs:
  - App: `APP_BUNDLE_IDENTIFIER=com.ifonly3.pulsedock`
  - Widget: `WIDGET_BUNDLE_IDENTIFIER=com.ifonly3.pulsedock.widget`

## Development

Run the SwiftPM build and tests:

```bash
swift build
swift test
```

Generate the Xcode project used for local packaging and App Store archive flows:

```bash
scripts/generate-xcodeproj.rb
```

Create a local test app bundle:

```bash
scripts/package-app.sh
```

Install the app and register the widget extension locally:

```bash
scripts/install-system-widget.sh
```

## App Store Archive

Use `scripts/archive-app-store.sh` for App Store Connect archives. The script requires production signing inputs and keeps the app and widget bundle identifiers aligned:

```bash
APP_BUNDLE_IDENTIFIER=com.ifonly3.pulsedock \
WIDGET_BUNDLE_IDENTIFIER=com.ifonly3.pulsedock.widget \
DEVELOPMENT_TEAM=ABCDE12345 \
MARKETING_VERSION=1.0.0 \
CURRENT_PROJECT_VERSION=1 \
scripts/archive-app-store.sh
```

## Privacy

Pulse Dock samples local system metrics on device. It does not create accounts, collect personal data, track users, run analytics, or send remote probes. Release privacy details live in `docs/data-capability-audit.md` and `docs/app-store-release-checklist.md`.

## License

MIT. See `LICENSE`.
