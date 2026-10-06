# Dynamic configuration, rename, and removal audit

Date: 2026-10-07

Scope: source inspection of production room management, owner configuration,
tenant forms, announcements, billing selectors, and shared management services.
This is an implementation plan, not a claim that the live database or every
screen was tested. Existing uncommitted work was left intact.

## Findings

| Area | Existing behavior | Gap / recommended action | Priority |
| --- | --- | --- | --- |
| Rooms | Owner can add rooms with four beds, edit floor/description, archive and reactivate | Room number cannot be renamed in UI or database. Implement coordinated rename and remove number-based identity assumptions. | P1 |
| Room removal | Archive exists; occupied rooms cannot be archived; database rejects hard deletion | Make Archive discoverable as removal from available inventory. Keep history and restore action. Permanent deletion requires a separate dependency-aware design. | P1 UX |
| Bed spaces | Label editing exists; room has exactly four beds | Arbitrary add/delete conflicts with the current four-bed rule. Retain label editing; changing capacity is a separate business-rule change. | Existing rule |
| Floors | Free-text floor on room create/edit; floor plan discovers floors from rooms | No central floor rename/merge. Typing variants can split the same floor. Add existing-floor suggestions and an owner bulk rename with collision preview. | P2 |
| Maintenance categories | Database-backed add, label edit, ordering, deactivate/reactivate | No permanent delete; add explicit Archive/Restore actions and active/archived filtering if removal is unclear. | P1 UX |
| Common areas | Same configurable lifecycle as maintenance categories | Same removal/discoverability gap. Preserve saved report locations. | P1 UX |
| Concern report types | Database-backed labels, add/edit/order/deactivate; fixed workflow mapping | System choices are locked, including label editing. Decide whether owner-editable display labels are needed; retain stable workflow codes. | P2 |
| Announcement records | Title/body editing and delete already wired to UI/service | No missing basic record delete. | Existing |
| Announcement categories | Six hardcoded categories in owner editor and tenant filters; SQL check constraint | Add configurable categories end-to-end, including filters, badges, historical labels, and database validation. | P2 |
| Payment methods | Tenant receipt form hardcodes GCash, Maya, Bank transfer, Cash; database also constrains methods | Add managed payment channels with instructions and stable codes; update every payment entry path together. | P2 |
| Billing / utility categories | Hardcoded selectors for charge and utility types | Some values drive calculations/accounting. Allow configurable display labels or subtypes while retaining calculation codes. Trace backend usage before enabling arbitrary types. | P3 |
| Cleaning schedule management | Management service lists active schedules and regenerates a room | No individual edit/remove operation in this service. Define override/deactivate semantics and whether regeneration preserves overrides before adding controls. | P3 |
| Roles, audiences, statuses, urgency, weekdays, sort filters | Fixed choices appear across forms | These represent permissions, workflow, time, or UI behavior. Keep codes fixed; any configurable labels must preserve behavior. | Intentional fixed values |

## Code evidence

- `lib/views/owner/room_monitoring_page.dart`: `RoomEditor` only creates floor and
  description controllers and submits `number: r.number`; Archive/Reactivate and
  bed-label editing already exist.
- `lib/services/room_service.dart`: `updateRoom` accepts a number, but `deleteRoom`
  is an archive operation; `deleteBed` still calls physical deletion even though
  the newer database rule rejects it. Clarify or retire misleading service APIs
  after checking callers.
- `supabase/migrations/202610070009_room_expansion_and_dynamic_capacity.sql`:
  `protect_room_lifecycle` explicitly rejects renaming and hard deletion; the
  bed lifecycle enforces four beds. Owner authorization, trimmed case-insensitive
  uniqueness, and occupied-room archive protection must survive any replacement.
- `lib/views/owner/floor_plan_page.dart`: layout slot matching and selection use
  room numbers; maintenance matching uses text `contains(room.number)`. A rename
  can move a room outside its original slot and lose report associations.
- `lib/services/dormitory_configuration_service.dart`: only three configurable
  groups exist: `maintenance_category`, `common_area`, and `report_type`.
- `lib/views/owner/dormitory_configuration_page.dart`: custom choices have Edit
  and active switches; system choices display a lock. No delete action exists.
