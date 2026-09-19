param(
  [Parameter(Mandatory = $true)][string]$ProjectUrl,
  [Parameter(Mandatory = $true)][string]$PublishableKey,
  [Parameter(Mandatory = $true)][string]$TestPassword
)

$ErrorActionPreference = 'Stop'
$restUrl = "$ProjectUrl/rest/v1"

function Get-TestSession([string]$Email) {
  $headers = @{ apikey = $PublishableKey }
  $body = @{ email = $Email; password = $TestPassword } | ConvertTo-Json
  Invoke-RestMethod -Method Post `
    -Uri "$ProjectUrl/auth/v1/token?grant_type=password" `
    -Headers $headers -ContentType 'application/json' -Body $body
}

function Get-AuthHeaders($Session, [string]$Prefer = '') {
  $headers = @{
    apikey = $PublishableKey
    Authorization = "Bearer $($Session.access_token)"
  }
  if ($Prefer) { $headers.Prefer = $Prefer }
  $headers
}

function Assert-Empty([object]$Rows, [string]$Message) {
  if ($null -ne $Rows -and @($Rows).Count -ne 0) { throw $Message }
}

function Invoke-ExpectedFailure([scriptblock]$Operation, [string]$Message) {
  try {
    & $Operation
    throw "Expected failure: $Message"
  } catch {
    if ($_.Exception.Message -like 'Expected failure:*') { throw }
  }
}

$tenant = Get-TestSession 'tenant@carmelita.test'
$guardian = Get-TestSession 'guardian@carmelita.test'
$caretaker = Get-TestSession 'caretaker@carmelita.test'
$owner = Get-TestSession 'owner@carmelita.test'
$createdId = $null
$marker = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$contractNumber = "RLS-TEST-$marker"

try {
  $createBody = @{
    tenant_id = $tenant.user.id
    contract_number = $contractNumber
    starts_on = '2098-01-01'
    ends_on = '2098-12-31'
    monthly_rent = 4000
    security_deposit = 4000
    status = 'draft'
    notes = 'Automated contract CRUD/RLS smoke test'
  } | ConvertTo-Json

  $created = Invoke-RestMethod -Method Post -Uri "$restUrl/tenant_contracts" `
    -Headers (Get-AuthHeaders $owner 'return=representation') `
    -ContentType 'application/json' -Body $createBody
  $createdId = @($created)[0].id
  if (-not $createdId) { throw 'Owner create did not return a contract ID' }
  if (@($created)[0].created_by -ne $owner.user.id) {
    throw 'Contract created_by was not set to the authenticated owner'
  }

  foreach ($actor in @(
    @{ name = 'tenant'; session = $tenant },
    @{ name = 'guardian'; session = $guardian },
    @{ name = 'caretaker'; session = $caretaker }
  )) {
    $rows = Invoke-RestMethod -Method Get `
      -Uri "$restUrl/tenant_contracts?id=eq.$createdId&select=id" `
      -Headers (Get-AuthHeaders $actor.session)
    Assert-Empty $rows "$($actor.name) could read an owner-only contract"

    $updateRows = Invoke-RestMethod -Method Patch `
      -Uri "$restUrl/tenant_contracts?id=eq.$createdId" `
      -Headers (Get-AuthHeaders $actor.session 'return=representation') `
      -ContentType 'application/json' `
      -Body (@{ notes = "Unauthorized $($actor.name) update" } | ConvertTo-Json)
    Assert-Empty $updateRows "$($actor.name) could update an owner-only contract"

    $deleteRows = Invoke-RestMethod -Method Delete `
      -Uri "$restUrl/tenant_contracts?id=eq.$createdId" `
      -Headers (Get-AuthHeaders $actor.session 'return=representation')
    Assert-Empty $deleteRows "$($actor.name) could delete an owner-only contract"

    $unauthorizedBody = @{
      tenant_id = $tenant.user.id
      contract_number = "DENIED-$($actor.name)-$marker"
      starts_on = '2098-01-01'
      ends_on = '2098-12-31'
      monthly_rent = 1
      security_deposit = 0
      status = 'draft'
    } | ConvertTo-Json
    Invoke-ExpectedFailure {
      Invoke-RestMethod -Method Post -Uri "$restUrl/tenant_contracts" `
        -Headers (Get-AuthHeaders $actor.session) `
        -ContentType 'application/json' -Body $unauthorizedBody
    } "$($actor.name) must not create contracts"
  }

  $ownerCheck = Invoke-RestMethod -Method Get `
    -Uri "$restUrl/tenant_contracts?id=eq.$createdId&select=id,notes" `
    -Headers (Get-AuthHeaders $owner)
  if (@($ownerCheck).Count -ne 1 -or @($ownerCheck)[0].notes -ne 'Automated contract CRUD/RLS smoke test') {
    throw 'Contract changed during unauthorized update/delete checks'
  }

  $updated = Invoke-RestMethod -Method Patch `
    -Uri "$restUrl/tenant_contracts?id=eq.$createdId" `
    -Headers (Get-AuthHeaders $owner 'return=representation') `
    -ContentType 'application/json' `
    -Body (@{ monthly_rent = 4250; notes = 'Updated by remote smoke test' } | ConvertTo-Json)
  if (@($updated)[0].monthly_rent -ne 4250) {
    throw 'Owner update did not persist the new monthly rent'
  }

  Invoke-ExpectedFailure {
    Invoke-RestMethod -Method Patch `
      -Uri "$restUrl/tenant_contracts?id=eq.$createdId" `
      -Headers (Get-AuthHeaders $owner) -ContentType 'application/json' `
      -Body (@{ ends_on = '2097-12-31' } | ConvertTo-Json)
  } 'contract end date must not precede its start date'

  Invoke-ExpectedFailure {
    Invoke-RestMethod -Method Post -Uri "$restUrl/tenant_contracts" `
      -Headers (Get-AuthHeaders $owner) -ContentType 'application/json' `
      -Body (@{
        tenant_id = $owner.user.id
        contract_number = "INVALID-TENANT-$marker"
        starts_on = '2098-01-01'
        ends_on = '2098-12-31'
        monthly_rent = 1
        security_deposit = 0
        status = 'draft'
      } | ConvertTo-Json)
  } 'contracts must reference tenant accounts only'

  Invoke-RestMethod -Method Delete `
    -Uri "$restUrl/tenant_contracts?id=eq.$createdId" `
    -Headers (Get-AuthHeaders $owner) | Out-Null
  $createdId = $null

  $remaining = Invoke-RestMethod -Method Get `
    -Uri "$restUrl/tenant_contracts?contract_number=eq.$contractNumber&select=id" `
    -Headers (Get-AuthHeaders $owner)
  Assert-Empty $remaining 'Owner delete did not remove the test contract'

  [pscustomobject]@{
    owner_create_read_update_delete = $true
    tenant_isolated = $true
    guardian_isolated = $true
    caretaker_isolated = $true
    invalid_date_rejected = $true
    non_tenant_rejected = $true
    cleanup_complete = $true
  }
} finally {
  if ($createdId) {
    try {
      Invoke-RestMethod -Method Delete `
        -Uri "$restUrl/tenant_contracts?id=eq.$createdId" `
        -Headers (Get-AuthHeaders $owner) | Out-Null
    } catch {
      Write-Warning "Cleanup failed for contract $createdId`: $($_.Exception.Message)"
    }
  }
}
