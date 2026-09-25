# CarmeLink User Workflows, Inputs, and Results

> Workflow reference only. Use [`STATUS.md`](STATUS.md) for the current gap and completion tracker.

This document describes the system as a user experiences it.

Status meanings:

- **Working** — the user can complete the workflow in the current app.
- **Needs live verification** — the workflow is built, but must be tested against the deployed backend or a real phone.
- **Partial** — some steps work, but the complete result is not available.
- **Placeholder** — the screen exists, but the intended action does not happen yet.

## General user workflows

### Sign in

- **User:** Any registered tenant, guardian, caretaker, or owner.
- **Input:** Email address and password.
- **Workflow:** Open CarmeLink, enter credentials, and tap Sign in. The app checks the account and identifies the user's role.
- **Result:** The user is taken to the correct tenant, guardian, caretaker, or owner dashboard.
- **State:** **Working; needs live verification** for every production account type.

### Verify email

- **Input:** Email address and six-digit verification code.
- **Workflow:** After an account is created, enter the code received by email. A new code can be requested when necessary.
- **Result:** The account becomes verified and can continue into protected workflows.
- **State:** **Working; needs live email-delivery testing.**

### Recover or change password

- **Input:** Account email, recovery code/link, current password when applicable, and new password.
- **Workflow:** Request recovery, open the recovery link or enter the code, then choose a new password. A signed-in user can also change the password from Settings.
- **Result:** The old password stops working and the new password becomes active.
- **State:** **Working; needs mobile and website link testing.**

### View profile

- **Input:** None.
- **Workflow:** Open Profile from the account menu.
- **Result:** The user sees their name, email, phone, role, and role-related details such as assigned room or linked tenant.
- **State:** **Working.**

### Change appearance

- **Input:** System, light, or dark theme.
- **Workflow:** Open Settings and select a theme.
- **Result:** The app immediately changes appearance.
- **State:** **Working locally; the choice may reset after restarting the app.**

### View and manage notifications

- **Input:** Notification selection or Mark all read.
- **Workflow:** Open the live Notifications page, read an item, or mark all items as read. Tapping a message notification opens the related conversation.
- **Result:** Read status is updated and the appropriate page opens.
- **State:** **Working through the main notification page; partial overall** because one header shortcut still opens an obsolete empty notification page.

### Set notification preferences

- **Input:** On/off choices for notification categories.
- **Workflow:** Open Settings and change the switches.
- **Result:** The switches change on the current screen.
- **State:** **Partial.** Preferences are not saved permanently and do not yet control server notification delivery.

### Send feedback

- **Input:** Feedback category, message, and related form fields.
- **Workflow:** Open Feedback, complete the form, and submit.
- **Result:** The interface acknowledges the action, but no durable feedback record or ticket is created.
- **State:** **Placeholder.**

### Review permissions

- **Input:** Permission actions selected by the user.
- **Workflow:** Open Privacy and Permissions, review camera/location/notification status, and open the phone's app settings if changes are needed.
- **Result:** The operating-system settings page opens so the user can grant or revoke permissions.
- **State:** **Working.**

### Sign out

- **Input:** Sign-out confirmation.
- **Workflow:** Choose Sign out from Settings.
- **Result:** The push token is revoked when possible, tenant geofencing is stopped, cached role data is cleared, and the login screen appears.
- **State:** **Working.**

## Tenant workflows

### View tenant dashboard

- **Input:** None after signing in.
- **Workflow:** Open the tenant home page.
- **Result:** The tenant sees balances, curfew/presence summary, room information, recent activity, and shortcuts for payments, maintenance, visitors, and curfew requests.
- **State:** **Working.**

### View assigned room

- **Input:** None.
- **Workflow:** Open My Room.
- **Result:** The tenant sees room number, floor, bed space, occupancy, roommates, utility information, and room description. If no assignment exists, an incomplete/empty state is shown.
- **State:** **Working; needs live access testing.**

