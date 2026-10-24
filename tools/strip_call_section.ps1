# Removes the 00006_call_webrtc.sql section from the assembled schema.
# Run once, from the repository root:
#   powershell -ExecutionPolicy Bypass -File tools\strip_call_section.ps1
$ErrorActionPreference = "Stop"
$p = Join-Path (Split-Path -Parent $PSScriptRoot) "supabase\migrations\00021_full_schema.sql"

$lines = Get-Content -LiteralPath $p
Write-Host "before: $($lines.Count) lines"

# Boundaries (1-based source lines):
#   1468  "-- ###..."   opening banner of the 00006 section  -> index 1467
#   1469  "-- 00006_call_webrtc.sql"                       -> index 1468
#   1574  last dropped line
#   1575  "-- ###..."   opening banner of 00007             -> index 1574
# Verify both before cutting anything.
if ($lines[1468] -notmatch "00006_call_webrtc") {
    throw "line 1469 is not the 00006_call_webrtc header: $($lines[1468])"
}
if ($lines[1575] -notmatch "00007_guest_auth") {
    throw "line 1576 is not the 00007_guest_auth header: $($lines[1575])"
}

$replacement = @(
    "-- ############################################################################",
    "-- 00006_call_webrtc.sql",
    "--",
    "-- Removed: calls are gone from the app. This section created the calls",
    "-- table's live-state columns, constraints, indexes and publication entry,",
    "-- and contained a malformed `create or replace function",
    "-- enable_realtime_calls()` with no body followed by",
    "-- `select public.enable_realtime_calls();`. Postgres rejects that, which",
    "-- aborts the transaction, so every object defined after this point -",
    "-- including the whole chunked-media schema - never applied to a database",
    "-- built from this file. The table itself is removed by",
    "-- `drop table if exists public.calls cascade` in the Calls section above.",
    "-- #############################################################################",
    ""
)

$out = @()
$out += $lines[0..1466]        # through line 1467 (blank before the banner)
$out += $replacement
$out += $lines[1574..($lines.Count - 1)]   # from line 1575 (00007 banner)

[System.IO.File]::WriteAllLines($p, $out)
Write-Host "after: $($out.Count) lines (removed $($lines.Count - $out.Count))"