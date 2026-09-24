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

function Invoke-ExpectedFailure(
  [scriptblock]$Operation,
  [string]$Message
) {
  try {
    & $Operation
    throw "Expected authorization/validation failure: $Message"
  } catch {
    if (
      $_.Exception.Message -like
        'Expected authorization/validation failure:*'
    ) {
      throw
    }
  }
}

function New-VisitorBody(
  $Tenant,
  [DateTime]$Arrival,
  [DateTime]$Departure,
  [string]$Purpose,
  [DateTime]$CreatedAt = [DateTime]::MinValue
) {
  $body = @{
    tenant_id = $Tenant.user.id
    visitor_name = 'Automated Test Visitor'
    relationship = 'Test contact'
    purpose = $Purpose
    contact_number = '09170000000'
    schedule = $Arrival.ToUniversalTime().ToString('o')
    expected_departure_at = $Departure.ToUniversalTime().ToString('o')
    status = 'pending'
  }

  if ($CreatedAt -ne [DateTime]::MinValue) {
    $body.created_at = $CreatedAt.ToUniversalTime().ToString('o')
  }

  $body | ConvertTo-Json
}

$tenant = Get-TestSession 'tenant@carmelita.test'
$guardian = Get-TestSession 'guardian@carmelita.test'
$owner = Get-TestSession 'owner@carmelita.test'
$caretaker = Get-TestSession 'caretaker@carmelita.test'

$today = (Get-Date).Date
$tomorrow = $today.AddDays(1)

# Server must reject same-day requests even when a client tries to spoof an
# older created_at value.
$sameDayArrival = $today.AddHours(14)
$sameDayDeparture = $sameDayArrival.AddHours(2)
Invoke-ExpectedFailure {
  Invoke-RestMethod -Method Post -Uri "$restUrl/visitor_requests" `
    -Headers (Get-AuthHeaders $tenant 'return=representation') `
    -ContentType 'application/json' `
    -Body (New-VisitorBody `
      $tenant `
      $sameDayArrival `
      $sameDayDeparture `
      "Same-day policy test $([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" `
      $today.AddDays(-7))
} 'same-day visitor request must be rejected'

# Arrival before 09:00 Manila time must be rejected.
$earlyArrival = $tomorrow.AddHours(8).AddMinutes(59)
$earlyDeparture = $tomorrow.AddHours(10)
Invoke-ExpectedFailure {
  Invoke-RestMethod -Method Post -Uri "$restUrl/visitor_requests" `
    -Headers (Get-AuthHeaders $tenant 'return=representation') `
    -ContentType 'application/json' `
    -Body (New-VisitorBody `
      $tenant `
      $earlyArrival `
      $earlyDeparture `
      "Early-arrival policy test $([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())")
} 'visitor arrival before 9 AM must be rejected'

# Departure after 21:00 Manila time must be rejected.
$lateArrival = $tomorrow.AddHours(19)
$lateDeparture = $tomorrow.AddHours(21).AddMinutes(1)
Invoke-ExpectedFailure {
  Invoke-RestMethod -Method Post -Uri "$restUrl/visitor_requests" `
    -Headers (Get-AuthHeaders $tenant 'return=representation') `
    -ContentType 'application/json' `
    -Body (New-VisitorBody `
      $tenant `
      $lateArrival `
      $lateDeparture `
      "Late-departure policy test $([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())")
} 'visitor departure after 9 PM must be rejected'

# Overnight requests remain forbidden.
$overnightArrival = $tomorrow.AddHours(19)
$overnightDeparture = $tomorrow.AddDays(1).AddHours(9)
Invoke-ExpectedFailure {
  Invoke-RestMethod -Method Post -Uri "$restUrl/visitor_requests" `
    -Headers (Get-AuthHeaders $tenant 'return=representation') `
    -ContentType 'application/json' `
    -Body (New-VisitorBody `
      $tenant `
      $overnightArrival `
      $overnightDeparture `
      "Overnight policy test $([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())")
} 'overnight visitor request must be rejected'

# Existing happy-path/RLS/lifecycle smoke test.
$arrival = $today.AddDays(2).AddHours(14)
$departure = $arrival.AddHours(2)
$marker =
  "Automated visitor RLS test $([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"

$createBody = New-VisitorBody `
  $tenant `
  $arrival `
  $departure `
  $marker

$created = Invoke-RestMethod -Method Post -Uri "$restUrl/visitor_requests" `
  -Headers (Get-AuthHeaders $tenant 'return=representation') `
  -ContentType 'application/json' -Body $createBody

$requestId = $created[0].id
if (-not $requestId) {
  throw 'Tenant submission did not return a request ID'
}

Invoke-ExpectedFailure {
  $body = @{
    p_request_id = $requestId
    p_action = 'approve'
    p_note = $null
  } | ConvertTo-Json

  Invoke-RestMethod -Method Post `
    -Uri "$restUrl/rpc/transition_visitor_request" `
    -Headers (Get-AuthHeaders $tenant) `
    -ContentType 'application/json' `
    -Body $body
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

if ($ownerRows.Count -ne 1) {
  throw 'Owner could not read the visitor request'
}

foreach ($step in @(
  @{ session = $owner; action = 'approve'; expected = 'approved' },
  @{ session = $caretaker; action = 'record_arrival'; expected = 'arrived' },
  @{ session = $caretaker; action = 'record_departure'; expected = 'completed' }
)) {
  $body = @{
    p_request_id = $requestId
    p_action = $step.action
    p_note = if ($step.action -eq 'approve') {
      'Remote E2E approval'
    } else {
      $null
    }
  } | ConvertTo-Json

  $result = Invoke-RestMethod -Method Post `
    -Uri "$restUrl/rpc/transition_visitor_request" `
    -Headers (Get-AuthHeaders $step.session) `
    -ContentType 'application/json' `
    -Body $body

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

if ($events.Count -lt 3) {
  throw 'Visitor audit events are incomplete'
}

[pscustomobject]@{
  request_id = $requestId
  final_status = $tenantResult[0].status
  audit_event_count = $events.Count
  same_day_rejected = $true
  early_arrival_rejected = $true
  late_departure_rejected = $true
  overnight_rejected = $true
  created_at_spoof_blocked = $true
  tenant_cannot_approve = $true
  guardian_isolated = $true
}
