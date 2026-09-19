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

function Invoke-ExpectedFailure([scriptblock]$Operation, [string]$Message) {
  try {
    & $Operation
    throw "Expected authorization failure: $Message"
  } catch {
    if ($_.Exception.Message -like 'Expected authorization failure:*') {
      throw
    }
  }
}

$tenant = Get-TestSession 'tenant@carmelita.test'
$guardian = Get-TestSession 'guardian@carmelita.test'
$owner = Get-TestSession 'owner@carmelita.test'
$caretaker = Get-TestSession 'caretaker@carmelita.test'

$arrival = (Get-Date).Date.AddDays(2).AddHours(14)
$departure = $arrival.AddHours(2)
$marker = "Automated visitor RLS test $([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
$createBody = @{
  tenant_id = $tenant.user.id
  visitor_name = 'Automated Test Visitor'
  relationship = 'Test contact'
  purpose = $marker
  contact_number = '09170000000'
  schedule = $arrival.ToUniversalTime().ToString('o')
  expected_departure_at = $departure.ToUniversalTime().ToString('o')
  status = 'pending'
} | ConvertTo-Json

$created = Invoke-RestMethod -Method Post -Uri "$restUrl/visitor_requests" `
  -Headers (Get-AuthHeaders $tenant 'return=representation') `
  -ContentType 'application/json' -Body $createBody
$requestId = $created[0].id
if (-not $requestId) { throw 'Tenant submission did not return a request ID' }

Invoke-ExpectedFailure {
  $body = @{
    p_request_id = $requestId
    p_action = 'approve'
    p_note = $null
  } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$restUrl/rpc/transition_visitor_request" `
    -Headers (Get-AuthHeaders $tenant) -ContentType 'application/json' -Body $body
} 'tenant must not approve visitor requests'

$guardianRows = Invoke-RestMethod -Method Get `
  -Uri "$restUrl/visitor_requests?id=eq.$requestId&select=id" `
  -Headers (Get-AuthHeaders $guardian)
if ($guardianRows.Count -ne 0) {
  throw 'Guardian could read a tenant visitor request without authorization'
}

$ownerRows = Invoke-RestMethod -Method Get `
  -Uri "$restUrl/visitor_requests?id=eq.$requestId&select=id,status" `
  -Headers (Get-AuthHeaders $owner)
if ($ownerRows.Count -ne 1) { throw 'Owner could not read the visitor request' }

foreach ($step in @(
  @{ session = $owner; action = 'approve'; expected = 'approved' },
  @{ session = $caretaker; action = 'record_arrival'; expected = 'arrived' },
  @{ session = $caretaker; action = 'record_departure'; expected = 'completed' }
)) {
  $body = @{
    p_request_id = $requestId
    p_action = $step.action
    p_note = if ($step.action -eq 'approve') { 'Remote E2E approval' } else { $null }
  } | ConvertTo-Json
  $result = Invoke-RestMethod -Method Post `
    -Uri "$restUrl/rpc/transition_visitor_request" `
    -Headers (Get-AuthHeaders $step.session) `
    -ContentType 'application/json' -Body $body
  if ($result.status -ne $step.expected) {
    throw "Expected $($step.expected), received $($result.status)"
  }
}

$tenantResult = Invoke-RestMethod -Method Get `
  -Uri "$restUrl/visitor_requests?id=eq.$requestId&select=id,status" `
  -Headers (Get-AuthHeaders $tenant)
if ($tenantResult[0].status -ne 'completed') {
  throw 'Tenant did not receive the completed visitor status'
}

$events = Invoke-RestMethod -Method Get `
  -Uri "$restUrl/visitor_events?request_id=eq.$requestId&select=event_type" `
  -Headers (Get-AuthHeaders $owner)
if ($events.Count -lt 3) { throw 'Visitor audit events are incomplete' }

[pscustomobject]@{
  request_id = $requestId
  final_status = $tenantResult[0].status
  audit_event_count = $events.Count
  tenant_cannot_approve = $true
  guardian_isolated = $true
}
