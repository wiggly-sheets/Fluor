# Changelog

## 2.7.0 — 2026-08-15

- Adopt the `com.zm.fluor` bundle identity and safely migrate current settings without carrying stale menu-bar placement or Accessibility refusal state.
- Repair menu-bar item visibility and use an optically centered globe indicator for media-key mode, with an optional keycap background.
- Replace the legacy raster app-icon set with a macOS 26 Icon Composer source that fills the native icon shape.
- Refresh the README hero artwork and use a dedicated, web-sized app icon.
- Remove the DefaultsWrapper package and store settings and per-app rules with native `UserDefaults` types.
- Simplify the About and Settings interfaces, remove obsolete in-app release-note/update code, and clean up deprecated layout behavior.
- Make notification and Accessibility permission handling reflect current system authorization state.

## 2.6.0 — 2026-08-15

- Add a configurable global shortcut for toggling function/media-key mode, including a native recorder and clear button.
- Redesign Settings for current macOS, rename Preferences to Settings, and add menu-bar visibility controls.
- Add centered globe menu-bar indicators for media-key mode, with optional keycap background.
- Make reopening Fluor show Settings when the app is already running.
- Repair Accessibility permission state and prompts.
- Replace legacy launch-at-login code with `SMAppService`.
- Target macOS 26 and remove obsolete IOKit, Objective-C bridging, LetsMove, Sparkle, CoreGeometry, and SmoothOperators code or dependencies.
- Rename the app and documentation assets consistently to Fluor, while retaining the original author credit.