### View bills and payment history

- **Input:** Optional status filter or sorting choice.
- **Workflow:** Open Payments and filter all, due, pending, verified, or rejected items.
- **Result:** The tenant sees rent and utility amounts, due dates, remaining balances, submission status, and receipt access where available.
- **State:** **Working; financial totals need staging reconciliation.**

### Submit payment proof

- **Input:** Bill, payment amount, payment method, reference number, payment date, and receipt image.
- **Workflow:** Choose a bill, tap Pay now, select or photograph a receipt, review any OCR suggestions, correct the values, and submit.
- **Result:** The payment enters pending review and becomes visible to staff. It is not treated as paid until staff approves it.
- **State:** **Working; needs live file-upload and duplicate-submission testing.**

### Scan a receipt

- **Input:** Receipt image.
- **Workflow:** Select or capture the receipt. The app reads visible text and suggests an amount, method, and reference number.
- **Result:** Suggested values are placed in the form for the tenant to verify or change.
- **State:** **Working as an assistant only.** OCR never approves a payment.

### View maintenance reports

- **Input:** Optional status filter.
- **Workflow:** Open Reports or Maintenance and review submitted issues.
- **Result:** The tenant sees issue category, location, urgency, description, photo, status, staff notes, and resolution information.
- **State:** **Working.**

### Submit a maintenance issue

- **Input:** Category, exact location, description, urgency, and optional photo.
- **Workflow:** Tap Report issue, select the location through the form/floor plan, attach a photo if needed, and submit.
- **Result:** A new maintenance request appears in the tenant list and staff maintenance queue.
- **State:** **Working; media authorization needs live testing.**

### Edit or cancel a maintenance issue

- **Input:** Updated report details or cancellation action.
- **Workflow:** Open an editable request, change allowed fields or cancel it.
- **Result:** The report is updated or removed/cancelled when its current status still permits tenant changes.
- **State:** **Working.**

### Submit a confidential concern

- **Input:** Concern category/subject and detailed report.
- **Workflow:** Open Confidential Concern, describe the issue, and submit.
- **Result:** The tenant can see their own report. The owner receives it for confidential review.
- **State:** **Working; owner-only privacy rules need live verification.**

### View announcements

- **Input:** Optional announcement category filter.
- **Workflow:** Open Announcements and browse pinned/recent notices intended for tenants or everyone.
- **Result:** Matching announcements appear in priority/date order.
- **State:** **Working.** Push notification for a new announcement is not working automatically yet.

### Message dormitory staff

- **Input:** Message text.
- **Workflow:** Open Messages, open the staff conversation, type a message, and send it.
- **Result:** The message appears in the conversation, the inbox preview updates, and staff can receive an in-app/push notification.
- **State:** **Working; needs live multi-device testing.**

### Check current presence

- **Input:** Location permission and current phone location.
- **Workflow:** Open Presence and request a check. The app reads the current location and compares it with the configured dormitory boundary.
- **Result:** The tenant sees IN, OUT, or UNAVAILABLE. A valid check creates a new presence-history record; raw coordinates are not stored.
- **State:** **Working; physical-device validation remains.**

### Enable automatic gate monitoring

- **Input:** Always/background location permission.
- **Workflow:** Allow background location. The app registers native monitoring and watches for entering or leaving the dormitory perimeter.
- **Result:** Confirmed changes are queued and sent as gate events. Android can upload them in the background; iOS may wait until the app resumes.
- **State:** **Partial across platforms.** Native monitoring uses a circle even when the configured boundary is a polygon.

### View presence history

- **Input:** Optional show-more/filter action.
- **Workflow:** Open Presence and review prior checks and crossings.
- **Result:** The tenant sees direction, verification method, status, timestamp, and notes where applicable.
- **State:** **Working.**

### Submit a curfew exception

