# SELQUARO v0.7.0 — Data integrity, safer backups and file performance

## Changes
- Detect duplicate purchase IDs, duplicate document references, blank identifiers and missing purchase names before saving or loading encrypted local metadata. Invalid indexes fail closed rather than being silently replaced.
- When a details page deletes an item, resolve its current committed record first. This prevents old document references from deleting an unrelated or newly attached encrypted document after an edit. Repeated stale deletions are rejected.
- Validate local catalog data without imposing UUID syntax on legacy purchase identifiers, retaining compatibility with previously persisted metadata.
- Use a unique application-private scratch directory for each encrypted backup export; prevent older exports from being overwritten and cleanup afterward even if sharing fails.
- Remove abandoned temporary backup export directories and older SELQUARO scratch files at startup.
- Cache app-private directory resolution and iOS backup-exclusion configuration between receipt and thumbnail reads; reset the cached path after wiping the vault.
- Enforce the same 12–256 Unicode-character passphrase limits when exporting or restoring; reject empty backup files without attempting decryption.
- New regression tests for malformed indexes, cross-purchase document duplication, stale deletion safety, and corrupted-state write protection.

## Compatibility and privacy
The existing v1 vault format and SQBK2 portable backup format do not change. No accounts, cloud storage, advertising, analytics or demo purchases.

## Validation and release
GitHub Actions must pass Flutter analysis, tests, Android security assertions, Android APK and AAB builds, and unsigned iOS compilation before publishing. Android prerelease packages are **test-signed** and not production Google Play upload artifacts. An unsigned iOS compile does not constitute an installable IPA. Physical device QA and visual reference parity remain separate, unverified release requirements.

**Important:** Before replacing a test-signed installation, safely export and verify an encrypted backup and keep the passphrase. Deleting an existing installation may permanently erase app-private data.