- `supabase/migrations/202610070006_dormitory_configuration_and_report_addenda.sql`:
  owner policies exclude system choices; option references and protected workflow
  mappings mean a delete/rename change cannot be UI-only.
- `lib/views/owner/owner_pages.dart`: announcement category dropdown is literal;
  announcement edit/delete handlers already exist.
- `lib/views/tenant/tenant_pages.dart`: payment-method literals, announcement
  category filters, and Low/Medium/High urgency are still fixed.
- `supabase/migrations/202609110001_announcements_board.sql` and payment/billing
  migrations constrain category/method values. Review later migrations as part
  of implementing their replacements.
- `lib/views/owner/utility_charge_cart_dialog.dart` and
  `lib/views/owner/billing_management_page.dart`: fixed billing selectors.
- `lib/services/cleaning_schedule_management_service.dart`: list/regenerate only.

## Implementation sequence

### 1. Room rename and dependable room identity

1. Trace room-number references in layouts, report locations, exports, and
   historical documents. Preserve historical document text intentionally.
2. Use room IDs for live selection and associations. Retain stable layout slots
   independently of the displayed room number. For historical location strings,
   use explicit linkage or a reviewed backfill; never blindly replace substrings.
3. Add an owner-only Room number field (trimmed, required, max 40 characters).
4. Add a new migration allowing rename while preserving lifecycle safeguards;
   retain room/bed IDs, assignments, and four-bed capacity. Do not rewrite an
   already applied migration.
5. Refresh list/detail/floor plan and relevant tenant/staff views after save.
6. Test duplicate and case-only names, blank input, unauthorized users, occupied
   room rename, linked reports, archived rooms, and unchanged assignments.

### 2. Consistent removal and restore

1. Use clearly named Archive/Restore controls for custom dropdown choices and
   rooms, with confirmation explaining the effect on new selections.
2. Add active/archived filtering to configuration; keep archived values readable
   on old records and out of new selections.
3. Retain occupied-room protection and protected system choices.
4. If permanent deletion is later required for unused records, implement an
   atomic database operation that checks all references, permissions, concurrent
   usage, and audit requirements. Used records should remain archived.
5. Verify open forms react correctly when their selected choice is archived and
   that rapid repeated actions cannot submit conflicting changes.

### 3. More configurable business choices

1. Start with announcement categories: extend option groups, seed existing
   categories, add stable references and history handling, migrate validation,
   and update editor/filter/badge consumers across roles.
2. Add payment channels with display name, instructions, availability, ordering,
   and stable processing codes. Update receipt forms and staff payment entry
   together, preserving past transaction labels and processing behavior.
3. Add floor suggestions and bulk rename/merge. Preview affected rooms before
   committing a multi-room update.
4. Evaluate billing display labels/subtypes and cleaning overrides separately.

## Verification and completion criteria

- Owner creates, renames, archives, and restores supported business choices.
- Other roles cannot mutate owner configuration through UI or direct API calls.
- Changes appear in dependent forms without restarting the app.
- Archived choices remain readable historically and unavailable for new records.
- Renaming preserves identity, layout placement, assignments, and report linkage.
- Database regression tests verify authorization, uniqueness, references, and
  archive protection; widget tests verify real form interactions and refresh.
- Run relevant existing phase 2 configuration, phase 3 dynamic-options, and
  phase 4 room-expansion tests alongside new behavioral tests.
- Validate mobile dialog sizing and the shared web portal screens.

Implementation status: audit and plan only. No application code, database
migrations, or live records were changed during this audit.

## Follow-up: searchable lists and selectors

The subsequent search request is implemented separately from the rename/delete
plan above:

- Shared searchable form picker for 18 growing selectors: tenant/guardian choices,
  bills, maintenance categories, rooms/common areas, and concern report types.
- Search boxes for configuration choices, both room/bed assignment flows,
  utility room multi-selection, and cleaning rotations.
- Existing main room-list and floor-plan search retained.
- Case-insensitive label matching, trimmed queries, clear search, no-results
  feedback, cancellation without changing selection, and lazy result rendering.
- Selection uses the original record ID/value. Disabled fields/options remain
  disabled; selections removed during an open picker are not submitted.
- Search does not require a database migration. The rename/delete and additional
  configurable-group work above remains planned, not implemented.
