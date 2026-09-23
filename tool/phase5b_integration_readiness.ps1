param(
  [switch]$SkipSupabase
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$message) {
  Write-Host ""
  Write-Host "==> $message"
}

function Fail([string]$message) {
  Write-Host ""
  Write-Error $message
  exit 1
}

if (-not (Test-Path ".\pubspec.yaml")) {
  Fail "Run this script from the CarmeLink repository root."
}

Write-Step "Checking branch"
$branch = (git branch --show-current).Trim()
if ($LASTEXITCODE -ne 0) {
  Fail "Unable to read the current Git branch."
}
if ($branch -ne "japel") {
  Fail "Expected branch 'japel' but current branch is '$branch'."
}
Write-Host "Branch: $branch"

Write-Step "Checking for unresolved merge markers"
$sourceRoots = @(
  ".\lib",
  ".\test",
  ".\supabase\migrations"
)

$markerFiles = @()
foreach ($sourceRoot in $sourceRoots) {
  if (-not (Test-Path $sourceRoot)) { continue }

  $matches = Get-ChildItem $sourceRoot -Recurse -File |
    Where-Object {
      $_.Extension -in @(".dart", ".sql", ".ts", ".md")
    } |
    Select-String -Pattern '^(<<<<<<<|=======|>>>>>>>)' -ErrorAction SilentlyContinue

  if ($matches) {
    $markerFiles += $matches
  }
}

if ($markerFiles.Count -gt 0) {
  $markerFiles | ForEach-Object {
    Write-Host "$($_.Path):$($_.LineNumber): $($_.Line)"
  }
  Fail "Unresolved merge markers were found."
}
Write-Host "No unresolved merge markers found."

Write-Step "Checking owned production pages for MockData"
$ownedFiles = @()

foreach ($dir in @(".\lib\views\tenant", ".\lib\views\guardian")) {
  if (Test-Path $dir) {
    $ownedFiles += Get-ChildItem $dir -Recurse -File -Filter *.dart
  }
}

$sharedOwned = @(
  ".\lib\views\shared\room_cleaning_pages.dart",
  ".\lib\views\shared\room_inspection_pages.dart",
  ".\lib\views\shared\conduct_case_pages.dart",
  ".\lib\views\shared\conduct_case_appeal_panel.dart",
  ".\lib\views\shared\employee_curfew_profile_pages.dart",
  ".\lib\views\shared\retention_settings_page.dart"
)

foreach ($path in $sharedOwned) {
  if (Test-Path $path) {
    $ownedFiles += Get-Item $path
  }
}

$mockHits = @()
foreach ($file in $ownedFiles) {
  $hits = Select-String -Path $file.FullName -Pattern '\bMockData\b|mock_data\.dart'
  if ($hits) {
    $mockHits += $hits
  }
}

if ($mockHits.Count -gt 0) {
  $mockHits | ForEach-Object {
    Write-Host "$($_.Path):$($_.LineNumber): $($_.Line.Trim())"
  }
  Fail "Owned production pages still depend on MockData."
}
Write-Host "No MockData dependency found in owned production pages."

Write-Step "Checking phase migration files"
$requiredMigrations = @(
  ".\supabase\migrations\20260924050000_phase3a_room_cleaning.sql",
  ".\supabase\migrations\20260924060000_phase3b_room_inspections.sql",
  ".\supabase\migrations\20260924070000_phase4a_conduct_cases.sql",
  ".\supabase\migrations\20260924080000_phase4b_employee_curfew_profiles.sql",
  ".\supabase\migrations\20260924090000_phase4c_conduct_case_appeals.sql",
  ".\supabase\migrations\20260924100000_phase5a_retention_settings.sql"
)

$missing = $requiredMigrations | Where-Object { -not (Test-Path $_) }
if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Host "Missing: $_" }
  Fail "One or more Phase 3-5 migration files are missing."
}
Write-Host "All expected Phase 3-5 migrations are present."

Write-Step "Checking cross-module safety boundaries"

function Assert-NoSqlMutation(
  [string]$Path,
  [string[]]$Patterns,
  [string]$Label
) {
  $content = (Get-Content $Path -Raw).ToLowerInvariant()
  foreach ($pattern in $Patterns) {
    if ($content.Contains($pattern.ToLowerInvariant())) {
      Fail "$Label contains forbidden mutation pattern: $pattern"
    }
  }
}

