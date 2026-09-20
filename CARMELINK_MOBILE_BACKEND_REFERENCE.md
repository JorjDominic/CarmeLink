# CarmeLink Mobile Backend Reference

## React DevTools Data Contract

> Verified against the repository migrations and Flutter service on September 20, 2026. Items marked **LIVE CONFIRM** must still be checked in deployed Supabase.

## Purpose

This document explains how the React app must use the gate/geofence backend. Use the same Supabase project as Flutter, authenticate normally, and rely on RLS. Never expose a service-role key in React.

```text
profiles (identity)
  ├─ 1:1 tenant_details (current summarized state)
  ├─ 1:N gate_events (immutable movement history)
  └─ 1:N curfew_requests (exception history)

dorm_boundary_config (shared geofence definition)
```

## Why Every Gate Input Creates a New Row

`gate_events` is an append-only history. Each observation must remain available:

```text
08:00 OUT → 12:10 IN → 13:00 OUT → 18:30 IN
```

Changing one row repeatedly would erase movement times, curfew evidence, staff actions, and the audit trail. Current state is stored separately in `tenant_details.current_gate_status` and updated automatically after every new event.

| Question | Read from |
|---|---|
| Where is the tenant now? | `tenant_details.current_gate_status` |
| When was the latest check? | `tenant_details.last_gate_event_at` |
| What happened over time? | `gate_events ORDER BY checked_at DESC` |
| Was the latest observation suspicious? | Latest `gate_events.status` |

## `profiles` — User Identity

One row represents one Supabase Auth user.

| Column | Meaning | React usage |
|---|---|---|
| `id` | UUID matching the authenticated user ID. | Used by `tenant_id`, `created_by`, and related tables. |
| `full_name` | Display name. | Join into tenant selectors and event timelines. |
| `role` | `tenant`, `guardian`, `caretaker`, or `owner`. | Controls screens, RLS, and RPC authorization. |

Only profiles with `role = 'tenant'` may be gate-event targets.

## `gate_events` — Immutable Movement History

### Row meaning

One row equals one GPS/geofence or staff observation at one time. A tenant normally has many rows. Client `INSERT`, `UPDATE`, and `DELETE` are revoked; create rows only through the RPCs below.

| Column | Type | Meaning and React behavior |
|---|---|---|
| `id` | `uuid` | Generated event ID; use as the React list key. |
| `tenant_id` | `uuid` | Observed tenant; references `profiles.id`. Filter timelines with this. |
| `direction` | nullable `text` | `IN`, `OUT`, or `NULL`. Must be null when status is `UNAVAILABLE`. |
| `verification_method` | `text` | `GPS Geofence` or `Staff Manual Log`. Shows how the event was created. |
| `status` | `text` | `Verified`, `Flagged`, or `UNAVAILABLE`. This is the actual implemented field; there are no `check_status` or `curfew_status` columns. |
| `checkpoint_type` | `text` | `daytime`, `pre_curfew`, `curfew`, `manual_entry`, or `on_demand`. |
| `checked_at` | `timestamptz` | Observation time and primary timeline sort field. |
| `notes` | nullable `text` | Required for staff manual logs; normally null for GPS events. |
| `created_by` | nullable `uuid` | Tenant or staff profile that created the event. |
| `created_at` | `timestamptz` | Database insertion time; use `checked_at` for the timeline. |

Rules:

- `Verified`/`Flagged` requires `IN` or `OUT`; `UNAVAILABLE` requires a null direction.
- Manual logs require nonblank notes.
- At 10 PM–6 AM Asia/Manila time, the server changes a verified event to `Flagged` when no active approved curfew request exists.
- No tenant coordinates or raw distances are stored.
- Do not remove consecutive equal directions; each is a genuine observation.

```ts
const { data, error } = await supabase
  .from('gate_events')
  .select(`
    id, tenant_id, direction, verification_method, status,
    checkpoint_type, checked_at, notes, created_by,
    tenant:profiles!tenant_id(full_name),
    creator:profiles!created_by(full_name)
  `)
  .eq('tenant_id', tenantId)
  .order('checked_at', { ascending: false })
  .limit(50);
```

RLS permits staff to read all events, tenants to read their own, guardians to read linked tenants, and anonymous users to read none.

## `tenant_details` — Current Tenant Summary

### Row meaning

Exactly one row per tenant. `profile_id` is both primary key and profile reference. This table contains current state; it is not a history table.

| Column | Type | Meaning and React behavior |
|---|---|---|
| `profile_id` | `uuid` | Tenant profile ID and unique row key. |
| `birth_date` | nullable `date` | Private date of birth. |
| `address` | `text` | Tenant address. |
| `school_name` | `text` | School name. |
| `course_or_program` | `text` | Course/program. |
| `year_level` | nullable `smallint` | Academic year, limited to 1–20. |
| `emergency_contact_name` | `text` | Emergency contact name. |
| `emergency_contact_phone` | `text` | Emergency contact phone. |
| `emergency_contact_relationship` | `text` | Relationship to tenant. |
| `contract_starts_on` | nullable `date` | Cached active-contract start. Read-only summary; contracts are the source of truth. |
| `contract_ends_on` | nullable `date` | Cached active-contract end. |
| `residency_status` | `text` | `active`, `moving_out`, or `inactive`; this is residency, not physical location. |
| `current_gate_status` | `text` | Current physical summary: `IN`, `OUT`, or `UNAVAILABLE`. |
| `last_gate_event_at` | nullable `timestamptz` | Timestamp copied from the newest inserted event. |
| `created_at` / `updated_at` | `timestamptz` | Audit/freshness timestamps. |

