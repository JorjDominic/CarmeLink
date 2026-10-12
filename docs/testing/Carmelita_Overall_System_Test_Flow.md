# Carmelita Overall System Test Flow

Prepared: October 12, 2026 (Asia/Manila)

This is a manual test plan, not a completed test report.

## Owner

| Order | Module | Actions | Expected result | Status |
|---|---|---|---|---|
| O01 | Login & role access | Sign in with valid and invalid credentials. Reopen the app and attempt another role workspace. | Correct Owner workspace; invalid login and unauthorized routes are rejected. | |
| O02 | Dashboard & navigation | Open dashboard cards, Operations, search, filters and mobile/web menus. Compare counts with source records. | Links open the correct module; counts agree with the records. | |
| O03 | Dormitory configuration | Review report categories, payment methods and common areas. Add or deactivate a test option and reopen its form. | Saved active options appear; inactive choices cannot be newly selected. | |
| O04 | Floors, rooms & beds | Create test floors, rooms and beds; review floor plan, capacity and occupancy. Try a duplicate or invalid entry. | Room identities and bed availability remain consistent; invalid records are rejected. | |
| O05 | Accounts & invitations | Create Tenant, Guardian and Caretaker test accounts; validate duplicates and invitation flow. Test account status changes. | Correct roles and account states persist; invitations route to the intended account. | |
| O06 | Tenant onboarding | Open tenant directory and onboarding checklist. Review profile, emergency contact, IDs, lease upload and signature. | Missing requirements are visible; verified details and documents belong to the correct tenant. | |
| O07 | Contracts & deposits | Create and activate a contract with dates and rent; inspect generated monthly bills. Record a separate security-deposit receipt. | Correct contract months are generated once; deposit receipt remains separate from monthly rent. | |
| O08 | Room assignment & transfers | Assign an available bed, try an occupied bed, then process a transfer/amendment. Recheck old and new occupancy. | No double assignment; room, bed and transfer history match the active assignment. | |
| O09 | Guardian links | Link a Guardian to a Tenant; verify linked visibility. Switch linked tenants and test an unrelated account. | Only linked tenants are visible; link changes persist without cross-tenant leakage. | |
| O10 | Billing & adjustments | Inspect rent and utilities; create utility allocations and an approved additional charge. Exercise rent override and bill-management actions. | Amounts and periods are correct; changes are audited and do not duplicate bills. | |
| O11 | Manual payments | Review a tenant proof, approve one and reject another with notes. Record a staff receipt and test a partial payment. | Only verified amounts reduce balances; receipt, reviewer, date and remaining balance are correct. | |
| O12 | Automatic / advance payments | Enable configured PayMongo sandbox. Review selected-month requests, overlap protection, confirmation and reconciliation (Tenant T07-T08). | Only Owner changes collection mode; confirmed months credit once and retain their breakdown. | |
| O13 | Income, expenses & analytics | Create a sample expense and inspect financial totals, reporting filters and trends. Compare collected totals with verified ledger entries. | Amounts reconcile; pending, rejected and demo labels are handled consistently. | |
| O14 | Maintenance & confidential reports | Review tenant submissions; assign, update and resolve maintenance. Review confidential reports and authorized follow-up/addenda. | Correct lifecycle and history; confidential details stay restricted to authorized viewers. | |
| O15 | Cleaning & inspections | Set cleaning rotation/override and record a missed duty. Schedule a room inspection, add findings/evidence and publish permitted results. | Correct tenants and room receive schedules/notices; findings and evidence stay attached to the record. | |
| O16 | Conduct & disciplinary records | Create a test conduct case; publish a response request, review tenant response/appeal, and inspect disciplinary history. | Case status, evidence, decision and audit history remain consistent; records stay scoped. | |
| O17 | Visitors, curfew & work profiles | Review visitor requests and check-in/out; inspect curfew requests, work-curfew profiles and presence records. Test boundary tools separately. | Permitted transitions persist; guardian/staff handoff is correct. Curfew/geofence release status is explicitly recorded. | |
| O18 | Notices, communication & closure | Publish a targeted notice and send a test message. On a separate departure account, test eviction notice, inspection, settlement, owner approval and final closure; review retention access. | Correct recipients receive notices; only authorized Owner decisions finalize closure and approved deposit outcomes. | |
## Caretaker

