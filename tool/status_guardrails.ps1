$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  Write-Error $Message
  exit 1
}

if (-not (Test-Path '.\pubspec.yaml')) {
  Fail 'Run this script from the CarmeLink repository root.'
}

Write-Host 'Checking prohibited application-usage tracking...'
$usagePatterns = @(
  'PACKAGE_USAGE_STATS',
  'UsageStatsService',
  'AppUsageStat',
  'carmelitas/usage_stats',
  'UsageStatsManager',
  'ACTION_USAGE_ACCESS_SETTINGS'
)
$usageRoots = @('.\lib', '.\android', '.\ios')
foreach ($pattern in $usagePatterns) {
  $hits = Get-ChildItem $usageRoots -Recurse -File |
    Select-String -SimpleMatch $pattern -ErrorAction SilentlyContinue
  if ($hits) {
    $hits | ForEach-Object { Write-Host "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" }
    Fail "Prohibited application-usage tracking returned: $pattern"
  }
}
Write-Host 'PASS: no application-usage tracking code or permission found.'

Write-Host 'Checking boundary editor contract...'
$boundaryService = '.\lib\services\boundary_config_service.dart'
$boundaryMigration = '.\supabase\migrations\202609250002_boundary_config_editable.sql'
$clientCallsBoundaryRpc = (Get-Content $boundaryService -Raw).Contains(
  "'update_dorm_boundary_config'"
)
$migrationDefinesBoundaryRpc =
  (Test-Path $boundaryMigration) -and
  (Get-Item $boundaryMigration).Length -gt 0 -and
  (Get-Content $boundaryMigration -Raw).Contains('update_dorm_boundary_config')
if ($clientCallsBoundaryRpc -and -not $migrationDefinesBoundaryRpc) {
  Fail 'Boundary editor calls update_dorm_boundary_config, but its migration does not define the RPC.'
}
Write-Host 'PASS: boundary editor and migration contract agree.'

Write-Host 'Checking announcement notification dispatch...'
$announcement = Get-Content '.\lib\services\announcement_service.dart' -Raw
$hasNoOpHook =
  $announcement.Contains('_dispatchFCMNotificationIfConfigured') -and
  -not $announcement.Contains('notifyNewAnnouncement(') -and
  -not $announcement.Contains("functions.invoke(")
if ($hasNoOpHook) {
  Fail 'Announcement creation still has a no-op notification hook.'
}
Write-Host 'PASS: announcement notification hook has a concrete dispatch path.'

Write-Host 'Checking obsolete notification page...'
$commonWidgets = Get-Content '.\lib\core\widgets\common_widgets.dart' -Raw
if ($commonWidgets.Contains('class _GlobalNotificationsPage')) {
  Fail 'Obsolete _GlobalNotificationsPage still exists; route all notification entry points to NotificationsPage.'
}
Write-Host 'PASS: obsolete notification page is absent.'

Write-Host 'Checking retention safety boundary...'
$retention = Get-Content `
  '.\supabase\migrations\20260924100000_phase5a_retention_settings.sql' `
  -Raw
if (-not $retention.Contains('check (enforcement_enabled = false)')) {
  Fail 'Retention enforcement safety boundary changed; update STATUS.md and obtain explicit review.'
}
Write-Host 'PASS: automated retention enforcement remains disabled as documented.'

Write-Host 'All status guardrails passed.'
