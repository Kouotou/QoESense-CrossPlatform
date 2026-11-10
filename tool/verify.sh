#!/usr/bin/env bash
# Local equivalent of CI, for macOS/Linux (e.g. the borrowed Mac). Run from the project root.
#   ./tool/verify.sh            # everything available on this OS
#   SKIP_BUILDS=1 ./tool/verify.sh
#   SKIP_ANDROID=1 ./tool/verify.sh   # an Android SDK is present but can't build (e.g. no android-37)
set -euo pipefail

step() { printf '\n== %s\n' "$1"; shift; "$@"; }

step "pub get" flutter pub get
# *.g.dart keeps Pigeon's own formatting, so it's excluded from the format check.
step "format check" bash -c "find lib test pigeons -name '*.dart' ! -name '*.g.dart' -print0 | xargs -0 dart format --output=none --set-exit-if-changed"
step "regenerate Pigeon channel" dart run pigeon --input pigeons/telemetry_api.dart
step "regenerate l10n" flutter gen-l10n
step "regenerate drift database code" dart run build_runner build
step "analyze" flutter analyze
step "tests" flutter test

if [[ -z "${SKIP_BUILDS:-}" ]]; then
  # The borrowed Mac has no Android SDK: skip the APK there (the Windows PC builds it).
  if [[ -n "${SKIP_ANDROID:-}" ]]; then
    echo "(SKIP_ANDROID set - skipping the APK build)"
  elif [[ -n "${ANDROID_HOME:-}" || -d "$HOME/Library/Android/sdk" || -d "$HOME/Android/Sdk" ]]; then
    step "Android debug build" flutter build apk --debug
  else
    echo "(no Android SDK found - skipping the APK build)"
  fi
  if [[ "$(uname)" == "Darwin" ]]; then
    step "iOS build, no codesign (compiles Swift)" flutter build ios --debug --no-codesign
    # XCTest (ios/RunnerTests) on the first available iPhone simulator.
    sim=$(xcrun simctl list devices available | grep -m1 -oE 'iPhone[^(]*\(([0-9A-F-]{36})\)' | grep -oE '[0-9A-F-]{36}' || true)
    if [[ -n "$sim" ]]; then
      step "iOS unit tests (XCTest, simulator)" bash -c "cd ios && xcodebuild test -quiet -workspace Runner.xcworkspace -scheme Runner -destination 'id=$sim'"
    else
      echo "(no iPhone simulator found - skipping XCTest)"
    fi
  fi
fi
echo "All checks passed."
