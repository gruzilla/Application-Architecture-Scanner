#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
/bin/bash "$project_root/Scripts/build.sh" "$@"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent \
    "$project_root/build/Application Architecture Scanner.app" \
    "$project_root/build/Application-Architecture-Scanner.zip"
printf 'USB app ZIP: %s\n' "$project_root/build/Application-Architecture-Scanner.zip"
