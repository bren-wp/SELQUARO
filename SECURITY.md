# Security and privacy

SELQUARO is designed for offline use. It does not implement accounts, API endpoints, telemetry, advertising SDKs, or cloud synchronization.

## Encryption
- A fresh random 256-bit key is generated on first vault access and stored using flutter_secure_storage (Android Keystore / iOS Keychain backing).
- Each vault write and imported file is encrypted independently using AES-256-GCM and a fresh random 96-bit nonce.
- Authenticated decryption rejects modified content rather than silently repairing or resetting it.
- Raw contents are transiently in application memory during import/preview. OS-level snapshots, malware, rooted/jailbroken devices and compromised system processes are outside the app threat model.

## Data handling
- Document selection permits only PDF/JPEG/PNG/WebP; file size is capped at 20 MB.
- Imported documents use random filenames inside app-private storage. The app never uploads them.
- OCR, where enabled, runs on-device. OCR results are suggestions requiring review.
- No unsupported claim of '100% protected' or guaranteed legal warranty duration.
- No remote backup and no recoverable account. Reinstallation or loss of device key can irreversibly lose the vault.
- Biometric gating provides convenience but is not a substitute for OS device lock or storage encryption.
- Android OS cloud backup should be disabled in the generated AndroidManifest. iOS backups require review of platform-specific backup exclusion policies before production.

## Release checks
`flutter analyze`, `flutter test`, Android release build and iOS no-codesign build must complete before automated tagging/release. Production App Store signing is not bundled or fabricated.
