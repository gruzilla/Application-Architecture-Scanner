#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"

cd "$project_root"
/usr/bin/xcrun swift-format lint --strict --recursive --parallel Sources Tests
