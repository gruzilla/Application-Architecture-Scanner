#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
# The XCTest suite uses temporary fixtures and never scans live applications.
"$project_root/Scripts/lint.sh"
/usr/bin/xcodebuild \
    -project "$project_root/Application Architecture Scanner.xcodeproj" \
    -scheme 'Application Architecture Scanner' \
    -destination "platform=macOS,arch=$(/usr/bin/uname -m)" \
    -derivedDataPath "$project_root/build/DerivedData" \
    test "$@"
