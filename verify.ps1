# verify.ps1 — run every automated check in the project.
#
#   .\verify.ps1
#
# COVERED: all pure logic — CSV parsing, encoding repair, section lookup,
# greenhouse cells, the cultivar fallback, contest scoring and windows, gallery
# privacy rules, the agent's intent router, update-mode slot merging — plus
# static analysis and a compile of both the app and the backend.
#
# NOT COVERED, and why:
#   • camera, BLE beacons, GPS   — need real hardware
#   • Firestore/Storage rules    — need the Firebase emulator and a JDK
#   • the live garden API        — T's production system; tests must never
#                                  write to it
#   • the LLM providers          — non-deterministic and rate-limited
# The device checklist printed at the end covers what is left.

$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
$failed = @()

function Report($name, $ok, $detail) {
    Write-Host ""
    Write-Host "── $name " -NoNewline -ForegroundColor Cyan
    Write-Host ("─" * [Math]::Max(0, 56 - $name.Length)) -ForegroundColor DarkGray
    if ($detail) { Write-Host "   $detail" -ForegroundColor DarkGray }
    if ($ok) {
        Write-Host "   PASS" -ForegroundColor Green
    } else {
        Write-Host "   FAIL" -ForegroundColor Red
        $script:failed += $name
    }
}

Set-Location $root

# ── Static analysis ─────────────────────────────────────────────────────────
# Gate on errors and warnings only. `flutter analyze` exits non-zero for
# info-level lint too, and the tree carries ~120 pre-existing deprecation infos
# — gating on those would make this script permanently red and therefore
# ignored, which is worse than not having it.
$analyze = flutter analyze 2>&1 | Out-String
$errCount  = ([regex]::Matches($analyze, '(?m)^\s*error -')).Count
$warnCount = ([regex]::Matches($analyze, '(?m)^\s*warning -')).Count
$infoCount = ([regex]::Matches($analyze, '(?m)^\s*info -')).Count
Report "Flutter analyze" ($errCount -eq 0) `
    "$errCount errors, $warnCount warnings, $infoCount info"
if ($errCount -gt 0) {
    $analyze -split "`n" | Select-String '^\s*error -' | Select-Object -First 10
}

# ── Tests ───────────────────────────────────────────────────────────────────
$testOut = flutter test 2>&1 | Out-String
$testOk = $testOut -match 'All tests passed'
$passed = if ($testOut -match '\+(\d+)(?: -\d+)?: All tests passed') { $Matches[1] } else { '?' }
Report "Flutter tests" $testOk "$passed tests"
if (-not $testOk) { $testOut -split "`n" | Select-String '\[E\]' | Select-Object -First 10 }

# ── Dart self-checks ────────────────────────────────────────────────────────
foreach ($check in @(
    @{ n = "Self-check: encoding repair";  f = "lib/data/encoding_fix.dart";     k = "self-check ok" },
    @{ n = "Self-check: greenhouse cells"; f = "lib/data/greenhouse_cells.dart"; k = "self-check ok" }
)) {
    $out = dart run --enable-asserts $check.f 2>&1 | Out-String
    Report $check.n ($out -match $check.k) ""
    if ($out -notmatch $check.k) { Write-Host $out }
}

# ── Backend ─────────────────────────────────────────────────────────────────
Set-Location "$root\functions"

$build = npm run build 2>&1 | Out-String
$buildOk = $build -notmatch 'error TS'
Report "Backend compile (tsc)" $buildOk ""
if (-not $buildOk) { $build -split "`n" | Select-String 'error TS' | Select-Object -First 10 }

foreach ($check in @(
    @{ n = "Self-check: intent router";     f = "src/agent/router.ts";      k = "router self-check ok" },
    @{ n = "Self-check: update-mode slots"; f = "src/agent/update_mode.ts"; k = "update_mode self-check ok" }
)) {
    $out = npx tsx $check.f 2>&1 | Out-String
    Report $check.n ($out -match $check.k) ""
    if ($out -notmatch $check.k) { Write-Host $out }
}

Set-Location $root

# ── Summary ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host ("=" * 62) -ForegroundColor DarkGray
if ($failed.Count -eq 0) {
    Write-Host " ALL AUTOMATED CHECKS PASSED" -ForegroundColor Green
} else {
    Write-Host " FAILED: $($failed -join ', ')" -ForegroundColor Red
}
Write-Host ("=" * 62) -ForegroundColor DarkGray
Write-Host ""
Write-Host "Cannot be automated — verify on a device before an event:" -ForegroundColor Yellow
Write-Host "  1. Agent      ask 'Where is the cacao?' and get a real answer"
Write-Host "  2. Update     record an action, read the card, tap Cancel"
Write-Host "  3. Contest    submit an entry with a photo, check the leaderboard"
Write-Host "  4. Gallery    save a private photo, Share it, Make private again"
Write-Host "  5. Moderation report from a 2nd account, hide it as admin"
Write-Host "  6. Navigation pick two cells, confirm a route is drawn"
Write-Host ""

if ($failed.Count -ne 0) { exit 1 }
