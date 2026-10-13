#!/usr/bin/env python3
"""Fail CI when generated Android privacy controls are missing."""
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml").read_text()
activity = Path("android/app/src/main/kotlin/com/selquaro/selquaro/MainActivity.kt").read_text()

checks = {
    "Local Android backups disabled": 'android:allowBackup="false"' in manifest,
    "Cleartext Android networking disabled": 'android:usesCleartextTraffic="false"' in manifest,
    "Camera permission declared": 'android.permission.CAMERA' in manifest,
    "Notification restart receiver declared": "ScheduledNotificationBootReceiver" in manifest,
    "Screenshots and task snapshots guarded": "WindowManager.LayoutParams.FLAG_SECURE" in activity,
    "Biometric-compatible host activity": "FlutterFragmentActivity" in activity,
}
for label, passed in checks.items():
    print(("PASS" if passed else "FAIL") + " — " + label)
if not all(checks.values()):
    raise SystemExit("Missing SELQUARO Android privacy configuration")
