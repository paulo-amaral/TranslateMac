#!/bin/sh
# Builds .build/TranslateMac.app. SwiftPM only makes a bare executable, and the
# Services menu entry and the microphone permission need a bundle with an Info.plist.
# VERSION (for example v1.2.0) sets the bundle version; without it the plist value stays.
set -eu
cd "$(dirname "$0")/.."

version=${VERSION:-}
version=${version#v}
case "$version" in
    *[!0-9.]* | .* | *. | *..*) echo "VERSION must look like 1.2.3" >&2; exit 1 ;;
esac

swift build -c release

app=.build/TranslateMac.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp .build/release/TranslateMac "$app/Contents/MacOS/TranslateMac"
cp App/Info.plist "$app/Contents/Info.plist"
if [ -n "$version" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
fi

# Ad-hoc signature with the hardened runtime; the entitlement keeps the microphone available under it.
codesign --force --options runtime --entitlements App/TranslateMac.entitlements --sign - "$app"

if [ -z "${CI:-}" ]; then
    # Make the Services menu read the new bundle.
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app"
    /System/Library/CoreServices/pbs -update
fi

echo "Built $app"
