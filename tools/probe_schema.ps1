# Read-only reconnaissance of a live Supabase project.
#
#   powershell -ExecutionPolicy Bypass -File tools\probe_schema.ps1
#
# Uses the ANON key only, never the service_role key. Every call is a GET or a
# POST that selects nothing destructive, and PostgREST still applies RLS, so this
# reports what exists without being able to read a row the app itself could not.
#
# How the answers are derived:
#   RPC     404 "Could not find the function" -> MISSING
#           401                                   -> present (auth required)
#           400 with a type/arg error             -> present (signature mismatch)
#           200                                   -> present and callable
#   table   404 -> missing or fully RLS-hidden (ambiguous, reported as such)
#           200 -> present
#           400 -> present, but a selected column does not exist
param(
    [string]$ProjectRef = "",
    [string]$SecretsFile = "secrets.env"
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

if (-not $ProjectRef) {
    $url = (Get-Content $SecretsFile | Select-String -Pattern '^\s*SUPABASE_URL\s*=').ToString() -replace '^\s*SUPABASE_URL\s*=\s*',''
    $ProjectRef = ([uri]$url).Host.Split('.')[0]
}
$anon = (Get-Content $SecretsFile | Select-String -Pattern '^\s*SUPABASE_ANON_KEY\s*=').ToString() -replace '^\s*SUPABASE_ANON_KEY\s*=\s*',''

$base = "https://$ProjectRef.supabase.co"
$headers = @('-H', "apikey: $anon", '-H', "Authorization: Bearer $anon")

function Invoke-Probe([string[]]$curlArgs) {
    $tmp = [System.IO.Path]::GetTempFileName()
    $code = & curl.exe -s --max-time 25 @curlArgs -o $tmp -w "%{http_code}" 2>$null
    $body = (Get-Content $tmp -Raw -ErrorAction SilentlyContinue)
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    return [pscustomobject]@{ Code = $code; Body = $body }
}

# ---------------------------------------------------------------- RPCs
$rpcs = @(
    'get_my_chats', 'get_messages', 'get_messages_after', 'mark_read', 'mark_delivered',
    'get_or_create_direct_conversation', 'create_group_conversation', 'set_reaction',
    'normalize_phone', 'restore_profile_by_phone', 'delete_user_account', 'register_device',
    'set_presence', 'get_ban_status', 'submit_ban_appeal', 'media_storage_usage',
    'purge_stale_media_uploads', 'validate_media_upload', 'expire_device_link_sessions',
    'device_link_qr_payload', 'post_status', 'view_status', 'status_view_count',
    'archive_old_messages', 'is_admin', 'admin_export_user_data',
    # added this round
    'delete_conversation_messages', 'set_disappearing_messages', 'purge_expired_messages'
)

Write-Host "Probing $($rpcs.Count) RPCs on $ProjectRef ...`n"
$missing = @(); $present = @(); $unknown = @()
foreach ($r in $rpcs) {
    $res = Invoke-Probe (@('-X', 'POST', "$base/rest/v1/rpc/$r", '-H', 'Content-Type: application/json', '-d', '{}') + $headers)
    if ($res.Body -match 'Could not find the function|does not exist|schema cache') {
        $missing += $r
        Write-Host ("  MISSING  {0}" -f $r)
    }
    elseif ($res.Code -in @('200', '201')) {
        $present += $r
        Write-Host ("  PRESENT  {0}  (HTTP {1})" -f $r, $res.Code)
    }
    elseif ($res.Code -eq '401' -or $res.Code -eq '400' -or $res.Code -eq '403') {
        $present += $r
        Write-Host ("  PRESENT  {0}  (HTTP {1}, needs args/auth)" -f $r, $res.Code)
    }
    else {
        $unknown += $r
        Write-Host ("  UNKNOWN  {0}  (HTTP {1}) {2}" -f $r, $res.Code, ($res.Body -replace '\s+', ' ').Substring(0, [Math]::Min(70, ($res.Body).Length)))
    }
}

# ---------------------------------------------------------------- tables
$tables = @(
    'profiles', 'devices', 'conversations', 'conversation_members', 'messages',
    'message_receipts', 'statuses', 'status_views', 'calls', 'message_archive',
    'groups', 'group_members', 'communities', 'community_members', 'contacts',
    'blocked_users', 'message_reactions', 'typing', 'notifications', 'admin_users',
    'user_privacy_settings', 'device_sync_cursors', 'client_outbox', 'notification_queue',
    'user_settings', 'media_uploads', 'media_chunks', 'device_link_sessions'
)

Write-Host "`nProbing $($tables.Count) tables ...`n"
$missingTables = @(); $presentTables = @(); $ambiguous = @()
foreach ($t in $tables) {
    # `limit=0` asks for metadata only: it returns no rows, so this cannot leak
    # data even where RLS is misconfigured.
    $res = Invoke-Probe (@("$base/rest/v1/$t`?select=*&limit=0") + $headers)
    switch ($res.Code) {
        '200' { $presentTables += $t; Write-Host ("  PRESENT  {0}" -f $t) }
        '404' { $missingTables += $t; Write-Host ("  MISSING  {0}  {1}" -f $t, ($res.Body -replace '\s+',' ')) }
        '400' { $presentTables += $t; Write-Host ("  PRESENT  {0}  (column error: {1})" -f $t, ($res.Body -replace '\s+',' ').Substring(0,[Math]::Min(60,($res.Body).Length))) }
        default {
            $ambiguous += $t
            Write-Host ("  HIDDEN?  {0}  (HTTP {1}) - exists but RLS hides it from anon, or is absent" -f $t, $res.Code)
        }
    }
}

Write-Host "`n================ SUMMARY ================"
Write-Host ("RPCs     present {0} / missing {1}" -f $present.Count, $missing.Count)
Write-Host ("Tables   present {0} / missing {1} / rls-hidden-or-absent {2}" -f $presentTables.Count, $missingTables.Count, $ambiguous.Count)
if ($missing.Count)    { Write-Host ("  missing RPCs   : " + ($missing -join ', ')) }
if ($missingTables.Count) { Write-Host ("  missing tables : " + ($missingTables -join ', ')) }
if ($ambiguous.Count)  { Write-Host ("  ambiguous      : " + ($ambiguous -join ', ')) }
Write-Host ""
Write-Host "Note: a table reported HIDDEN may well exist. RLS legitimately blocks"
Write-Host "anon from most of these, so 404/401 is not proof of absence - it is"
Write-Host "why PREFLIGHT.sql exists and must be run with a privileged session."