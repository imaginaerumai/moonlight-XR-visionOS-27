#!/bin/bash
# Build the macOS target when the macOS SDK is present, and the visionOS
# simulator target when that SDK is present. Missing SDKs and missing
# signing material skip with a message. Compile errors fail the job.
set -uo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "SKIP: xcodebuild is not installed on this runner, so Moonlight XrOS and Moonlight macOS were not compiled."
  exit 0
fi

SDKS="$(xcodebuild -showsdks 2>/dev/null || true)"
echo "$SDKS"

sign_off=(
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_IDENTITY=
  DEVELOPMENT_TEAM=
)

build_one() {
  local scheme="$1"
  local sdk="$2"
  local destination="$3"
  local log
  log="$(mktemp)"
  echo "Building scheme '$scheme' with sdk '$sdk'"
  if xcodebuild -project Moonlight.xcodeproj -scheme "$scheme" -configuration Debug -sdk "$sdk" -destination "$destination" "${sign_off[@]}" build >"$log" 2>&1; then
    echo "Built $scheme ($sdk)"
    rm -f "$log"
    return 0
  fi
  if grep -E -q "requires a provisioning profile|No signing certificate|No profiles for|Signing for .* requires a development team" "$log"; then
    echo "SKIP: $scheme was not signed. This runner has no Apple signing secrets. The compile may also have stopped at signing."
    echo "----- tail of xcodebuild log -----"
    tail -n 40 "$log"
    rm -f "$log"
    return 0
  fi
  echo "BUILD FAILED: $scheme ($sdk)"
  tail -n 80 "$log"
  rm -f "$log"
  return 1
}

status=0

if echo "$SDKS" | grep -q "macosx"; then
  build_one "Moonlight macOS" macosx "generic/platform=macOS" || status=1
else
  echo "SKIP: no macOS SDK on this runner, so Moonlight macOS was not compiled."
fi

if echo "$SDKS" | grep -q "xrsimulator"; then
  build_one "Moonlight XrOS" xrsimulator "generic/platform=visionOS Simulator" || status=1
else
  echo "SKIP: this hosted runner has no visionOS Simulator SDK (xrsimulator)."
  echo "Moonlight XrOS was not compiled. Install Xcode with the visionOS 27 SDK and run:"
  echo "  xcodebuild -project Moonlight.xcodeproj -scheme \"Moonlight XrOS\" -configuration Debug -sdk xrsimulator -destination 'generic/platform=visionOS Simulator' CODE_SIGNING_ALLOWED=NO build"
fi

exit "$status"
