# SELQUARO privacy and security (0.4.0)

SELQUARO does not require user accounts or a cloud server. No advertising, telemetry, or analytics integrations are built in.

## Local vault
- AES-256-GCM authenticated encryption per metadata save and document, using fresh nonces.
- Random 256-bit vault key backed by device Keystore/Keychain secure storage.
- A missing OS key **never causes silent generation of another key** over existing ciphertext. If the first metadata commit was interrupted, a complete authenticated pending write can be recovered without treating the vault as empty. When encrypted files are present, vault access fails closed to protect recovery options.
- Imported PDF, JPEG, PNG and WebP files are checked against their binary signatures as well as their declared name/type; this is not antivirus scanning or full format sanitization.\n- Imported files are stored in an app-private encrypted directory. Partial encrypted attachment writes are cleaned up after failure. Original external documents are not modified.
- Backup of app-private vault storage by Android is disabled; iOS excludes the vault directory from OS backup.

## Screens and user interaction
- On Android, FLAG_SECURE is enabled to block system screenshots and recent-task captures of sensitive contents.
- The optional device-authentication lock overlays every route, not merely the dashboard, when backgrounded.
- Sharing a document is explicit, creates a temporary plaintext copy for the platform share sheet and removes that copy after the share operation returns. Startup cleanup removes files matching the earlier SELQUARO share-cache naming scheme. A recipient application can still retain what the user shares.
- Previewing a document decrypts it into runtime memory. Malware, rooted/jailbroken OS instances, memory acquisition, and hostile keyboards are beyond the app threat model.

## Portable archives
- Portable SQBK2 backups encrypt metadata and attachments with AES-256-GCM, using PBKDF2-HMAC-SHA256 with 210,000 iterations and a random 128-bit salt.
- Preflight validation requires unique well-formed IDs, matching attachment references and types, valid purchases, complete cover-photo references, and size limits.
- Restore is only permitted into an empty vault; authentication and archive-format validation occur before any writes. Attachment headers are also checked during each restored-file import.\n- Once a purchase metadata update succeeds, best-effort orphan cleanup errors cannot cause newly attached files to be deleted by the editor as if the save had failed. Concurrent mutations fail rather than racing.
- Forgotten passphrases cannot be recovered. Archives can only be shared through explicit user action.

## Reminders
- Warranty reminders are off by default, use opt-in device notification permissions, and contain generic lock-screen-safe text.
- Inexact scheduling may be deferred by system energy policy; delivery is not guaranteed.

## Distribution and review
- Android GitHub prerelease binaries are **test-signed**, not production-signed.
- iOS CI is unsigned compile validation only. Actual device/simulator smoke tests, security review, signing, and pixel-level UI validation have not been certified.
