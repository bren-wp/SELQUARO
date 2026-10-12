# SELQUARO 0.2.0 — Android feature and privacy update

## Delivered
- Privacy-first Android/iOS shared codebase and refined dark SELQUARO interface
- On-device encrypted receipt and warranty storage without accounts or cloud synchronization
- Camera capture, local text recognition, image/PDF imports and searchable purchase records
- Two-column product library with user-selected encrypted product photographs (icon fallback)\n- In-app document viewer with pinch zoom for images and native PDF rendering from decrypted memory
- Opt-in device-local warranty reminders 30, 7 and 1 days ahead of user-entered expiry dates
- Portable passphrase-encrypted .sqvault backup and restore (AES-256-GCM, PBKDF2-HMAC-SHA256, 210k iterations)
- Protected restore into an empty vault only, to prevent accidental overwrites
- Expanded automated tests for backups, tamper rejection, incorrect passphrase and empty-state UI
- Android CI APK and AAB artifacts with SHA-256 checksums; iOS unsigned compile check

## Distribution
The Android APK and AAB are **test builds** signed by CI with the default ephemeral Android signing configuration. They are not Google Play upload-signed and must not be published as production packages. Final app store distribution requires a stable signing key supplied through protected CI secrets.

iOS compilation is verified but no installable IPA is distributed without Apple Developer signing credentials.

## Known limitations
- Design follows SELQUARO reference compositions, but exact pixel-level 1:1 parity on real hardware has not been verified. No synthetic screenshots are passed off as device captures.
- Reminders are optional; the operating system may delay inexact notifications, and iOS/Android notification permission must be granted.
- OCR output is a suggestion and should be reviewed.
- App installation, navigation and scanning still require physical-device smoke testing.
- Backups require a separate passphrase; losing it makes the portable file unrecoverable.
- No user accounts, cloud service, advertising SDK, remote analytics or demo purchases.