| Order | Module | Actions | Expected result | Status |
|---|---|---|---|---|
| C01 | Login & operational dashboard | Sign in; open cards, Operations and menus. Attempt Owner-only Contracts, analytics, financial settings and collection-mode actions. | Operational workspace loads; Owner-only actions remain unavailable and are rejected if attempted directly. | |
| C02 | Accounts & tenant directory | Create permitted Tenant/Guardian accounts and view tenant records. Try creating an Owner/Caretaker or altering protected account fields. | Permitted account work succeeds; privileged role creation and protected changes are blocked. | |
| C03 | Rooms & assignments | Inspect occupancy and beds; perform permitted assignment/transfer steps. Attempt assigning the same bed twice. | Correct availability and occupancy persist; conflicting assignments are rejected. | |
| C04 | Billing & utilities | Inspect tenant balances and utility allocation workflow. Attempt an Owner-only non-utility charge or rent-rate override. | Permitted utility work succeeds; Owner financial approvals remain protected. | |
| C05 | Manual receipts & proof review | Record a received payment with amount, receipt and date. Review permitted proofs; retry a receipt and inspect partial balances. | Receipts are recorded once; allowed review updates only the appropriate bill. | |
| C06 | PayMongo requests | Expand an active multi-month breakdown; check status and cancel a pending request. Attempt a staff receipt for a covered month. | All covered months are visible; cancellation is provider-confirmed and active overlap blocks a receipt. | |
| C07 | Maintenance management | Open a Tenant maintenance report; assign, update progress, add completion details and close it. Reopen the record history. | Updates persist and appear in the Tenant view with correct status and history. | |
| C08 | Confidential reports | Open authorized confidential reports, add permitted follow-up and inspect access boundaries. | Only authorized records are visible; follow-up preserves original content and authorship. | |
| C09 | Cleaning schedules & reports | Review rotation, test an override and submit a missed-duty record with evidence. Check Tenant schedule/report visibility. | Correct room and affected resident are selected; changes and evidence persist. | |
| C10 | Room inspections | Schedule or update permitted inspection records; add findings/evidence and review published notices. | Correct room records and notices; inspection steps do not finalize Owner settlement decisions. | |
| C11 | Conduct cases & appeals | Create/update permitted operational case steps and review a resident response. Attempt Owner-only eviction decisions. | Case history is consistent; Owner decisions remain protected. | |
| C12 | Visitors, curfew & work profiles | Approve/reject permitted visitor requests and record visits. Process permitted curfew/work-profile steps and inspect presence history. | Permitted transitions and notifications are correct; WIP presence functionality is recorded separately. | |
| C13 | Departure & settlement support | Review a test departure case; record operational inspection/clearance details and a deduction proposal. Attempt final financial approval. | Operational preparation persists; Owner approval and final financial decisions remain protected. | |
| C14 | Communication, retention & profile | Publish a permitted notice; send a message and open alerts. Review retention permissions, edit profile/settings and sign out. | Correct recipients and access scope; only authorized settings save and logout clears the session. | |
## Tenant

