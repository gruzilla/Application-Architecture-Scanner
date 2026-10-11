#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
# Pass optional Xcode build settings as arguments, e.g. MACOSX_DEPLOYMENT_TARGET=12.0.
# The shipped product is Universal; Xcode compiles Swift rather than embedding JXA.
/usr/bin/xcodebuild \
    -project "$project_root/Application Architecture Scanner.xcodeproj" \
    -scheme 'Application Architecture Scanner' \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$project_root/build/DerivedData" \
    build "$@"
product="$project_root/build/DerivedData/Build/Products/Release/Application Architecture Scanner.app"
output="$project_root/build/Application Architecture Scanner.app"
# Replace only our generated app, preserving neighboring CSVs.
if [[ -e "$output" ]]; then
    [[ -d "$output/Contents" ]] || { printf 'Refusing to replace a non-app path: %s\n' "$output" >&2; exit 1; }
    rm -rf "$output"
fi
/usr/bin/ditto "$product" "$output"
/usr/bin/codesign --verify --deep --strict "$output"
printf '\nBuilt %s\n' "$output"
