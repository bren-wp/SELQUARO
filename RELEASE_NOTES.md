# SELQUARO 0.3.0 — Data integrity and privacy hardening

## Changes
- **Missing-key protection:** never generate a replacement encryption key while an older encrypted vault or encrypted attachment is still on disk; preserve data for recovery and show an unlock error.
- **Backup preflight checks:** validate purchase identifiers, duplicate records, filenames, MIME types, document references, product cover images, amounts, dates, and attachment limits before accepting an archive.
- **Safe backup export:** reject malformed vault contents instead of writing an internally inconsistent portable backup.
- **Locked route protection:** the authentication curtain now covers all Flutter Navigator routes, including an open PDF/document page or editor after the app is backgrounded.
- **Android content privacy:** set FLAG_SECURE on the host Activity to block OS screenshots, screen recording captures, and readable recent-app snapshots; disable cleartext transport in the release app manifest.
- New regression tests for backup integrity, orphaned/missing attachments, duplicate purchase IDs, stale cover references, and invalid metadata.
- Android APK + AAB release CI, SHA256 verification, and iOS unsigned compilation remain required.

## Distribution notes
The attached APK and AAB use GitHub CI's testing/debug signing identity and are **not Google Play upload-signed**. Do not upload them to production Google Play. The iOS app is compiled without signing, not distributed as an IPA.

This update retains the v0.2.0 encrypted vault format and the SQBK2 portable backup format. No user accounts, network backend, analytics, advertising, or sample purchase records were added.

## Known limits
- Device smoke tests, full visual comparison with the design references, accessibility audit, and production signing still require validation. CI compilation does not prove pixel-perfect 1:1 parity or crash-free runtime behavior.
- FLAG_SECURE prevents taking screenshots of SELQUARO on Android, including for support; the policy is intentionally privacy-focused.
- Users must keep backup passphrases and confirm restoration on an empty vault before deleting originals.