- **Input:** Request type, destination, reason, departure time, and expected return time.
- **Workflow:** Open Curfew, create a request, provide the required information, and submit.
- **Result:** The request appears with its current guardian/staff approval state. An approved active request can prevent an ordinary curfew-time gate event from being flagged.
- **State:** **Working; timezone and full approval-chain testing remain.**

### Cancel a curfew request

- **Input:** A cancellable request.
- **Workflow:** Open the request and choose Cancel.
- **Result:** The request becomes cancelled when its current state permits cancellation.
- **State:** **Working.**

### View an employee curfew profile

- **Input:** None.
- **Workflow:** Open the employee-curfew section and view an approved work schedule.
- **Result:** The tenant sees approved work days, hours, dates, and basis.
- **State:** **Partial.** The profile is stored and displayed but does not currently change automatic gate/curfew classification.

### Submit a visitor request

- **Input:** Visitor name, relationship, purpose, phone number, arrival, and expected departure.
- **Workflow:** Open Visitor Requests, complete the form for a future same-day visit within visiting hours, and submit.
- **Result:** The request enters pending review and appears in the tenant and staff lists.
- **State:** **Working; staging smoke test still required.**

### Edit or cancel a visitor request

- **Input:** Updated details or cancellation action on a pending request.
- **Workflow:** Open the request and edit/cancel before staff processing makes it ineligible.
- **Result:** The request is updated or cancelled, with its event history preserved.
- **State:** **Working.**

### View visitor history

- **Input:** Selected visitor request.
- **Workflow:** Tap View history.
- **Result:** The tenant sees request/approval/arrival/departure events and timestamps allowed for that request.
- **State:** **Working.**

### View rules and policies

- **Input:** Selected policy/rule section.
- **Workflow:** Open Rules and Policies and browse the content.
- **Result:** Dormitory rules are displayed from app content.
- **State:** **Working as static content.**

### Bind a trusted device

- **Input:** Bind trusted device button.
- **Workflow:** Open Device Binding and tap the action.
- **Result:** Only an informational message appears; no trusted-device record is created.
- **State:** **Placeholder.**

## Guardian workflows

### View linked residents

- **Input:** Selected linked tenant when more than one exists.
- **Workflow:** Open the guardian dashboard and choose a resident.
- **Result:** The dashboard updates to show that resident's room, payment, gate, and curfew information.
- **State:** **Working; relationship isolation needs live testing.**

### View resident information and room

- **Input:** Selected linked resident.
- **Workflow:** Open Tenant Information.
- **Result:** The guardian sees permitted identity, residency, education, emergency contact, room, bed, occupancy, and utility details.
- **State:** **Working.**

### Review a curfew request

- **Input:** Guardian decision and optional note.
- **Workflow:** Open Curfew Requests, select a pending request, then approve or reject it.
- **Result:** Approved requests move to the next required stage; rejected requests stop. The tenant sees the updated result.
- **State:** **Working; approval-order rules need live verification.**

### Monitor resident presence

- **Input:** Selected resident and optional filter.
- **Workflow:** Open Presence/Activity and review current state and recent events.
- **Result:** The guardian sees whether the resident is currently IN, OUT, or unavailable plus permitted crossing history.
- **State:** **Working.**

### Set personal outside-alert time

- **Input:** Preferred time, such as 9:00 PM.
- **Workflow:** Choose an alert time in guardian settings/presence UI.
- **Result:** The current app process can determine whether the resident is outside after that time.
- **State:** **Partial/local only.** It resets after restart and does not schedule a real device notification.

### View resident payment status

- **Input:** Selected resident.
- **Workflow:** Open Payments.
- **Result:** The guardian sees outstanding and verification information permitted for the linked resident.
- **State:** **Working.**

### View announcements

- **Input:** Optional category filter.
- **Workflow:** Open Announcements.
- **Result:** Guardian/all-audience notices appear.
- **State:** **Working; automatic announcement push remains incomplete.**

### Message staff

