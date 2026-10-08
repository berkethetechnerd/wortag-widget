#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -d build/Wortag.app ]; then bash Scripts/build.sh; fi
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$PWD/build/Wortag.app"
open "$PWD/build/Wortag.app"
