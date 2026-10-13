# SELQUARO 0.4.0 — vault reliability and safer document imports

## Improvements
- Validate PDF, JPEG, PNG and WebP binary headers, filename and MIME type before accepting imported files. Reject renamed unsupported files instead of relying on extensions alone.
- Validate document signatures again during encrypted imports and portable-backup restore.
- Recover a fully authenticated pending metadata save if the first vault write was interrupted, without resetting existing encrypted information.
- Remove partially written encrypted attachment files after failed import or restore.
- Ensure a failed *post-commit* deletion of obsolete encrypted attachments cannot mistakenly undo or mark successful purchase saves/deletions as failed.
- Reject overlapping vault mutations to prevent concurrent writes from silently overwriting records.
- Lock the app when backgrounded or inactive if device authentication is enabled, including screens opened through Navigator.
- Clean up SELQUARO temporary plaintext share files left behind by older releases.
- Handle inaccessible secure device settings without exposing purchases.
- Add regression tests for transaction ordering, failed cleanup, simultaneous updates, valid document headers and spoofed extensions.

## Signing, testing and release
GitHub Actions runs Dart analysis, unit tests, Android privacy checks, Android APK and AAB builds, and an unsigned iOS compilation check before tagging this prerelease.

**The APK and AAB are test-signed**. Neither is a production Google Play upload artifact until a persistent upload signing key is configured. iOS requires Apple signing before distribution.

## Data compatibility
- Vault schema remains version 1, with the same per-document AES-256-GCM encryption format.
- Portable backups remain SQBK2. Existing valid encrypted purchases and attachments are not migrated or reset.
- No accounts, no backend, no advertisements, and no seeded/demo purchases.

## Remaining QA
Pixel-for-pixel parity with design reference images, device-level end-to-end smoke testing and store signing cannot be inferred from CI and are not claimed completed. Keep independent copies of original receipts and your encrypted backup passphrase.