- **Input:** Message text and linked-tenant context.
- **Workflow:** Open Messages, open/create the guardian conversation, and send.
- **Result:** Staff receives the message in the appropriate conversation.
- **State:** **Working; needs live notification testing.**

### View emergency and safety information

- **Input:** None or selected linked resident.
- **Workflow:** Open Emergency/Safety Alerts.
- **Result:** The guardian sees available presence/safety information.
- **State:** **Partial.** There is no fully defined automated emergency escalation and acknowledgement workflow.

## Owner and caretaker workflows

Caretakers use many of the same operational screens as owners. Actions that require owner-only authority should be rejected for caretakers even when a similar screen is visible.

### View staff dashboard

- **Input:** None.
- **Workflow:** Sign in as owner/caretaker and open the dashboard.
- **Result:** The user sees occupancy, payment-review, maintenance, curfew, room, and operational summaries with shortcuts.
- **State:** **Working.**

### Create and manage user accounts

- **Input:** Name, email, phone, role, and role-specific details.
- **Workflow:** Open Account Management, create or edit an account, resend verification/reset, or delete when authorized.
- **Result:** Authentication and profile records are created/updated together and the account appears in the relevant directory.
- **State:** **Working; deployed Edge Function authorization must be verified.**

### Manage tenant room assignment

- **Input:** Tenant, room/bed, or end-assignment action.
- **Workflow:** Open Tenant Directory or room monitoring, choose a tenant and an available bed, then assign/reassign/end assignment.
- **Result:** Occupancy, tenant room view, and directory information update to the new active assignment.
- **State:** **Working; concurrency testing remains.**

### Manage rooms and beds

- **Input:** Room number/floor/details and bed information.
- **Workflow:** Open Room Monitoring, create a room, edit room/bed information, or remove eligible records.
- **Result:** The room directory and occupancy views update. New rooms follow the four-bed convention.
- **State:** **Working; occupied-record deletion rules need live testing.**

### Create a tenant contract

- **Input:** Tenant, contract number, dates, monthly rent, deposit, status, and notes.
- **Workflow:** Open Contracts, create a contract, and complete required onboarding items.
- **Result:** A contract record is created with requirements/signers. Activation can update tenant dates and generate billing.
- **State:** **Working; full activation must be tested in staging.**

### Send and manage onboarding invitations

- **Input:** Tenant account.
- **Workflow:** Create an invitation and give the generated link/QR to the tenant; revoke or recreate when needed.
- **Result:** The tenant can claim the invitation and submit onboarding information.
- **State:** **Working; expiry/single-use testing remains.**

### Review contract requirements and signers

- **Input:** Requirement decision, verification note, guardian requirement, or signer status.
- **Workflow:** Open the onboarding checklist, review submitted documents, and update signer verification/waiver status.
- **Result:** The checklist shows completed or missing requirements and controls whether activation can proceed.
- **State:** **Working; private-file authorization needs live testing.**

### Generate and review contract documents

- **Input:** Contract and signed document file.
- **Workflow:** Generate lease PDF, download/print it, upload signed copy, and approve/reject the signed version.
- **Result:** Versioned generated/signed documents and review status appear under the contract.
- **State:** **Working; Unicode names and Storage policies need verification.**

### Review payment proof

- **Input:** Payment record, approve/reject decision, and review note.
- **Workflow:** Open Payment Verification, inspect submitted amount/reference/receipt, and decide.
- **Result:** The tenant sees verified or rejected status; approved value affects financial summaries/balance allocation.
- **State:** **Working; financial reconciliation remains.**

### Add utility charges

- **Input:** Billing period, category, amount, notes, target residents/rooms, and allocation method.
- **Workflow:** Add one charge or build a cart containing several allocations and submit.
- **Result:** Charges and allocations are created together and become visible to affected tenants.
- **State:** **Working; rounding and rollback tests remain.**

### Override future rent