| Order | Module | Actions | Expected result | Status |
|---|---|---|---|---|
| T01 | Login & access gate | Sign in as a new, incomplete, active and restricted Tenant. Try another role route and another Tenant record. | Access follows residency/onboarding state; other roles and unrelated tenant records are blocked. | |
| T02 | Onboarding & requirements | Complete personal/emergency details; upload IDs and lease, sign on screen and revisit checklist. Try missing fields or unsupported files. | Validation works; files/signature persist and incomplete requirements remain visible. | |
| T03 | Home & shortcuts | Open Home cards, summary totals and each shortcut. Compare displayed room, next bill and report status with module details. | Home reflects the correct tenant and opens the intended records. | |
| T04 | My room & contract | Inspect bed, room, roommates, facilities, contract and security-deposit information. Recheck after an Owner assignment/transfer. | Only the tenant assignment and allowed resident details appear; transfer data stays consistent. | |
| T05 | Billing & future rent schedule | Open all bills, current balances, filters and future rent schedule. Compare periods and dates with the active contract. | Current outstanding and scheduled future rent are distinguished; paid/voided bills are handled correctly. | |
| T06 | Manual payment proof | In Manual mode, submit a reference, receipt and partial amount. Test invalid/over-balance amounts; follow staff approval and rejection. | Proof stays pending until verified; accepted amounts reduce balances and rejection notes are visible. | |
| T07 | PayMongo month selection & QR | In Automatic mode, select one rent month, then multiple months; deselect all. Check dates, balances and total, then generate one QR. | Correct month breakdown and combined amount; empty selection cannot pay; one request covers selected rent bills. | |
| T08 | PayMongo outcomes & saved breakdown | Simulate success, failure, cancellation and expiry; leave/reopen a request. Reopen each paid bill breakdown and repeat status refresh. | Success credits each month once; other outcomes do not credit. Saved months/reference persist; overlaps are blocked. | |
| T09 | Maintenance reports | Submit issue details and evidence; inspect staff updates, add permitted follow-up and cancel an eligible report. | Own report progresses correctly; invalid submissions and forbidden transitions are rejected. | |
| T10 | Confidential reports | Submit a test confidential concern and evidence; inspect own status and permitted addenda. Try another Tenant report. | Own records remain accessible; unrelated tenant/confidential data stays private. | |
| T11 | Cleaning schedule & records | Open current rotation and overrides; inspect own published missed-duty records. Recheck after staff updates. | Correct room/resident duties and dates appear; private operational data is not exposed. | |
| T12 | Room inspections | Open an inspection notice, findings and permitted evidence; test acknowledgement/response where offered. | Published information belongs to the tenant room; unpublished staff records stay restricted. | |
| T13 | Conduct responses & appeals | Open own case, submit a response/appeal and follow staff decisions. Attempt changing a staff decision. | Response and history persist; only permitted own-case actions are available. | |
| T14 | Visitor requests | Request a visit; test invalid dates/details, staff rejection/approval and scheduled visit history. | Requests belong to the correct tenant; only valid schedules and allowed status transitions succeed. | |
| T15 | Curfew, work profile & presence | Submit an exception with dates/reason; exercise Guardian endorsement and staff review. Check work-profile evidence and location permission states. | Correct approval chain and own history; unavailable location is not presented as confirmed presence. Record WIP status. | |
| T16 | Communication, profile & departure | Read notices, send messages and open alerts; edit profile/settings and sign out. With a separate departure Tenant, test move-out request, notices and settlement visibility. | Correct recipient scope and session behavior; own departure status is visible without staff financial privileges. | |
## Guardian

| Order | Module | Actions | Expected result | Status |
|---|---|---|---|---|
| G01 | Login & role access | Sign in with valid/invalid credentials; reopen app and attempt Tenant/Owner/Caretaker workspaces. | Guardian workspace only; invalid login and unauthorized role routes are rejected. | |
| G02 | Linked-tenant selection | Test no link, one link and multiple links; switch the active resident and attempt an unrelated tenant record. | Empty state is clear; every module follows the selected linked resident only. | |
| G03 | Home & tenant information | Compare Home summary with resident contact, room, bed, residency and school information. Refresh after staff changes. | Correct linked resident and allowed profile/assignment details; changes appear on refresh. | |
| G04 | Payment status | Inspect linked bills before and after manual and PayMongo payment; verify current outstanding versus scheduled rent. | Correct linked balances/status; Guardian cannot verify payments or change collection settings. | |
| G05 | Documents | Open linked contract, lease and permitted document checklist/downloads. Attempt editing files or viewing another tenant document. | Permitted documents are view-only; unrelated or unauthorized files cannot be accessed. | |
| G06 | Curfew endorsement & presence | Endorse and decline linked curfew requests; test remarks, status history, alert time and permission/unavailable states. | Endorsement does not bypass required staff review; linked presence and alerts are accurate. Record WIP status. | |
| G07 | Notices | Open published guardian/linked-resident notices and filters. Check expired or differently targeted announcements. | Only notices relevant to the Guardian are shown; links open the correct content. | |
| G08 | Messages | Send and receive permitted staff/resident messages; check unread counts, history and contact visibility. | Correct recipients and thread history; unauthorized conversations are not exposed. | |
| G09 | Notifications & resident notices | Trigger test payment, curfew and relevant departure notices; open them and mark read. Switch linked tenant and refresh. | Alerts reach intended accounts and correct records; inaccessible destinations reveal no private data. | |
| G10 | Profile, settings & logout | Edit allowed profile fields; check theme, password and notification preferences. Log out then attempt reopening a protected page. | Allowed changes persist; protected resident/staff fields stay locked and logout ends access. | |

