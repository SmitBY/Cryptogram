# Cryptogram

Cryptogram is a SwiftUI implementation of a logic puzzle where you decode famous phrases in several languages. The interface focuses on responsive tile input, gentle animations, and accessible hinting.

## Features
- phrases in Russian, English, German, French, Italian, Spanish, and Portuguese;
- tile-based input with automatic move to the next empty cell after a correct letter;
- a hint system with daily refresh and a special-last-chance path before a loss;
- a victory overlay that shows the full phrase and author before moving to the next challenge.

## Building and running
```bash
xcodebuild -project Cryptogram.xcodeproj -scheme Cryptogram -sdk iphonesimulator -configuration Debug build
```
Then launch via Xcode or `xcrun simctl` if you prefer the command line.

For device deployment use `ios-deploy --bundle <path>/Cryptogram.app --justlaunch` after building with `-destination 'generic/platform=iOS'`.

## Localization
UI strings live in `Localizable.xcstrings`.
`AppLocalization.swift` stores language metadata and the helper that resolves catalog strings for the app-selected locale.

## Maintenance
To adjust gameplay, hint logic, or phrase sets edit `ProgressSupport.swift`, `PhraseStore.swift`, and the per-language `phrases*.txt` banks. Keep phrase banks native to each language instead of translating one source list across locales.
