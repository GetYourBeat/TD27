#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ "$(uname -s)" != Darwin ]]; then
  echo "This build needs macOS and full Xcode. Linux cannot build SwiftUI/AppKit."
  exit 1
fi
xcodebuild -version
bash tools/test-core-macos.sh
xcodebuild -project PulsoKit.xcodeproj -scheme PulsoKit -configuration Debug \
  -destination "platform=macOS,arch=arm64" -derivedDataPath build/TestData \
  -only-testing:PulsoKitTests CODE_SIGNING_ALLOWED=NO test
xcodebuild -project PulsoKit.xcodeproj -scheme PulsoKit -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build/DerivedData \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
mkdir -p dist
/usr/bin/ditto build/DerivedData/Build/Products/Release/PulsoKit.app dist/PulsoKit-TD27.app
/usr/bin/codesign --force --deep --sign - dist/PulsoKit-TD27.app
/usr/bin/ditto -c -k --sequesterRsrc --keepParent dist/PulsoKit-TD27.app dist/PulsoKit-TD27-AppleSilicon.zip
echo "Built: $PWD/dist/PulsoKit-TD27.app"
