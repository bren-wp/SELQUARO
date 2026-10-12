# SELQUARO

**Your purchases. Safely kept.** A privacy-first receipt and warranty organizer for Android and iOS.

SELQUARO works offline, **without accounts, sign-in, cloud servers, analytics, ads, trackers, or demo purchases**. The vault starts empty. Only user-added purchases appear.

## Features in 0.1.0

- Premium dark dashboard, searchable vault, expiry overview, document scanner, and security settings
- Create, edit, and delete purchase records, prices, categories, dates, notes and serial numbers
- Capture receipt images or import PDF and image documents
- On-device OCR to help populate editable receipt fields; no receipt text is uploaded
- AES-256-GCM encrypted local records and attachments; secret key held in OS secure storage
- Optional device biometric unlock and full local vault deletion
- No automatic guesswork about legal warranties: expiration dates are set by the user

## Run

Install Flutter SDK and Android Studio / Xcode, then:

```bash
flutter create --platforms=android,ios --org com.selquaro .
flutter pub get
flutter run
```

The GitHub CI generates standard Flutter native platform scaffolds, configures Android backup exclusion and iOS camera permission, analyzes and tests the app, and builds release artifacts.

## Release and signing

Version: **0.1.0+1**. The automated release only executes after the Android and iOS build jobs have succeeded. Android store delivery requires a permanent signing identity configured as GitHub Actions secrets. CI-generated debug-signed APKs must not be used for app-store distribution.

iOS archive signing and App Store distribution require an Apple Developer signing identity and provisioning profile. CI uses `flutter build ios --no-codesign` as a compilation check; it is not a distributable IPA.

See [SECURITY.md](SECURITY.md) for threat model and limitations.

## Design

Dark-navy surfaces, restrained cyan accents and responsive rounded components follow the supplied SELQUARO concept references. The illustrations are **concept art**, not evidence of application functionality. Screen captures in this repo must come from actual running builds; no sample accounts or fabricated screenshots are included.

## Privacy

No network permissions are requested by the application. Imported documents are copied to app-private encrypted storage; source originals remain untouched. Uninstalling the app can destroy access to encrypted documents. The user is responsible for retaining original receipts until a portable encrypted backup feature ships.
