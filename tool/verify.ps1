# Local equivalent of the CI "dart" + "android" jobs, for this Windows machine.
# Usage (from the project root):  powershell -ExecutionPolicy Bypass -File tool\verify.ps1
# Add -SkipAndroid to skip the (slow) APK build.
param([switch]$SkipAndroid)
$ErrorActionPreference = 'Stop'

$flutter = 'C:\Users\Ahmad\flutter\bin\flutter.bat'
$dart = 'C:\Users\Ahmad\flutter\bin\dart.bat'
if (-not $env:JAVA_HOME) { $env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr' }

function Step($name, [scriptblock]$block) {
  Write-Host "`n== $name" -ForegroundColor Cyan
  & $block
  if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: $name" -ForegroundColor Red; exit $LASTEXITCODE }
}

Step 'pub get' { & $flutter pub get }
# *.g.dart keeps Pigeon's own formatting, so it's excluded from the format check.
$handWritten = Get-ChildItem -Recurse -Include *.dart -Path lib, test, pigeons | Where-Object { $_.Name -notlike '*.g.dart' } | ForEach-Object { $_.FullName }
Step 'format check' { & $dart format --output=none --set-exit-if-changed @handWritten }
Step 'regenerate Pigeon channel' { & $dart run pigeon --input pigeons/telemetry_api.dart }
Step 'regenerate l10n' { & $flutter gen-l10n }
Step 'regenerate drift database code' { & $dart run build_runner build }
Step 'analyze' { & $flutter analyze }
Step 'unit + widget + contract tests' { & $flutter test }
if (-not $SkipAndroid) { Step 'Android debug build (compiles Kotlin)' { & $flutter build apk --debug } }

Write-Host "`nAll checks passed. Swift is only compiled by CI (macos job) or on a Mac." -ForegroundColor Green
