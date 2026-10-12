# SELQUARO security and privacy (0.2.0)

## Data flow and trust boundaries
- SELQUARO has no account system, backend, ads, analytics, telemetry, remote synchronization or purchase/demo dataset.
- Locally imported documents are encrypted into app-private storage. The original selected files are not modified.
- On-device Google ML Kit OCR operates on receipt images; extracted text must be manually reviewed.
- Android app backups are disabled. iOS private vault directory is marked as excluded from device backup.

## At-rest encryption
- A random 256-bit vault key is stored in the system's protected key store (Android Keystore / iOS Keychain, via flutter_secure_storage).
- Each metadata update and imported file is sealed with AES-256-GCM, a fresh 96-bit nonce and an authentication tag.
- Authentication failure must never silently erase or regenerate existing vault records.
- Document preview decrypts into app memory; user-requested sharing writes a temporary plaintext copy for the OS share sheet and deletes it upon return. Recipient apps may retain shared files.
- The operating system, keyboards, screenshots, malware, rooted devices and access to unlocked runtime memory remain outside a mobile application's full control.

## Backups
- Portable SQBK2 archives contain encrypted records and attachments with AES-256-GCM.
- The backup key is derived from a user-provided 12+ character passphrase using PBKDF2-HMAC-SHA256 (210,000 iterations, random 128-bit salt), fresh random nonce and authentication.
- Backup export intentionally invokes the OS share sheet with ciphertext only. Restore validates file limits, document references, IDs and authentication and will not overwrite an existing non-empty vault.
- A forgotten passphrase cannot be recovered. Protect exported backups and test restore safely.

## Notifications and permissions
- Reminders are off by default and require permission.
- Notifications contain generic text, not product names, to reduce lock-screen data exposure.
- Schedules are inexact and are subject to the device's battery/notification policies; delivery is not guaranteed.
- No exact alarm permission and no online push notification provider are requested.

## Supply chain / distribution
- Android APK/AAB in GitHub prereleases use a testing configuration, not a permanent Play Store upload signature.
- No signing keys, Apple credentials, passphrases or production passwords belong in GitHub history.
- Device QA, penetration review and production signing remain required prior to publishing to stores.
