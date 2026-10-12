#!/usr/bin/env bash
set -euo pipefail
# Generate official Flutter Android/iOS host projects from the checked-in Dart app.
flutter create --platforms=android,ios --org com.selquaro --project-name selquaro .
rm -f test/widget_test.dart
python3 tool/secure_platforms.py
python3 tool/generate_icon.py