Assert-NoSqlMutation `
  ".\supabase\migrations\20260924070000_phase4a_conduct_cases.sql" `
  @(
    "insert into public.payments",
    "update public.payments",
    "insert into public.billing",
    "update public.billing",
    "update public.contract",
    "delete from public.tenant_assignments"
  ) `
  "Phase 4A conduct migration"

Assert-NoSqlMutation `
  ".\supabase\migrations\20260924080000_phase4b_employee_curfew_profiles.sql" `
  @(
    "insert into public.gate_events",
    "update public.gate_events",
    "insert into public.curfew_requests",
    "update public.curfew_requests"
  ) `
  "Phase 4B employee-curfew migration"

Assert-NoSqlMutation `
  ".\supabase\migrations\20260924090000_phase4c_conduct_case_appeals.sql" `
  @(
    "update public.conduct_cases",
    "insert into public.payments",
    "update public.payments",
    "update public.contract",
    "tenant_assignments"
  ) `
  "Phase 4C appeal migration"

$retention = (
  Get-Content ".\supabase\migrations\20260924100000_phase5a_retention_settings.sql" -Raw
).ToLowerInvariant()

if (-not $retention.Contains("check (enforcement_enabled = false)")) {
  Fail "Phase 5A must keep retention enforcement hard-disabled."
}

foreach ($forbidden in @(
  "delete from ",
  "storage.objects",
  "cron.",
  "pg_cron"
)) {
  if ($retention.Contains($forbidden)) {
    Fail "Phase 5A contains forbidden destructive/scheduled retention behavior: $forbidden"
  }
}

Write-Host "Cross-module safety boundaries passed."

Write-Step "Running Flutter analyzer"
flutter analyze
if ($LASTEXITCODE -ne 0) {
  Fail "flutter analyze failed."
}

Write-Step "Running Phase 1-5 lightweight contract tests"
$targetedTests = @(
  ".\test\core\visitor_policy_test.dart",
  ".\test\core\cleaning_schedule_policy_test.dart",
  ".\test\core\room_inspection_policy_test.dart",
  ".\test\core\conduct_case_policy_test.dart",
  ".\test\core\employee_curfew_policy_test.dart",
  ".\test\core\conduct_case_appeal_policy_test.dart",
  ".\test\core\retention_policy_test.dart",
  ".\test\phase5b_integration_contract_test.dart"
) | Where-Object { Test-Path $_ }

if ($targetedTests.Count -eq 0) {
  Fail "No targeted Phase 1-5 tests were found."
}

flutter test $targetedTests
if ($LASTEXITCODE -ne 0) {
  Fail "One or more targeted Phase 1-5 tests failed."
}

Write-Step "Checking whitespace errors"
git diff --check
if ($LASTEXITCODE -ne 0) {
  Fail "git diff --check failed."
}

if (-not $SkipSupabase) {
  Write-Step "Checking Supabase migration synchronization"
  $migrationList = (& cmd.exe /d /s /c "npx supabase migration list 2>&1" | Out-String)
  $migrationExitCode = $LASTEXITCODE
  Write-Host $migrationList
  if ($migrationExitCode -ne 0) {
    Fail "Supabase migration list failed."
  }

  foreach ($version in @(
    "20260924050000",
    "20260924060000",
    "20260924070000",
    "20260924080000",
    "20260924090000",
    "20260924100000"
  )) {
    $matchingLine = ($migrationList -split "`r?`n") |
      Where-Object { $_ -match $version } |
      Select-Object -First 1

    if (-not $matchingLine) {
      Fail "Migration version $version was not found in Supabase migration list."
    }

    $count = ([regex]::Matches($matchingLine, [regex]::Escape($version))).Count
    if ($count -lt 2) {
      Fail "Migration $version is not synchronized between Local and Remote."
    }
  }

  Write-Step "Running Supabase dry-run"
  $dryRun = (& cmd.exe /d /s /c "npx supabase db push --dry-run 2>&1" | Out-String)
  $dryRunExitCode = $LASTEXITCODE
  Write-Host $dryRun
  if ($dryRunExitCode -ne 0) {
    Fail "Supabase database dry-run failed."
  }

  if ($dryRun -match "Would push these migrations:") {
    Fail "Supabase still has pending migrations. Synchronize them before closing Phase 5B."
  }
}

Write-Host ""
Write-Host "============================================================"
Write-Host "PHASE 5B INTEGRATION READINESS: PASS"
Write-Host "============================================================"
Write-Host ""
Write-Host "This does NOT replace the deferred final manual/end-to-end QA."
Write-Host "Proceed to the consolidated Phase 1-5 test matrix next."
