#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"

cd "$project_root"
/usr/bin/xcrun swift-format format --in-place --recursive --parallel Sources Tests
