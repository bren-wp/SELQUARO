# SELQUARO 0.6.0 — Private UI and reliability refinement

## Changes
- Replace the duplicated lock-screen routes with one consistent **full-route privacy curtain**. Authentication no longer destroys unfinished receipt forms or a selected document view. The overlay blocks touches and hides the underlying content from accessibility services.
- Lock view is scrollable on small screens and remains usable with large accessibility fonts.
- Improve bottom-tab accessibility through explicitly labelled, selected-state semantics and single-line labels.
- Guard receipt/photo import and on-device OCR against rapid concurrent save/scan actions; prevent callbacks from updating screens after disposal.
- Prevent cleanup errors after sharing a document or rolling back imports from crashing the editor or hiding the initial error.
- Validate monetary values against the maximum accepted by portable backup rules (0–1 trillion) so a purchase cannot be saved successfully but fail all backups solely due to its value.
- Reject malformed encrypted document IDs before attempting filesystem reads/deletion.
- Serialize local notification schedule changes: a stale asynchronous cancel/reschedule operation can no longer race against newer edits.
- Add focused widget tests for locked UI state preservation and small-screen layout, plus tests that reject attachment path traversal.

## Compatibility
No vault format or SQBK2 archive change. Existing encrypted receipts/warranties are not rewritten, and there are no user accounts, demo records, cloud sync, telemetry or adverts.

## Quality and distribution
Android static analysis, Flutter tests, Android privacy assertions, APK/AAB builds and unsigned iOS compile are required before GitHub prerelease publication. Android packages in this release are **CI test-signed**, not Google Play production/upload signed. Physical-device runtime testing, 1:1 screenshot comparisons and permanent distribution signatures remain necessary before a production-ready designation.

Always keep your original receipts and a separately verified encrypted backup before replacing test-signed installations.