The gate-event trigger owns `current_gate_status` and `last_gate_event_at`. React must not edit them directly.

```ts
const { data, error } = await supabase
  .from('tenant_details')
  .select(`profile_id, residency_status, current_gate_status,
           last_gate_event_at, contract_starts_on, contract_ends_on,
           profiles!profile_id(full_name)`)
  .order('last_gate_event_at', { ascending: false });
```

## `dorm_boundary_config` — Official Geofence

One active row describes the dormitory boundary. It stores shared dorm geometry, never tenant location history.

| Column | Meaning and React behavior |
|---|---|
| `id` | Configuration UUID. |
| `boundary_name` | Display name. |
| `boundary_mode` | `polygon` or `circle`; selects calculation method. |
| `center_latitude`, `center_longitude` | Circle center/fallback. |
| `radius_meters` | Circle radius; repository default `50.0`. |
| `edge_buffer_meters` | Edge tolerance; repository default `3.0`. |
| `polygon_points` | Ordered JSON array of `{lat, lng}` vertices; preserve order. |
| `is_active` | Load true rows for normal operation. |
| `updated_at`, `created_at` | Audit timestamps. Writers must explicitly update `updated_at`. |

```ts
const { data, error } = await supabase
  .from('dorm_boundary_config').select('*')
  .eq('is_active', true)
  .order('updated_at', { ascending: false })
  .limit(1).maybeSingle();
```

The migration seeds a polygon around `14.949402, 120.884676`. **LIVE CONFIRM** the active production coordinates. Authenticated users can read; current policy allows staff to modify.

## `curfew_requests` — Curfew Exception Source

One row is one requested absence window.

| Column | Meaning |
|---|---|
| `id` | Request UUID. |
| `tenant_id` | Requesting tenant. |
| `destination`, `reason` | Request context. |
| `departure_time`, `expected_return_time` | Exception window; return must be later than departure. |
| `status` | `pending_guardian`, `pending_staff`, `approved`, `rejected`, `cancelled`, or `completed`. |
| Guardian/staff fields | Reviewer IDs, decisions, notes, and timestamps. |
| `created_at`, `updated_at` | Audit timestamps. |

Only a request with `status = 'approved'` where database `now()` falls between departure and return prevents automatic curfew flagging.

## Supported Writes: RPCs Only

### Tenant geofence event

```sql
record_tenant_geofence_check(
  p_direction text,
  p_status text,
  p_checkpoint_type text
) returns uuid
```

```ts
const { data: eventId, error } = await supabase.rpc(
  'record_tenant_geofence_check', {
    p_direction: 'IN',
    p_status: 'Verified',
    p_checkpoint_type: 'on_demand',
  });
```

Caller must be the tenant. Status may be `Verified` or `UNAVAILABLE`; checkpoints may be `daytime`, `pre_curfew`, `curfew`, or `on_demand`. Flutter evaluates the boundary on-device and sends no coordinates. React simulators must do the same.

### Staff manual event

```sql
record_staff_manual_log(
  p_tenant_id uuid,
  p_direction text,
  p_notes text
) returns uuid
```

```ts
const { data: eventId, error } = await supabase.rpc(
  'record_staff_manual_log', {
    p_tenant_id: tenantId,
    p_direction: 'OUT',
    p_notes: 'Observed leaving through the main gate.',
  });
```

Caller must pass `is_staff()`. The target must be a tenant, direction must be `IN`/`OUT`, and notes are mandatory. The server fills method, status, checkpoint, timestamps, and creator.

Both RPCs are `SECURITY DEFINER` and perform server-side authorization.

## Realtime

The migration publishes `gate_events`. **LIVE CONFIRM** this in production. Realtime respects RLS and payloads do not include joined profile names.

```ts
const channel = supabase.channel('gate-events-live')
  .on('postgres_changes', {
    event: 'INSERT', schema: 'public', table: 'gate_events'
  }, () => {
    // Refetch the joined event and tenant_details current status.
  })
  .subscribe();
```

## React Screen Rules

- Status list: read `tenant_details`; show latest event status as a separate badge.
- Timeline: read every `gate_events` row ordered by `checked_at DESC`.
- Manual log: call `record_staff_manual_log`; never insert directly.
- Coordinate simulator: coordinates may exist temporarily in UI memory, but send/persist only the calculated result.
- After a successful RPC: use the returned event UUID or refetch; the summary trigger completes in the same transaction.

## Deployment Checklist

- [ ] Confirm React and Flutter use the same project URL.
- [ ] Confirm no service-role secret is shipped to React.
- [ ] Add/confirm safe test-account isolation before writing production data; it is not present in reviewed migrations.
- [ ] Confirm actual table columns and RPC signatures match this document.
- [ ] Confirm direct gate-event mutations are revoked.
- [ ] Confirm event insertion updates the tenant summary.
- [ ] Confirm active boundary coordinates.
- [ ] Confirm Realtime publication and RLS for each role.
- [ ] Confirm no tenant coordinates or raw distances are stored or logged.
