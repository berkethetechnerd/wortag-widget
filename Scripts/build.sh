#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodegen >/dev/null; then
    echo 'XcodeGen is required to regenerate the project: brew install xcodegen' >&2
    exit 1
fi
# Stop only Wortag processes from this project's local installations.
stop_wortag() {
    pkill -TERM -f "^$PWD/build/(DerivedData/Build/Products/Release/)?Wortag.app/Contents/MacOS/Wortag$" || true
    pkill -TERM -f "^$PWD/build/(DerivedData/Build/Products/Release/)?Wortag.app/Contents/PlugIns/WortagWidget.appex/Contents/MacOS/WortagWidget( |$)" || true
}
stop_wortag
xcodegen generate
xcodebuild -project Wortag.xcodeproj -scheme Wortag -configuration Release \
    -derivedDataPath build/DerivedData -destination 'platform=macOS' \
    CODE_SIGNING_ALLOWED=YES build
mkdir -p build
# Local-only signing needs no Apple Developer subscription or provisioning profile.
# Xcode signs the extension and app before registering either with macOS.
# No App Group provisioning profile is needed for this local folder entitlement.
product=build/DerivedData/Build/Products/Release/Wortag.app
codesign --verify --deep --strict "$product"
stop_wortag
ditto "$product" build/Wortag.app
codesign --verify --deep --strict build/Wortag.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$PWD/$product"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$PWD/build/Wortag.app"
# WidgetKit may relaunch the previous copy during Xcode's registration. Retire
# it after installation so the next timeline uses the newly installed version.
stop_wortag
echo "Built: $PWD/build/Wortag.app"
