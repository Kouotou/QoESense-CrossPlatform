#!/usr/bin/env bash
# Local equivalent of CI, for macOS/Linux (e.g. the borrowed Mac). Run from the project root.
#   ./tool/verify.sh            # everything available on this OS
#   SKIP_BUILDS=1 ./tool/verify.sh
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
  step "Android debug build" flutter build apk --debug
  if [[ "$(uname)" == "Darwin" ]]; then
    step "iOS build, no codesign (compiles Swift)" flutter build ios --debug --no-codesign
  fi
fi
echo "All checks passed."