- **Input:** Contract/tenant, new rent, effective date, and reason.
- **Workflow:** Open payment management and submit the override.
- **Result:** Future rent changes with an audit record; past ledger facts are not silently rewritten.
- **State:** **Working; edge-date tests remain.**

### Process maintenance requests

- **Input:** Selected request, next status, staff note, and resolution details.
- **Workflow:** Open Maintenance Management, inspect the issue/photo, and advance it through allowed states.
- **Result:** Tenant sees the new status; staff history records the action.
- **State:** **Working.**

### Review visitor requests

- **Input:** Selected request, approve/reject action, and optional note.
- **Workflow:** Open Visitor Management and decide a pending request.
- **Result:** Tenant sees the decision and approved visitors become eligible for arrival/departure recording.
- **State:** **Working.**

### Record visitor arrival and departure

- **Input:** Approved visitor request and arrival/departure action.
- **Workflow:** Staff opens the approved request and records arrival, then later departure.
- **Result:** Request state and visitor history update with staff actor and timestamp.
- **State:** **Working.**

### Review curfew requests

- **Input:** Request, staff decision, and note.
- **Workflow:** Open Curfew Monitoring and decide a request that has reached staff review.
- **Result:** Tenant and guardian see approved/rejected status; approved active window influences ordinary curfew event classification.
- **State:** **Working; timezone and complete decision-chain tests remain.**

### Manage employee curfew profiles

- **Input:** Tenant, work schedule, weekdays, effective dates, employer/work basis, and approval action.
- **Workflow:** Create/update the profile, then approve or revoke it.
- **Result:** The tenant can see an approved profile and staff can review its event history.
- **State:** **Partial.** It does not currently alter gate classification.

### Monitor gate presence

- **Input:** Optional tenant/status filter.
- **Workflow:** Open Gate Monitoring and review each tenant's current state and event history.
- **Result:** Staff sees IN, OUT, unavailable, last event time, verification method, and status.
- **State:** **Working; Realtime deployment needs verification.**

### Record a manual gate event

- **Input:** Tenant, IN or OUT, and mandatory explanation.
- **Workflow:** Choose Staff Manual Log and submit the observation.
- **Result:** A new event is added, the tenant's current state changes, and notifications may be sent.
- **State:** **Working.**

### Simulate a crossing

- **Input:** Tenant and IN/OUT selection in diagnostics.
- **Workflow:** Use the owner geofence diagnostics/simulation control.
- **Result:** A real staff-manual gate record is created and visible in the timeline.
- **State:** **Working as a development/diagnostic tool.** Do not present it as real GPS evidence.

### Edit the dormitory boundary

- **Input:** Center, radius, buffer, polygon/circle mode, and polygon points.
- **Workflow:** Owner opens boundary settings, changes values, and taps Save & Apply.
- **Result:** Currently expected to fail unless the remote project contains a manually created function.
- **State:** **Broken/incomplete.** The required migration/RPC is missing.

### Create and publish announcements

- **Input:** Title, body, category, audience, and pinned state.
- **Workflow:** Open Announcement Management, compose the notice, select audience, and post.
- **Result:** The announcement appears on matching tenant/guardian boards.
- **State:** **Working for the board; push delivery is not connected to creation.**

### Review confidential concerns

- **Input:** Selected report, review status, and owner note/response.
- **Workflow:** Owner opens Confidential Reports, reads the concern, and records review/resolution.
- **Result:** The tenant sees the permitted updated state; review activity is audited.
- **State:** **Working; owner-only privacy needs live verification.**

### Schedule room cleaning

- **Input:** Bed/room, weekdays, assignment details, and schedule state.
- **Workflow:** Open Room Cleaning, select the bed and schedule, then save.
- **Result:** Current occupants can see their room cleaning schedule.
- **State:** **Working.**

### Process cleaning noncompliance

- **Input:** Report details and staff status/notes.
- **Workflow:** Submit or open a noncompliance report and update it through the allowed workflow.
- **Result:** The report and staff action history are retained.
- **State:** **Working; live authorization testing remains.**

