# SELQUARO 0.5.0 — Responsive vault and correct warranty dates

## What's new
- Refactored the purchase vault from a fully shrink-wrapped grid to lazily rendered slivers, improving scroll responsiveness on collections with hundreds or thousands of items.
- Adaptive presentation: readable purchase rows on narrow Android screens; two-column cards on regular phones and three columns on larger screens.
- Search by purchase name, merchant, category, notes or serial number. Clear-search action and reset filters when no results match.
- Category and warranty-status filters (active, expiring within 90 days, expired, unknown), plus deterministic newest/oldest, alphabetic and nearest-expiry sorting.
- Correct warranty countdown at daylight-saving time transitions by comparing calendar dates in UTC rather than elapsed local hours.
- Schedule reminders relative to true civil dates and then schedule at 9:00 local time, avoiding shifts across DST boundaries.
- Prevent concurrent vault edits, deletions or restores while creating a portable encrypted backup: metadata and document bytes are captured as a single consistent snapshot.
- Preserve existing encrypted data format and backup format; no demo purchases or accounts added.

## Quality
- Pure logic regression tests for search, sorting, category/warranty filters, and empty sets.
- Calendar-date tests for spring and autumn DST boundaries.
- A controlled delayed-read test ensures an encrypted backup blocks edits until its contents are copied.
- CI requires Flutter analysis, tests, Android privacy checks, APK and AAB builds, and unsigned iOS compilation.

## Distribution limitations
Attached Android APK/AAB packages are **testing builds** using GitHub's temporary signing configuration. They are not Google Play production upload-signed; use a stable upload key before store release. No signed iOS IPA is provided.

The UI uses the established SELQUARO visual palette. Pixel-level design parity and physical-device smoke testing have not been certified. Keep external copies of your original receipts and your backup passphrase.
