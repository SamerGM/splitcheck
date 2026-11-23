# SplitCheck — project memory for Claude

Flutter Android bill-splitting app. Owner: Samer (IT professional; wants direct,
structured answers with tables/rankings and a clear recommendation; no filler).
Work branch: `claude/eager-faraday-nd03um` (commit + push there; no PRs unless asked).

## Working agreement (how Samer likes to work)
- For UI changes: **mock up first** (HTML mockup → Playwright screenshot), wait for
  "go"/"proceed", then build. Small fixes can go straight in.
- Every change: English + Arabic (RTL, Arabic digits), light + dark themes.
- After building: real-app screenshots (Flutter web build + Playwright), commit, push,
  trigger the CI build, verify the APK, give the link.
- APK link (always the same): https://github.com/SamerGM/splitcheck/releases/download/test-latest/splitcheck-test.apk
- Releases are named by app version: "Split Check v<pubspec version> (build N)", tag `v<version>-buildN`, APK `splitcheck-v<version>-buildN.apk`. Bump `version:` in pubspec.yaml for v1.1 etc.
- CI: GitHub Actions workflow `build.yml` (workflow_dispatch on the branch, ~7 min).
  Trigger with the GitHub MCP `actions_run_trigger`; check with `actions_list`.
  Verify by downloading the APK (strings in `lib/arm64-v8a/libapp.so`; non-ASCII
  strings are stored UTF-16LE).

## Environment notes
- Flutter: `export PATH=/root/flutter/bin:$PATH` (runs as root; ignore the warning).
- Checks: `flutter analyze` (3 known deprecation infos in voice_service.dart are OK),
  `flutter test` (41 tests).
- Web preview: `flutter build web --release --no-web-resources-cdn`, serve
  `build/web` with `python3 -m http.server 8765`, drive with Playwright
  (`require('playwright')`, Chromium preinstalled). Preset prefs via localStorage keys
  `flutter.language` ("en"/"ar"), `flutter.theme_mode`, `flutter.my_name`,
  `flutter.friend_groups` (JSON string). Click buttons by Semantics label
  (`getByRole('button', {name})`); Arabic clicks may report false timeouts — catch them.
  On web the keyboard Next bar shows whenever a field is focused (kIsWeb).

## Architecture
- `lib/features/wizard/` — full-screen wizard (no chat UI).
  `wizard_controller.dart` (`wizardProvider`, stack of `WNav`, `WStep` enum),
  pages in `pages_setup.dart`, `pages_items.dart`, `pages_charges.dart`,
  shared widgets in `wizard_widgets.dart` (`WizardPage` with `keyboardBar`,
  `OptionCard`, `NumberGrid`, `Pill`, `GlowButton`, `KeyboardNextBar`, `VatBadge`).
- Bill state: `billDraftProvider` (core/services/providers.dart).
- Math: `core/services/split_calculator.dart` (VAT/service/discount proportional;
  delivery + tip split equally; round-up to whole numbers via `roundUpTo`).
  `bill_breakdown.dart` = per-person working; `share_text.dart` (`ShareFormatter`)
  = shared text + card lines. One source for text, card and in-app breakdown.
- Result/share: `features/result/result_card.dart` (share card image + caption text).
- Groups: `features/groups/group_widgets.dart` (⋯ actions, "Who's here today?"
  sheet, Add saved group picker, `GroupEditorPage`); `GroupsNotifier` in
  `settings_provider.dart` (`add`, `replace`, `remove`).
- Settings: `features/settings/settings_page.dart` (language, theme, default country
  + VAT/service, your name, Saved groups).
- Strings: `core/utils/strings.dart` — class `S` with `_t(en, ar)`; add every new
  string in both languages. `toArabicDigits`, `s.n(int)`.
- Spoken numbers: `parseSpokenNumber` in `core/utils/number_parser.dart`
  (used by `VoiceField` numeric fields).
- OCR: `core/services/ocr_service.dart` — Google Cloud Vision (key via
  `--dart-define=GOOGLE_VISION_API_KEY` from GitHub secret) with ML Kit fallback;
  sends `X-Android-Package` / `X-Android-Cert` headers.
- Native: `MainActivity.kt` — `splitcheck/contacts` MethodChannel (system picker).

## Current app flow
Dine-in/Delivery → Prices final? (VAT added first with +VAT badge; "final" second) →
Country → VAT/service rates (Make default / This bill only) → How many people
(saved groups with ⋯; tap → Who's here today?) → Names (Include me card, keyboard
Next bar, Add person / Add saved group, Save as group) → Scan or manual → item count →
item cards (suggestions stay; repeats named Pizza 1/2; Next: Price → Next: Who's
paying? popup) → Review items → Tip (5–25%, Other, glowing No tip, Back+Next) →
Delivery fee (delivery orders; 5–25 in currency) → Discount (% 5–25 or fixed
10–100; No discount) → Whole numbers? → Quick check (items with prices, Edit links,
place name) → Result (share card + text). Top bar: Start over, History, Settings
(no step count). Tap-to-advance on simple choice pages.

## Share text format (agreed)
`🧾 Bill split` · per person `*Name*: 170 AED`, item lines
`• Pizza · Shared ÷3: 50.00 AED + 2.50 AED "VAT" = 52.50 AED`, delivery/tip
`÷N "Persons"` lines, `Total: … (a + b + …) + x AED "round-up" = 170 AED`; end with
`Total after VAT`, `*Grand total after all additions + round-up: … AED*`,
`Split with SplitCheck`. Currency after the number (EN code, AR symbol).
Tested in `test/share_text_test.dart` (the 7118 AED example).

## Icon
Original blue receipt + green tick, enlarged, with a **zigzag bottom edge**
(build #64). Sources: `assets/icon/icon.png`, `icon_foreground.png`,
`icon_background.png`; `flutter_launcher_icons` with `adaptive_icon_foreground_inset: 0`.
Regenerate: `dart run flutter_launcher_icons`.

## Security (report: https://claude.ai/artifact/E4zM5EX1FjMi3ELnq6u4ro)
Done: removed storage/photo permissions, Dart obfuscation in CI, keystores
gitignored, deps updated, Android identity headers for the Vision key.
Owner still to do: restrict the Vision API key in Google Cloud (Android app
`com.samer.splitcheck`, SHA-1 `86:26:6A:26:96:4B:41:AE:19:90:42:1F:5E:64:9E:E9:43:21:F7:ED`,
Cloud Vision only, daily quota, budget alert).

## Open / ideas
- Delete orphaned receipt photo when a scanned bill is abandoned (Start over).
- Before Play Store: move Vision key behind a small server; privacy policy.
- Renumbering: deleting one of two "Pizza 1/2" leaves "Pizza 1" (not reverted).