### Conduct a room inspection

- **Input:** Room, schedule/notice, findings, severity, description, remediation, and optional evidence.
- **Workflow:** Create and start an inspection, add/update findings and files, then complete or cancel it.
- **Result:** Staff gets a full inspection record; affected current tenants can see permitted inspection/finding information.
- **State:** **Working; evidence Storage tests remain.**

### Manage conduct cases

- **Input:** Tenant, case category, title, description, review state, warning, or termination-review reason.
- **Workflow:** Create a draft, publish it, review tenant response, issue warnings, and update/recommend next action.
- **Result:** Tenant sees published case information; responses, warnings, evidence, and events form an audit trail.
- **State:** **Working; policy and live privacy tests remain.**

### Review conduct appeals

- **Input:** Appeal, review start, decision, and explanation.
- **Workflow:** Open an eligible appeal, begin review, and approve/reject according to the workflow.
- **Result:** Tenant sees the decision and appeal event history.
- **State:** **Working; deadline and repeat-decision tests remain.**

### Configure retention policy

- **Input:** Proposed retention days, review status, and notes.
- **Workflow:** Open Retention Settings and update a record category.
- **Result:** The proposal and audit event are saved.
- **State:** **Partial by design.** No records are actually deleted, archived, or anonymized.

### Generate reports

- **Input:** Selected report type: financial, occupancy, maintenance, curfew/gate, or executive overview.
- **Workflow:** Open Reports and Analytics, select a report, generate it, then preview/print/save.
- **Result:** A PDF is produced from the data visible to the staff account.
- **State:** **Working; figures need reconciliation before official use.**

### Call an emergency contact

- **Input:** Call button beside a contact.
- **Workflow:** Open the contact directory and tap Call.
- **Result:** Only a placeholder message appears; the phone dialer does not open.
- **State:** **Placeholder.**

## Public website and staff web workflows

### Browse the public website

- **Input:** Navigation, gallery selection, location/map controls, and external links.
- **Workflow:** Visit the website, browse property information/photos, open the map, and choose directions or staff access.
- **Result:** Public dormitory information is displayed without requiring an account.
- **State:** **Working.**

### Use the staff web portal

- **Input:** Staff credentials and normal staff workflow inputs.
- **Workflow:** Open Staff Access, sign in, and use the responsive owner/caretaker workspace.
- **Result:** Authorized staff uses the same operational data and actions as supported mobile staff screens.
- **State:** **Working; deployed-domain session and role testing remain.**

### Use the local staff preview

- **Input:** Demo role and locally entered demo records.
- **Workflow:** Launch the separate staff-preview entry point and select a role.
- **Result:** The user can explore a local interface without changing Supabase data.
- **State:** **Working as an intentional demo only.** It must not be confused with the production staff portal.

## Result summary

### Fully or substantially usable

- Authentication and role routing
- Rooms, beds, assignments, and directories
- Guardian linking and linked-resident views
- Contracts, onboarding, requirements, signers, and documents
- Billing, payments, maintenance, visitors, and ordinary curfew requests
- Gate history and staff manual logs
- Messaging and read receipts
- Announcement board
- Cleaning, inspections, conduct cases, and appeals
- Operational PDF reports
- Public website and authenticated staff workspace

### Usable but still needs live or physical-device proof

- Email/recovery delivery
- RLS and private Storage isolation
- Realtime updates
- Push notifications
- Payment reconciliation
- Contract activation/billing idempotency
- Android/iOS background geofencing
- All remote smoke-test workflows

### Incomplete or placeholder

- Boundary editing
- Announcement push-on-create
- One obsolete notification shortcut/page
- Persistent notification preferences
- Guardian personal alert scheduling
- Employee-curfew effect on gate classification
- Trusted-device binding
- Feedback submission
- Emergency-contact phone launching
- Automated retention/deletion
- Fully equivalent iOS background geofence delivery