## Cross-role handoffs

### X01 Onboarding
Owner creates account/contract > Tenant completes requirements > staff reviews permitted steps > Owner assigns bed > Guardian checks linked details.
Expected: One consistent resident identity, active assignment and requirement state across roles.

### X02 Manual payment
Tenant submits partial proof > Owner/Caretaker verifies or rejects > Tenant and Guardian refresh balances/history.
Expected: Only verified amount is credited; rejection leaves balance unchanged and shows the review result.

### X03 Advance PayMongo payment
Tenant selects November/December > reviews breakdown > generates one request > simulates success > staff checks ledger > Tenant reopens receipt > Guardian checks balances.
Expected: November remaining PHP 3,000 + December PHP 3,500 = PHP 6,500; each month is credited once, with one provider reference.

### X04 Payment conflict
Create a multi-month request > attempt overlapping request/staff receipt > change or void a selected bill > confirm provider payment.
Expected: Overlap is blocked. Changed balance/voided bill sends the entire received payment to needs_review; no partial month credit.

### X05 Reports & room care
Tenant reports maintenance/concern > staff updates it; staff publishes cleaning/inspection records > affected Tenant checks permitted details.
Expected: Correct status, evidence, room and notifications; confidential and unpublished records stay restricted.

### X06 Curfew & visitors
Tenant requests exception > Guardian endorses/declines > staff performs permitted final review; Tenant requests visit > staff records permitted visit transitions.
Expected: Correct approval chain and recipient scope; actual presence/location testing remains a separate WIP/integration check.

### X07 Communication
Staff publishes targeted notice > Tenant/Guardian reads it; exchange permitted messages > recipients open notifications.
Expected: Correct audiences, thread history, unread state and notification destinations; unrelated users receive no private content.

### X08 Departure & closure
Separate Tenant requests move-out, or Owner publishes test eviction decision > staff inspects/prepares settlement > Owner approves/finalizes > Tenant/Guardian check allowed notices.
Expected: Clearance, approved deductions, deposit outcome, contract status and released occupancy remain consistent.

## Final system checks

### Access isolation
Switch users on the same device; open old pages and direct record links; verify Tenant A/Guardian A cannot access Tenant B.
Expected: No stale account data, cross-role writes or unrelated private records.

### Platform & layout
Run staff workflows on web and mobile, and resident workflows on supported phones; test narrow screens, keyboard, long text and uploads.
Expected: No clipping or blocked controls; equivalent actions retain the same permissions.

### Refresh & network recovery
Save on device A, refresh device B, background/resume, interrupt network, retry and reopen records.
Expected: Saved data persists; failures are clear; retries do not duplicate writes or credits.

### Files & notifications
Test allowed and invalid uploads, restricted downloads, denied permissions, foreground/background alerts and notification links.
Expected: Files stay scoped; notification destinations and unread counts are correct.

### Totals & audit history
Compare room occupancy, verified collections, bills, contract schedules, reports and departure state across related pages.
Expected: Source records and summaries agree; changes retain actor/date/history.

### WIP & external integrations
Record curfew/geofence WIP behavior, physical-device location results, feedback preview behavior and PayMongo sandbox configuration.
Expected: Completed, blocked and preview-only behavior are distinguished; external processing is not inferred from a UI screen.

## Run record
Tester / date / build / environment / platforms / account labels / status totals / defect IDs / evidence / retest decision.
