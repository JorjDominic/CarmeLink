# CarmeLink overall system UI and platform improvement checklist

Date: 17 October 2026.

This is the overall system UI improvement and acceptance checklist for Owner, Caretaker, Tenant and Guardian. It preserves the original Owner web feedback and adds role-specific screen inventories, shared workflows, separate web/Android/iOS requirements, and conditional desktop-runner checks. It covers navigation, forms, records, documents, payments, communication, accessibility, connectivity and platform behavior. It is a planning document; no application UI, permissions or database behavior was changed while preparing it.

**Status:** “Acceptable” records the user's feedback. Unchecked items are pending work. “Proposed merge” and cross-role recommendations require review before implementation; they are not confirmed defects or final navigation decisions. Check the current behavior before adding search, filters or pagination so existing controls are improved rather than duplicated.

## Scope and role/platform coverage

| Surface | Owner | Caretaker | Tenant | Guardian | Required treatment |
| --- | --- | --- | --- | --- | --- |
| Dedicated web portal on desktop browsers | Staff workspace | Staff workspace with existing restrictions | No tenant workspace registered | No guardian workspace registered | Improve both staff roles; validate access-denied guidance for other roles. |
| Dedicated web portal on phone/tablet browsers | Responsive staff workspace | Responsive staff workspace | Public website and sign-in guidance only | Public website and sign-in guidance only | A mobile browser is still the web portal, not the native mobile app. |
| Android app | Owner mobile shell and authorized operations | Caretaker mobile shell and authorized operations | Tenant shell and own records/actions | Guardian shell and linked records/actions | Review every applicable screen and Android-specific behavior. |
| iOS app | Owner mobile shell and authorized operations | Caretaker mobile shell and authorized operations | Tenant shell and own records/actions | Guardian shell and linked records/actions | Review every applicable screen and iOS-specific behavior independently. |
| Public website | Available without staff login | Available without staff login | Available without staff login | Available without staff login | Review landing content, navigation, contact links and authentication entry points. |
| Windows/macOS/Linux native runners | Conditional | Conditional | Conditional | Conditional | Runners exist in the repository; that alone does not establish supported production releases. Use the desktop checklist if a runner is included in delivery. |

The current dedicated web routes are `/`, `/staff` and `/reset-password`; `WebRoutes` explicitly registers no Tenant or Guardian workspace. Covering all roles does **not** authorize building new Tenant/Guardian web portals or exposing their mobile pages through staff routes. Native desktop support likewise requires an explicit delivery decision rather than assuming mobile plugins work there.

### How to use this checklist

1. Use the detailed Owner web feedback below as the original design brief.
2. Use each role's screen inventory to review the full workflow, including nested details, sheets, dialogs and empty states—not just sidebar destinations.
3. Apply the shared standards and the separate platform checklists to every applicable inventory row.
4. Track each screen/platform cell as **Pending**, **Pass**, **Needs change**, **Blocked** or **N/A with reason**. Initial inventory cells are Pending; none represents a completed test.
5. Record role, platform/device/browser, screen, relevant record state, result and evidence. A shared Dart widget does not establish Android/iOS/browser parity without checking each surface.
6. Review proposed merges and permission-sensitive additions separately; keep the current approved behavior while design choices remain unresolved.

### System-wide review areas

- [ ] Public website, welcome, login, verification, recovery, onboarding and access gates.
- [ ] All four role shells, navigation, dashboards, profiles and settings.
- [ ] Residents, accounts, guardian relationships and authorized contact discovery.
- [ ] Rooms, capacity/occupancy display, inspections, cleaning and room transfers.
- [ ] Visitors, presence, geofence presentation, curfew requests and employee exceptions.
- [ ] Maintenance, confidential concerns, conduct cases, warnings, investigations and appeals.
- [ ] Contracts, onboarding requirements, signatures, document review and renewals.
- [ ] Billing, charges, deposits, payment proof, gateway checkout, receipts and settlement.
- [ ] Analytics, financial summaries, report filters, graphs, PDFs and exports.
- [ ] Announcements, messaging, notifications, contact directory and feedback.
- [ ] Agreements, security/privacy presentation, permissions and retention configuration.
- [ ] Accessibility, responsive layout, keyboard/touch behavior, offline/retry behavior and lifecycle recovery.

## Public website and authentication

### Public web pages — desktop, tablet and phone browsers

- [ ] Review the landing hero, property/room sections, photo gallery, amenities/information, location map and inquiry/contact actions on narrow and wide screens.
- [ ] Keep room/property information clearly separate from live staff occupancy records; public imagery must not imply a guaranteed available bed or confirmed booking.
- [ ] Check navigation/menu opening, section scrolling, sticky header behavior, image loading/cropping, gallery controls and map controls without trapping page scrolling.
- [ ] Check contact/social/map links, accessible labels, unavailable-image/network states and return navigation.
- [ ] Keep staff sign-in discoverable without exposing staff records or showing admin navigation to anonymous visitors.
- [ ] Review reduced-motion behavior, large text, keyboard navigation, image descriptions and color contrast.
- [ ] Check direct staff/reset URLs, unknown routes, reload, browser back/forward and readable unavailable-service states.

### Shared authentication — all four roles on Android/iOS; staff access on web

- [ ] Splash/welcome: consistent branding, readable loading/offline states and an obvious next step without oversized decorative containers.
- [ ] Sign-in: readable email/password fields, password visibility, validation, autofill/password-manager support, loading state and duplicate-tap prevention.
- [ ] Account routing: the authenticated role reaches the correct shell; unsupported roles receive useful staff-web guidance without briefly displaying a restricted workspace.
- [ ] Email verification and recovery code entry: visible destination, paste/autofill, resend state, expired/invalid-code messaging and keyboard-safe layout.
- [ ] Forgot/reset/change password: clear steps, meaningful validation, cancel/back behavior and consistent successful completion feedback.
- [ ] Onboarding links/QR/code entry: handle valid, expired, invalid, already-used and wrong-account links with a clear recovery path.
- [ ] Tenant onboarding: organize personal, residency, school/employment and emergency-contact information into manageable sections; preserve entered data when validation fails.
- [ ] Pending/restricted Tenant access: explain requirements and allowed next actions; do not remove a legitimate access restriction just to simplify labels.
- [ ] Session expiration: preserve an understandable destination after reauthentication without exposing the previous user's data.
- [ ] Sign-out/account switching: clear cached role/record selection and return to the correct entry surface.
- [ ] Keyboard/back behavior: do not dismiss required confirmation accidentally, hide submission buttons or submit a form twice.
- [ ] Deep-link entry and app relaunch: onboarding, password recovery and notifications retain their intended authorized destination.

## Shared UI standards

- [ ] Use consistent page headers, section titles, spacing, borders, colors and action placement across management pages.
- [ ] Use short, plain-language page/header titles that remain fully visible at supported screen widths and text sizes. Avoid long words or labels that become clipped, cut off or unreadable with ellipsis; shorten the title and move supporting detail into the subtitle or page content.
- [ ] Check header width with Back/menu, notification and other action buttons present. Keep the complete title readable without overlapping controls; use an appropriate wrapping layout if a shorter title is insufficient.
- [ ] On mobile, remove a redundant Refresh page/header button where pull-to-refresh, automatic/realtime updates or another clear interaction already meets the page's needs. Keep an accessible retry/refresh action where necessary for error recovery or where no usable alternative exists.
- [ ] Use compact cards or rows for browsing. Show essential identity, status, date and primary action first; move long details into an expandable section, drawer or detail page.
- [ ] Keep primary work visible above secondary configuration. Avoid stacking several large settings panels before the list users need to manage.
- [ ] Use **five records per page** as the initial target for dense lists, including billing, presence events and reports. Display result count and clear Previous/Next controls.
- [ ] Apply search and filters to the complete authorized result set, then paginate. Reset to the first page when filters change and preserve useful state after viewing a record.
- [ ] Give each list relevant filters, a clear reset action, a no-results state and loading/error/retry states. Do not add irrelevant filters just for visual consistency.
- [ ] Support phone, tablet and desktop layouts without overflowing text or making action buttons hard to reach. Compact desktop cards must still have usable mobile touch targets.
- [ ] Reuse the approved Rooms & inspections card style as a reference after its sizes are refined; adapt the content to each module instead of forcing identical cards everywhere.
- [ ] Use consistent status badges, readable contrast, visible labels and keyboard focus. Important actions must not rely on a small icon or subtle text link alone.
- [ ] Keep merged tools reachable through clear tabs or sections. Preserve existing notification deep links, browser back/forward behavior and role permissions.
- [ ] Preserve signed contract terms, financial history, report confidentiality and existing disciplinary workflows. UI consolidation must not silently change business rules.

## Owner web app

### Workspace

| Page | Feedback | Checklist |
| --- | --- | --- |
| Dashboard | Acceptable / goods | Preserve the current layout and functionality; apply only shared consistency fixes when needed. |
| Residents | Acceptable / goods | Preserve the current main experience; consider contextual guardian-link shortcuts as described below. |
| Profile | Needs UI update | Improve layout and remove management operations from the personal profile. |
| Settings | Mostly acceptable | Match the presentation and spacing of the other updated pages. |

**Profile and Settings**

- [ ] Refresh Profile with a clearer account summary, personal details and account-related actions.
- [ ] Remove Room transfers, the Tenancy operations management section and Eviction/departure management entry points from the Owner Profile/Settings experience.
- [ ] Relocate these tools before removing their old entry points so they remain discoverable and authorized users retain access.
- [ ] Put Room transfer under **Facilities → Rooms & inspections**.
- [ ] Put Eviction/departure notice management under the chosen **Conduct & cases / Disciplinary records** destination.
- [ ] Place any remaining tenancy operations in the relevant room, resident, contract or move-out context; document the destination for each action.
- [ ] Retain personal settings, notification preferences, security and sign-out where they belong.
- [ ] Apply consistent containers and section spacing to Settings without redesigning working settings unnecessarily.

### Facilities

**Rooms & inspections**

- [ ] Disable/hide the floor-plan UI and its navigation entry points in this experience. Keep room records, assignments and inspection functionality intact.
- [ ] Improve room container dimensions, density and responsive layout; avoid oversized cards with unused space.
- [ ] Make room number, occupancy/capacity, availability and the main room action easy to scan.
- [ ] Move Room transfer here from Profile/Settings, with an obvious action or tab and existing permission checks.
- [ ] Ensure filters, room details and inspection actions remain easy to reach after the layout change.

**Cleaning schedules & reports**

- [ ] Use a compact container style consistent with the refined room cards.
- [ ] Reduce the long page and make schedules, assignments, overrides and reports easier to navigate.
- [ ] Consider tabs such as Schedule, Assignments and Reports rather than one continuous stack of large sections.
- [ ] Paginate report/history lists and keep the currently relevant schedule visible.

### Access & Safety

**Visitors**

- [ ] Improve container layout, spacing and action hierarchy.
- [ ] Make visitor identity, resident/host, visit schedule and status immediately readable.
- [ ] Review existing search, date/status filters and pagination; standardize or add only what is missing.

**Presence & Curfew**

- [ ] Keep the “How automatic crossing works” explanation **collapsed initially**.
- [ ] Make Request acknowledgement more visible through a clear label, placement and button style.
- [ ] Reduce presence event history to **five entries per page** initially.
- [ ] Improve the geofence editing UI: show the saved boundary, current edit, useful instructions and explicit Save/Cancel actions.
- [ ] Use the current device location as a convenient map starting point when no saved boundary is available, and provide a visible Use current location action while editing.
- [ ] Keep an existing saved dormitory boundary authoritative. Centering the map or obtaining a GPS fix must not silently move or save the geofence.
- [ ] Handle denied/unavailable location permission with a usable saved-location/manual-map fallback.
- [ ] Separate explanations/configuration from active requests and recent events so operational actions remain prominent.

**Employee curfew — proposed merge**

- [ ] Evaluate moving Employee curfew into **Presence & Curfew** as a tab/section.
- [ ] Improve employee profile containers and status/action presentation.
- [ ] Preserve employment-based curfew exceptions and the existing approval permissions.
- [ ] Remove the duplicate sidebar destination only after all functions and deep links have an equivalent destination.

**Conduct & Cases / Disciplinary records — proposed consolidation**

- [ ] Review the overlap between Conduct & Cases and Disciplinary records.
- [ ] Prefer a single canonical workflow with distinct Cases, Investigation, Appeals and History sections if these represent the same underlying records.
- [ ] Improve containers, text hierarchy, statuses, search, filters and pagination in the chosen destination.
- [ ] Add Eviction/departure notice management here from Profile/Settings, within its existing authorization and approval rules.
- [ ] Evaluate a shortcut or appropriate section inside Report management; avoid duplicating full case lists across two destinations.
- [ ] Keep allegations, pending investigations, confirmed violations, dismissed cases and overturned outcomes distinct. A visual merge must not equate them.

### Billing & Records

**Billing & charges**

- [ ] Overhaul the page layout and improve billing record containers.
- [ ] Reduce the space occupied by Security deposits, Automatic Payment Requests and Tenant Payment Collection.
- [ ] Move these secondary panels into compact summaries, expandable sections or clearly named tabs, as appropriate.
- [ ] Bring Billing actions and the billing record list nearer the top instead of burying them below configuration panels.
- [ ] Make charge creation, utility billing, review work and other existing actions easy to identify.
- [ ] Ensure Search billing has true pagination across the full filtered result set, targeting **five records per page** rather than an ever-growing visible list.
- [ ] Keep deposits separate from rent/utility collections in both presentation and calculations.

**Payment verification — proposed merge into Billing & charges**

- [ ] Reduce the oversized payment proof containers while keeping amount, reference, payer, date, status and review actions visible.
- [ ] Put full screenshots, OCR details and long notes in a detail view/drawer where appropriate.
- [ ] Evaluate a Payment verification tab within Billing & charges instead of a separate sidebar page.
- [ ] Preserve pending-first review, search/filters, verification/rejection reasons, concurrency protection and notification links.

**Move-out & settlement — current UI acceptable; proposed merge**

- [ ] Preserve the existing move-out/settlement UI and workflow quality.
- [ ] Evaluate a clearly labeled section within Billing & charges or a resident's tenancy details.
- [ ] Keep notices, inspection, clearance, deposit settlement and existing required approvals distinct and reachable; do not compress away necessary workflow steps.

**Report management**

- [ ] Evaluate making this the main entry point for report-related pages, with clear categories/tabs and permission-aware counts.
- [ ] Include Maintenance and Confidential reports without maintaining duplicate full sidebar destinations.
- [ ] Evaluate whether Disciplinary records belongs here or should remain part of the canonical Conduct & cases destination.
- [ ] Keep report triage, investigation decisions and reporting/export tools clearly named; similar-looking pages do not necessarily perform the same work.

**Maintenance**

- [ ] Add or improve report pagination with **five reports per page** initially.
- [ ] Disable/hide the maintenance floor-plan UI.
- [ ] Use compact report cards with category, location, submitted time, status and the main action visible.
- [ ] Evaluate allowing Owner/Caretaker report creation. First verify existing backend permissions; any new creation permission is a separate workflow/authorization decision, not just a button change.

**Confidential reports — proposed consolidation into Report management**

- [ ] Reduce oversized containers and improve summary/action placement.
- [ ] Add or improve search, relevant filters and five-record pagination.
- [ ] Reuse the existing Report management entry point and consider removing the duplicate sidebar item.
- [ ] Preserve confidential record scope, staff-only notes and authorized evidence access.

**Disciplinary records**

- [ ] Improve container sizing, typography and record descriptions/statuses.
- [ ] Add or improve search, relevant filters and five-record pagination.
- [ ] Resolve the overlap with Conduct & Cases before deciding whether to place this inside Report management.
- [ ] Preserve the existing Owner/Caretaker warning, resolution, dismissal, recommendation and appeal permissions.

**Contracts**

- [ ] Find/review an appropriate compact contract-list UI reference before changing this page.
- [ ] Reduce contract container size and improve the visibility of tenant, room, contract number, dates, rent and status.
- [ ] Keep draft, signatures, document verification, activation and renewal actions clear without placing every detail in the list card.
- [ ] Preserve access to original documents and signed/financial history.

**Income & expenses — proposed merge into Analytics**

- [ ] Move the financial summary experience into a dedicated Financial section/tab within Analytics.
- [ ] Remove the separate sidebar entry only when the replacement is equivalent and linked destinations still resolve correctly.

**Analytics**

- [ ] Include Income & expenses while distinguishing financial summaries from operational metrics.
- [ ] Add usable date ranges and relevant filters for reports, PDFs and exports where missing.
- [ ] Make on-screen totals, graphs and exports use the same selected filters/date scope, with the scope printed on exports.
- [ ] Add useful graphs for existing, reliable data; show empty/unavailable data clearly rather than fabricating trends.
- [ ] Reduce horizontally oversized export containers and organize export actions more compactly.
- [ ] Preserve correct financial totals, deposit separation and exclusion of test payments from actual collections.

### Communication

**Announcements**

- [ ] Add or improve search, audience/status/date filters and five-record pagination.
- [ ] Reduce excessive card/container space and improve title/date/audience/status presentation.
- [ ] Add or improve controls for sending/publication dates and expiration dates.
- [ ] Verify existing scheduling/expiration behavior before adding new controls; backend delivery semantics need implementation review if not already supported.

**Contact directory**

- [ ] Replace inconsistent/oversized containers with compact, consistent cards or rows.
- [ ] Add or improve search, contact-type/role filters and pagination appropriate to the authorized directory.
- [ ] Make person/office name, role, contact method and availability easy to read.
- [ ] Distinguish directory contacts from administrative account records and private messaging eligibility.

### Administration

**Accounts**

- [ ] Match the container style and spacing used by other updated management pages.
- [ ] Consider a **Grid / List** view toggle; use a compact horizontal row for List and responsive cards for Grid.
- [ ] Add or improve search, relevant role/status filters and five-record pagination.
- [ ] Clarify the note **“remove mobile on hold - tenants on”** before implementation: it may refer to mobile/on-hold UI labels or tenant account presentation. Do not remove a real account status or restriction based on this incomplete wording.
- [ ] Preserve account lifecycle rules, role restrictions and existing verification/onboarding behavior.

**Guardian links — proposed merge**

- [ ] Evaluate embedding guardian-link management in Residents or Accounts rather than a standalone sidebar page.
- [ ] Prefer a resident's detail view for viewing/changing that resident's links, with a shortcut from the related account where useful.
- [ ] Improve link containers to match account/resident styling and make relationship/primary-link status clear.
- [ ] Preserve linking authorization and prevent exposure of unrelated tenants or guardians.

**Security & retention**

- [ ] Explain in plain language what each setting controls, who can change it and whether it takes effect immediately.
- [ ] Improve section labels, descriptions and container layout so the page is understandable without implementation knowledge.
- [ ] Distinguish security settings from retention configuration and historical audit information.
- [ ] Keep automated deletion disabled unless separately approved; a UI redesign must not activate enforcement.

### Messages

- [ ] Show the contacts available to the signed-in user, or provide a prominent user search/New message action even when no conversation exists yet.
- [ ] Make it easy to find an authorized contact without requiring an existing conversation.
- [ ] Improve conversation/contact row density, role labels, unread indicators and selection state.
- [ ] Interpret “all users” as **all contacts the role is permitted to message**. Do not expose otherwise restricted account records or expand messaging permissions through search.

## Proposed navigation consolidation

These are options to evaluate, not an approved final sidebar or implementation instruction.

| Existing tool | Candidate destination | Keep distinct |
| --- | --- | --- |
| Room transfer in Profile/Settings | Rooms & inspections | Transfer approval, history and eligibility. |
| Employee curfew | Presence & Curfew tab | Employment profile/exception workflow. |
| Conduct & Cases + Disciplinary records | One canonical Conduct & cases area; Report management shortcut if useful | Investigation, appeals, confirmed outcomes and historical records. |
| Eviction/departure notices in Profile/Settings | Canonical conduct/disciplinary area | Authorized notice/termination workflow, separate from findings alone. |
| Payment verification | Billing & charges tab | Proof review actions and permission boundaries. |
| Move-out & settlement | Billing/settlement tab or resident tenancy context | Existing clearance and deposit workflow. |
| Confidential reports | Report management tab | Confidential visibility and internal notes. |
| Income & expenses | Analytics financial tab | Correct accounting totals and export scope. |
| Guardian links | Resident detail with Accounts shortcut | Relationship authorization and linked-tenant scope. |

## Related improvements for other roles

These recommendations come from the shared page structure and corresponding role pages in the repository. They are proposed review items, not claims that every issue below was reproduced visually. The current dedicated web portal serves Owner/Caretaker accounts; Tenant and Guardian items primarily concern their mobile interfaces and any supported adaptive layouts.

### Caretaker

- [ ] Apply the same compact Rooms, Visitors, Presence/Curfew, report, payment-review, account and contact components where the Caretaker already uses those shared pages.
- [ ] Carry the floor-plan visibility decision into shared Caretaker room/maintenance views so the same tool is not hidden for one staff role but unexpectedly exposed through another entry point.
- [ ] Apply the proposed Employee curfew and payment-review consolidation only to tools already authorized for this role.
- [ ] Improve Operations navigation with consistent categories, concise descriptions and visible active-work counts.
- [ ] Improve Profile/Settings using the same personal-versus-management separation as Owner, while retaining permitted management tools in their proper destinations.
- [ ] Preserve access to authorized warnings, resolution, dismissal, termination-review recommendations and appeals; UI cleanup must not make these Owner-only.
- [ ] Improve announcements, authorized message-contact search, unread indicators and compact conversation lists consistently with Owner.

### Tenant

- [ ] **Home:** keep presence, current obligations, alerts and important actions compact and readable; collapse lengthy explanations by default without hiding urgent notices.
- [ ] **Payments:** use compact bill/history cards, clear due/paid/pending status, search/filters and five-record pagination where appropriate. Keep amount due, reference, receipt and Pay/Submit proof actions easy to find.
- [ ] **Payment details/proof:** keep screenshots, OCR guidance and history in a readable detail flow; show upload progress and recoverable errors without expanding every bill card.
- [ ] **Reports:** align maintenance and concern history card styling; provide relevant category/status/date filters, search and pagination where missing. Preserve private reporting and Other/specify fields.
- [ ] **Curfew:** group requests/approvals separately from presence history and educational geofence text; collapse explanations and use compact event pagination.
- [ ] **Contracts/documents:** show document type, version, verification/signature status and primary action clearly; move long requirement lists into organized sections.
- [ ] **Conduct responses/appeals:** use a compact timeline with clear official responses, evidence and pending actions. Keep staff-only material inaccessible.
- [ ] **Cleaning/visitor tools:** review schedule/request cards, date/status filters and action visibility for consistency with staff-facing record summaries.
- [ ] **Announcements/notices:** use compact cards, publication/expiration dates and relevant filters without displaying staff-only scheduling controls.
- [ ] **Messages:** make permitted staff contacts searchable even before a conversation exists; improve empty states and unread/selection indicators.
- [ ] **Profile/Settings:** separate personal details, account settings, tenancy information and available requests; do not introduce staff administration or boundary-editing controls.

### Guardian

- [ ] **Home:** reduce tall stacked summaries, keep the selected linked resident prominent and make tenant switching consistent across detail pages.
- [ ] **Linked resident details:** use the same compact, readable room/profile containers as the resident directory, with only information this role may access.
- [ ] **Curfew/leave approvals:** place pending decisions before background explanations; distinguish Approve/Reject/Request status clearly and keep event history compact and paginated.
- [ ] **Presence information:** collapse automatic-crossing explanations initially; show latest status, observation time and unavailable/uncertain states clearly. Do not add boundary editing for Guardians.
- [ ] **Payments:** compact authorized linked-resident bill/receipt summaries with clear date/status/category filters and pagination; do not introduce payment collection or verification privileges.
- [ ] **Documents:** use consistent contract/document cards, version/status labels and visible View/Download actions within existing view-only restrictions.
- [ ] **Notices:** align announcement cards, audience relevance, dates, filters and pagination with the Tenant experience.
- [ ] **Messages:** show/search only eligible staff contacts and preserve linked-account privacy; use the same conversation components and unread conventions.
- [ ] **Profile/Settings/agreements:** organize personal preferences and linked-resident alert settings clearly; keep agreement text readable and explicit acceptance separate from routine settings.

### Shared pages and components to review together

- [ ] Profile editing, Settings, notification preferences and privacy/permissions screens.
- [ ] Notifications: consistent compact rows, unread treatment, filters/pagination where useful and clear Mark all as read feedback.
- [ ] Message contact selection, conversation lists and empty states.
- [ ] Record cards, status badges, search/filter bars, pagination controls and detail drawers.
- [ ] Contract/document viewers, upload feedback and PDF/export action placement.
- [ ] Confirmation dialogs and failure/retry messages, especially for payment, eviction, transfer and approval actions.

## Complete role and screen review inventories

These inventories group related subpages and dialogs by workflow. Every row includes list, detail, create/edit, confirmation, unavailable/empty and error states where those states exist. **Pending is review status, not a claim that the feature is missing.** Web means the dedicated staff portal; Android/iOS mean the native app. Public/authentication and shared-settings checks above/below also apply to every role.

### Owner — web, Android and iOS

Apply the original Owner web brief to the corresponding mobile tools without copying desktop card widths or sidebar layouts onto phones. Preserve the mobile Dashboard / Tenants / Operations / Profile structure unless a replacement navigation design is approved.

| ID | Screen/workflow | UI review and expected result | Web | Android | iOS |
| --- | --- | --- | --- | --- | --- |
| O01 | Role shell, Dashboard and overview metrics | Clear navigation and live summary states; web Dashboard remains acceptable per user feedback; mobile dashboard reviewed independently. | Pending | Pending | Pending |
| O02 | Residents/Tenants list and resident details | Consistent identity/room/status summaries, compact records, search/filter/pagination and contextual actions. | Pending | Pending | Pending |
| O03 | Operations hub and category pages | Mobile tools are easy to discover; web destinations and mobile categories lead to equivalent authorized workflows. | Pending | Pending | Pending |
| O04 | Profile, profile edit and Settings | Separate personal information/preferences from room transfer, eviction and management operations. | Pending | Pending | Pending |
| O05 | Rooms, room details and floor management | Compact room containers; capacity versus contractual occupancy is understandable; preserve room/floor configuration and archive/restore controls. | Pending | Pending | Pending |
| O06 | Inspections, findings, notices and detail views | Compact schedule/status summaries, clear findings and evidence, visible review actions; floor-plan removal does not remove inspections. | Pending | Pending | Pending |
| O07 | Room transfer proposal/review/history | Discoverable under Rooms; clear current/proposed assignment and approval/status feedback. | Pending | Pending | Pending |
| O08 | Cleaning rotation, assignments, overrides and noncompliance reports | Separate schedules from report history; compact lists and reachable detail actions. | Pending | Pending | Pending |
| O09 | Visitors and visit schedule editing | Consistent pending/approved/completed states, host association, dates and compact actions. | Pending | Pending | Pending |
| O10 | Presence, event details, acknowledgement and geofence editing | Collapsed explanations, visible acknowledgement, five-event pagination and safe location editing. | Pending | Pending | Pending |
| O11 | Curfew exception/late-return review and employee curfew profiles | Distinct approval/exception states; proposed merge preserves both workflows. | Pending | Pending | Pending |
| O12 | Conduct lists/details, responses, evidence, warnings, investigation and appeals | Compact case timeline, explicit decision controls and distinct confirmed/pending/overturned counts. | Pending | Pending | Pending |
| O13 | Eviction/departure notice management | Relocated from personal settings; notice, response, decision and departure states remain understandable and approval-gated. | Pending | Pending | Pending |
| O14 | Billing lists, search, charge details/actions and utility billing | Primary actions and records visible first; compact cards and true pagination; safe edit/retry feedback. | Pending | Pending | Pending |
| O15 | Security deposits, payment collection configuration and gateway requests | Compact secondary sections; preserve deposit separation and test/live labels. | Pending | Pending | Pending |
| O16 | Payment proof review, rejection and staff-received payments | Compact proof summaries, visible amount/reference/reason, private image viewing and clear save/verification state. | Pending | Pending | Pending |
| O17 | Receipt history, receipt viewing and printing | Saved transaction identity/reference, partial balance, TEST/recovery labels and suitable print/download actions. | Pending | Pending | Pending |
| O18 | Move-out, final inspection, clearance, deductions and settlement | Preserve existing good UI; readable steps, totals, evidence and outstanding approvals in any merged destination. | Pending | Pending | Pending |
| O19 | Report management and maintenance detail/status/history | Five-report pagination, compact work orders, no staff floor-plan dependency and clear visibility boundaries. | Pending | Pending | Pending |
| O20 | Confidential concerns and report history | Compact summaries, complete search/filter results and protected private/internal content. | Pending | Pending | Pending |
| O21 | Contracts, contract editor, roommate/occupancy selection and renewals | Compact summaries; exact rent/occupancy terms and unambiguous next step. | Pending | Pending | Pending |
| O22 | Onboarding invitation/QR, requirement checklist, signatures and document verification | Manageable sections, readable document versions, clear upload/review/signing states and original-document access. | Pending | Pending | Pending |
| O23 | Income/expenses, Analytics, graphs, report filters and exports | Consolidated financial view with matching date/filter scope; compact export controls and correct totals. | Pending | Pending | Pending |
| O24 | Announcements, scheduling and expiration | Compact audience/date/status summaries; preview and publication/expiration controls match actual backend behavior. | Pending | Pending | Pending |
| O25 | Contact directory, Messages, recipient search and conversations | Search permitted contacts before a conversation exists; compact rows and consistent unread/action states. | Pending | Pending | Pending |
| O26 | Accounts, account editing/onboarding status and guardian links | Compact Grid/List choices, meaningful filters and paginated authorized results; explain ambiguous status wording before changing it. | Pending | Pending | Pending |
| O27 | Dormitory configuration and dynamic choices | Grouped configuration, visible active/archived status and safe add/rename/archive/restore feedback. | Pending | Pending | Pending |
| O28 | Agreement publication/history/acceptance review | Distinguish draft inputs, approved immutable publication and acceptance history; never seed placeholder wording through UI work. | Pending | Pending | Pending |
| O29 | Security/retention and audit information | Plain-language descriptions, clear scope and no silent activation of automated deletion. | Pending | Pending | Pending |
| O30 | Notifications, preferences, feedback and dormitory information | Shared controls remain consistent and reachable; record links preserve their target after navigation consolidation. | Pending | Pending | Pending |

**Owner native-mobile checklist**

- [ ] Replace large desktop dialog layouts with keyboard-safe sheets/full-screen forms where appropriate.
- [ ] Make room, case and payment primary actions reachable without scrolling past large configuration panels.
- [ ] Adapt Grid/List selection to phone width without losing search/filter state or hiding crucial room/financial information.
- [ ] Keep signatures, evidence upload, contract review and financial confirmations usable with touch and large text.
- [ ] Ensure moving actions out of Profile does not strand mobile-only management tools in a web-only destination.

### Caretaker — web, Android and iOS

Review every shared staff module independently with a Caretaker account. A shared component does not imply the same actions or data scope as Owner. Owner-only configuration, contract/financial administration and agreement publication must remain restricted according to current backend rules.

| ID | Screen/workflow | UI review and expected result | Web | Android | iOS |
| --- | --- | --- | --- | --- | --- |
| C01 | Staff shell, Dashboard, Tenants/Residents and resident details | Same visual quality as Owner, with the correct Caretaker navigation and available actions. | Pending | Pending | Pending |
| C02 | Operations hub/categories | All permitted mobile tools remain discoverable after shared navigation consolidation. | Pending | Pending | Pending |
| C03 | Profile/edit/Settings | Personal settings separated from authorized management actions; consistent compact layout. | Pending | Pending | Pending |
| C04 | Rooms, occupancy and room-detail tools | Compact room cards and approved actions; no unauthorized structural-capacity changes exposed. | Pending | Pending | Pending |
| C05 | Inspections/findings, cleaning schedules and report details | Compact schedule/list/detail views and visible permitted review actions. | Pending | Pending | Pending |
| C06 | Room transfer and tenancy-operation entry points | Relocation preserves only existing authorized review/actions; denied operations have understandable feedback. | Pending | Pending | Pending |
| C07 | Visitors and schedule review | Host/date/status readable; search/filter/pagination equivalent to the applicable Owner tools. | Pending | Pending | Pending |
| C08 | Presence, event history and acknowledgement | Collapsed explanations, five-event pages and a visible acknowledgement action. | Pending | Pending | Pending |
| C09 | Curfew request review and employee profiles | Combined navigation if approved, without changing approval rules or employee exceptions. | Pending | Pending | Pending |
| C10 | Conduct/case lists and detail timelines | Clear reports, tenant explanations, internal/official responses, evidence and case state. | Pending | Pending | Pending |
| C11 | Warnings, dismissal/resolution, termination-review recommendations and appeals | Existing Caretaker disciplinary actions remain available; do not replace them with Owner-only controls. | Pending | Pending | Pending |
| C12 | Eviction/departure and move-out/settlement access | Correct placement and role-scoped controls; no new legal or financial decision authority. | Pending | Pending | Pending |
| C13 | Billing access and payment proof review | Compact records/proofs, visible pending actions and rejection reasons; Owner-only charge/configuration actions stay restricted. | Pending | Pending | Pending |
| C14 | Authorized staff-received payments and receipt history | Compact evidence/amount entry, clear saved/uncertain state and existing receipt permissions. | Pending | Pending | Pending |
| C15 | Report management and maintenance status/history | Compact five-report pages, clear responsibility/status and visible permitted actions. | Pending | Pending | Pending |
| C16 | Confidential-report destinations and protected notes | Show only currently authorized data; hide/deny restricted content rather than assuming all staff permissions match. | Pending | Pending | Pending |
| C17 | Announcements and contact directory | Shared compact cards, filters and publication controls limited to current permissions. | Pending | Pending | Pending |
| C18 | Accounts, recipient search and Messages | Show permitted accounts/contacts, Grid/List if applicable, pagination and useful empty states. | Pending | Pending | Pending |
| C19 | Security/retention, Notifications, preferences and Feedback | Consistent explanations and authorized settings; no automatic deletion enabled. | Pending | Pending | Pending |
| C20 | Restricted destinations and direct links | Verify Owner-only screens/actions stay protected even when opened by a stale link or typed URL; no brief data exposure. | Pending | Pending | Pending |

**Caretaker parity checklist**

- [ ] Apply shared card/pagination fixes to both staff roles instead of branching into inconsistent duplicate layouts.
- [ ] Test mobile Operations destinations as well as the dedicated web sidebar; a tool hidden in one entry point must not accidentally become broadly available elsewhere.
- [ ] Use explanatory unavailable/permission states without exposing internal authorization errors or confidential record content.
- [ ] Preserve draft input and current record selection after refresh, rejected save and return from an authorized detail screen.

### Tenant — Android and iOS; web boundary checks

The dedicated web portal has no Tenant workspace. Every mobile workflow below must be reviewed separately on Android and iOS. The web column records the required boundary check rather than authorizing a new browser implementation.

| ID | Screen/workflow | UI review and expected result | Android | iOS | Dedicated web |
| --- | --- | --- | --- | --- | --- |
| T01 | Welcome/login/verification/recovery | Consistent entry, keyboard-safe validation, session restore and correct role routing. | Pending | Pending | Public/auth guidance; no workspace. |
| T02 | Access gate, onboarding form and onboarding-link/code entry | Clear missing requirements and next actions; readable progress and preserved input. | Pending | Pending | Verify no staff access. |
| T03 | Home/dashboard and quick actions | Compact current presence, obligations, alerts and room information; urgent actions remain prominent. | Pending | Pending | No registered workspace. |
| T04 | My room and occupancy information | Readable assigned room/bed, occupancy arrangement and resident-visible details; no edit or transfer authority added. | Pending | Pending | No registered workspace. |
| T05 | Existing room/floor-plan view | Review discoverability/readability and agree whether staff-only floor-plan removal also applies here; retain room information if a view is retired. | Pending | Pending | No registered workspace. |
| T06 | Cleaning assignment/schedule and own report context | Compact schedule, dates/status, visible assigned duties and authorized detail/history. | Pending | Pending | No registered workspace. |
| T07 | Room inspection notices/findings | Readable notice, timing, findings and permitted acknowledgement/detail actions. | Pending | Pending | No registered workspace. |
| T08 | Payments list and bill details | Compact due/paid/pending records, dates, complete search/filter results and appropriate pagination. | Pending | Pending | No registered workspace. |
| T09 | Manual proof upload and OCR-assisted guidance | Clear amount/method/reference, preview, validation and upload/retry state; OCR does not imply payment approval. | Pending | Pending | No registered workspace. |
| T10 | PayMongo checkout and payment-session recovery | Clear test/live/pending/failed state, safe app switching and server-confirmed completion; no duplicate charge on retry. | Pending | Pending | No registered workspace. |
| T11 | Receipt history, receipt detail, deposits and settlement information | Correct original reference/balance, TEST/recovery labels and only authorized own financial records/actions. | Pending | Pending | No registered workspace. |
| T12 | Reports hub, maintenance list/create/edit/detail and photo preview | Compact records, active choices, Other/specify, timestamps, usable photo flow and five-record history pages. | Pending | Pending | No registered workspace. |
| T13 | Confidential concern submission/history and addenda | Clear private reporting context and permitted status/history; no staff/internal notes leak. | Pending | Pending | No registered workspace. |
| T14 | Curfew/presence and event history | Collapse explanations initially; show current/uncertain status, times and compact five-event history. | Pending | Pending | No registered workspace. |
| T15 | Curfew exception/late-return requests and employee-related information where exposed | Clear date/time/reason, approval progress and allowed next actions; no change to exceptions or confirmation rules. | Pending | Pending | No registered workspace. |
| T16 | Visitor requests and schedule editor | Compact request list, readable host/visit dates and clear cancellation/approval status. | Pending | Pending | No registered workspace. |
| T17 | Conduct list/details, official responses, own explanation and appeal | Distinguish allegations/outcomes; readable evidence/timeline and eligibility-aware responses/appeals. | Pending | Pending | No registered workspace. |
| T18 | Contract requirements, document previews and signature pad | Clear versions, required versus optional items, signature/verification progress and readable lease content. | Pending | Pending | No registered workspace. |
| T19 | Move-out/departure notices and permitted tenancy requests | Review existing own-request/response surfaces wherever exposed; no new refund, transfer or departure policy inferred. | Pending | Pending | No registered workspace. |
| T20 | Announcements, Rules & policies and dormitory information | Compact notices, relevant dates/filters, readable long content and useful empty/offline states. | Pending | Pending | Public information only. |
| T21 | Messages, contact selection and conversation detail | Find permitted staff before a conversation exists; clear unread state, compose actions and failure feedback. | Pending | Pending | No registered workspace. |
| T22 | Profile/edit, Settings, privacy and notification preferences | Personal, tenancy and preference sections clearly separated; no staff management or boundary editing exposed. | Pending | Pending | Recovery/access guidance only. |
| T23 | Notifications/detail, Feedback and agreement review/acceptance | Correct own-record links, readable form/text, explicit acceptance and clear unavailable states. | Pending | Pending | Verify protected routes denied. |

- [ ] Confirm the Reports and Curfew tabs are usable even if a destination carries a work-in-progress label; do not infer production completeness or remove a real access gate based on the label alone.
- [ ] Check payments, requirement checklists and long policies with the keyboard open and larger text enabled.
- [ ] Keep draft report/proof/explanation text through recoverable errors and clearly explain uncertain save outcomes before users resubmit.
- [ ] After changing account, verify room, receipt, contract, concern and message caches cannot show the previous Tenant's records.

### Guardian — Android and iOS; web boundary checks

The dedicated web portal has no Guardian workspace. Linked-tenant scope is part of every applicable row, not just the tenant selector.

| ID | Screen/workflow | UI review and expected result | Android | iOS | Dedicated web |
| --- | --- | --- | --- | --- | --- |
| G01 | Login/verification/recovery and session entry | Consistent forms, keyboard-safe validation and correct Guardian routing. | Pending | Pending | Public/auth guidance; no workspace. |
| G02 | Home/dashboard and linked-tenant selector | Compact summaries; clear selected resident; no-link, one-link and multiple-link states. | Pending | Pending | Verify no staff access. |
| G03 | Linked resident details, room/bed and authorized contact information | Consistent profile/room containers and clear relationship; no unrelated resident visibility. | Pending | Pending | No registered workspace. |
| G04 | Curfew/leave approvals and request details | Pending decisions first, visible Approve/Reject actions, schedule/reason and clear completed state. | Pending | Pending | No registered workspace. |
| G05 | Presence monitoring, activity history and automatic-crossing explanation | Explanation collapsed initially; readable latest status/time, unavailable state and compact paginated events. | Pending | Pending | No registered workspace. |
| G06 | Presence-alert schedule/preferences and status-update request | Clarify chosen tenant, time, alert conditions and request delivery/response state; no geofence editing. | Pending | Pending | No registered workspace. |
| G07 | Linked-resident payment status, bill detail and authorized receipts | Compact own-linked summaries, relevant filters/dates and readable balances; no staff verification or collection controls. | Pending | Pending | No registered workspace. |
| G08 | Documents, contract previews and permitted requirement information | Clear resident/version/status and view/download actions; maintain existing view-only and data restrictions. | Pending | Pending | No registered workspace. |
| G09 | Notices/announcements | Compact audience-relevant records, dates, expiration indicators and relevant filters/pagination. | Pending | Pending | Public information only. |
| G10 | Messages, staff-contact selection and conversations | Search permitted staff, distinguish active conversation/resident context and show failures/unread state consistently. | Pending | Pending | No registered workspace. |
| G11 | Emergency/safety information and contacts | Readable names/numbers, platform-appropriate contact actions and clear source/availability; no fabricated live status. | Pending | Pending | Public contacts only if present. |
| G12 | Notifications and record-detail links | Open only the intended authorized linked record; handle unlinked/deleted/inaccessible records clearly. | Pending | Pending | Verify protected routes denied. |
| G13 | Profile/edit, Settings, privacy, password and notification preferences | Personal settings separated from per-resident alert settings; maintain selection consistently. | Pending | Pending | Recovery/access guidance only. |
| G14 | Confidentiality agreements and own acceptance history | Readable full approved text, explicit review/acceptance and immutable own-user/version records. | Pending | Pending | No registered workspace. |
| G15 | Feedback, dormitory information and shared account/help surfaces | Consistent compact forms and navigation; no unauthorized tenant/staff operations. | Pending | Pending | Public information only where available. |

- [ ] Switch the linked resident while payment, curfew, document and notification requests are loading; stale results must not be presented as belonging to the new selection.
- [ ] Review no-linked-resident states without showing a blank screen, irrelevant approval controls or sample financial data.
- [ ] Check long approval descriptions and agreement text with large text and screen readers; important decision buttons remain available.
- [ ] Do not add Guardian access to confidential concerns, internal staff case notes or other restricted evidence through a combined report UI.

## Shared screens, forms and components — all applicable roles

| Area | UI improvements and verification checklist |
| --- | --- |
| Profile and editing | [ ] Consistent identity/role labels, personal versus tenancy sections, validation, save/cancel feedback and protection against double saves. |
| Settings and preferences | [ ] Group appearance, notifications, privacy, security and help clearly; show current values and explain unavailable platform controls. |
| Change password and recovery | [ ] Consistent validation/visibility controls, expired session handling, autofill and keyboard-safe actions. |
| Notification center/detail | [ ] Compact rows, unread counter/Mark all as read feedback, filters/pagination where useful, correct record targets and accessible expired/inaccessible states. |
| Feedback | [ ] Clear category, required description, submit/confirmation state and preserved input on failure. |
| Dormitory information and policies | [ ] Readable long content, accurate labels, searchable/navigation structure where useful and consistent back behavior. |
| Agreements | [ ] Full text, audience/version/date, explicit acceptance, previous acceptance visibility and no placeholder or unintended mandatory gate. |
| Contact picker and conversation list | [ ] Search all permitted contacts, useful empty states, compact identity/role rows and correct unread/active selection. |
| Conversation thread | [ ] Bounded scrolling, readable timestamps, keyboard-safe composer, send/retry feedback and no duplicate messages after reconnection. |
| Search/filter/pagination bar | [ ] Entire authorized dataset filtered before paging, clear active filters/reset/count, five-item default for dense records and stable return state. |
| Record cards/details | [ ] Consistent hierarchy/status/actions, compact summaries, readable expansion and enough detail to avoid confusing two records. |
| Upload/image preview | [ ] Camera/gallery/file choice where supported, format/size validation, preview/progress/cancel and retention after uncertain committed saves. |
| PDF/document viewer | [ ] Loading/error state, zoom/scroll, document/version identity, platform export controls and accessible original-file access. |
| Signature pad | [ ] Clear signer/document context, touch/scroll separation, Reset/Cancel/Confirm, orientation handling and visible save state. |
| Review/administrative dialogs | [ ] Meaningful reason fields, current record/version context, safe cancellation, visible confirmation and readable stale-data rejection. |
| Date/time/schedule controls | [ ] Consistent displayed timezone, valid ranges, publication/expiry distinction and clear cross-midnight schedules. |
| Status and totals | [ ] Consistent terminology, no confirmed outcome inferred from a report, distinct unavailable/stale states and no hidden financial recalculation. |
| Realtime refresh | [ ] Keep selected record/filter/page and unsaved input where possible; notify users about relevant changes instead of unexpectedly moving them. |

## Web-specific checklist

Apply separately to **Owner web**, **Caretaker web**, the **public website**, and **Tenant/Guardian boundary behavior**. Include desktop, tablet and phone browsers; native Android/iOS checks do not substitute for mobile-browser checks.

- [ ] Test available supported browsers, including Chromium-based browsers and Safari/Firefox where part of delivery; record actual browser/version results rather than assuming compatibility.
- [ ] Check wide desktop, narrow desktop, tablet portrait/landscape and phone browser widths; no document-wide horizontal overflow from tables, cards, dialogs or toolbars.
- [ ] Keep the staff sidebar/groups, collapsed navigation, page titles, breadcrumbs/back actions and current selection consistent after consolidation.
- [ ] Preserve direct record links, browser back/forward, reload, reset-password entry and unauthorized/unknown-route handling.
- [ ] Use keyboard-accessible tabs, menus, pagination, dialogs, filters and grids; provide visible focus and a sensible tab order.
- [ ] Keep search/filter/table headers usable at narrow widths; do not hide the only route to an essential action in an unlabeled icon menu.
- [ ] Keep hover feedback optional; controls work with touch as well as a mouse, including mobile Safari/browser keyboards.
- [ ] Check browser file selection, drag/drop only if supported, cancel/reselect, image/PDF preview, format/size errors and interrupted uploads.
- [ ] Verify download/print previews, popup handling and export filenames; displayed/exported dates, filters, totals and TEST labels match.
- [ ] Check zoom, text scaling, dark mode, reduced motion, screen-reader labels and long translated/user-entered text.
- [ ] Handle denied/unavailable browser geolocation with saved boundary/manual controls. Request location only in a relevant authorized workflow and never silently replace the dormitory boundary.
- [ ] Clearly communicate any browser limitation on background presence or notifications; do not promise native background monitoring in a normal browser tab.
- [ ] On tab switching, reconnection and session expiration, preserve a clear state without stale account information or repeated writes.
- [ ] Ensure Tenant/Guardian sign-in cannot reveal staff navigation/records and offers the intended mobile-app guidance instead of an empty staff page.
- [ ] Verify production website content and protected routes remain separate from local/demo/preview surfaces and developer tools.

## Android-specific checklist — each of the four roles

- [ ] Use short, fully readable header titles on phones, including with larger text and header actions; no cut-off words or hidden essential title text.
- [ ] Review each Refresh page/header button and remove it if redundant. Verify the remaining refresh gesture/automatic updates and failure-retry controls still work and remain discoverable.
- [ ] Review navigation with the system Back button/gesture, app bar Back, bottom navigation, drawers and nested detail screens; avoid unexpected app exits or lost drafts.
- [ ] Check phones/tablets, portrait/landscape where allowed, cutouts/system bars, gesture-navigation insets, split-screen if supported and large text/display scaling.
- [ ] Keep forms/composers and bottom-sheet actions visible with the keyboard; verify email/numeric/date input, autofill, password managers, paste and keyboard Next/Done actions.
- [ ] Check camera/gallery/file picker, selection cancellation, limited/denied media access, large/unsupported files and image rotation/preview.
- [ ] Make notification permission and location permission explanations actionable and consistent with actual OS settings; a declined permission must leave a useful app state.
- [ ] For the appropriate Tenant monitoring flow, distinguish foreground/background location, disabled GPS, unavailable/approximate location, battery/background restrictions and stopped monitoring. Do not display stale location as confirmed current presence.
- [ ] For Owner/Caretaker map editing, use an explicit current-location action and saved boundary context; do not start or expose Tenant monitoring controls simply because the page contains a map.
- [ ] Check foreground/background/terminated notification entry, selected-role routing, unread counts and record-specific deep links. Guard inaccessible records after an account switch.
- [ ] Verify app background/resume, process recreation, reboot-related monitoring behavior where configured and offline event recovery using physical-device evidence.
- [ ] Check gateway navigation/app switching/cancellation, app closure before confirmation and reopened payment/receipt state. UI confirmation must follow server verification.
- [ ] Check document downloads, PDF viewers, print/share sheets and reopening the original saved document; preserve the TEST designation.
- [ ] Review loading/progress, duplicate taps, network loss during save, failed upload recovery and reconnect behavior for all role-specific forms.
- [ ] Review the oldest/newest Android versions and device types included in the actual release support range; derive requirements from the project/release configuration rather than inventing a version guarantee.
- [ ] Test a release build, including native permissions, registered links, notification icon/channel and correct distribution signing; debug/emulator results alone do not complete this checklist.

## iOS-specific checklist — each of the four roles

- [ ] Use short, fully readable navigation/header titles on iPhone/iPad, including with larger text, Back navigation and action buttons; no cut-off words or hidden essential title text.
- [ ] Review each Refresh page/header button and remove it if redundant. Preserve usable pull-to-refresh/automatic updates and an accessible retry action where necessary.
- [ ] Review iPhone/iPad layouts, safe areas/notches, home indicator, supported orientation and large Dynamic Type/text settings without clipping actions.
- [ ] Check navigation push/pop, back gesture, modal dismissal and unsaved-form confirmation. Do not assume Android Back behavior applies.
- [ ] Keep forms, signature sheets and message composers clear of the keyboard; verify autofill/password managers, paste/code entry and appropriate input keyboards.
- [ ] Review camera, photo-library limited access, file picker, cancelled selection, repeated selection and permission changes in system Settings.
- [ ] Provide meaningful explanations and useful denied/unavailable states for notifications and location; do not assume a first permission prompt will recur automatically.
- [ ] For authorized Tenant monitoring, check When in Use/Always availability, reduced location accuracy, disabled services and background/relaunch limits using the actual iOS implementation.
- [ ] For staff geofence editing, keep device location separate from saved boundary changes and provide manual/saved-location fallback.
- [ ] Verify notification routing with actual APNs/FCM configuration for foreground/background/terminated entry and correct current account/record access.
- [ ] Check app backgrounding, suspension, force closure and reopening independently; document platform limitations instead of promising continuous monitoring unsupported by evidence.
- [ ] Check sandbox payment checkout/app switching/cancellation and callback/reconciliation after reopening; retain committed evidence and correct receipts on interrupted replies.
- [ ] Review PDF preview, Files export, share/print sheets, document naming and accessible original contract/receipt access.
- [ ] Check VoiceOver labels/focus, contrast, larger text, Reduce Motion and touch targets across all role workflows.
- [ ] Verify cold-start onboarding/password-recovery/notification links and wrong-account links without routing through an unauthorized shell.
- [ ] Validate the actual iOS support range, signing/provisioning, privacy strings, background modes and signed distribution notification entitlement on macOS/Xcode.
- [ ] Complete physical iPhone/iPad and distribution/TestFlight checks where part of release. Flutter widget tests and Windows source review do not establish iOS runtime acceptance.

## Windows, macOS and Linux native runners — conditional coverage

These runner folders are included in the system inventory. Do not label their apps release-supported until build/plugin/runtime acceptance is explicitly completed. If desktop-native delivery is not approved, record **N/A — runner present, not a delivery target**, separately for each OS; web use on those operating systems remains covered by the web checklist.

| Native target | Role shells/screens to review if enabled | Platform concerns | Initial status |
| --- | --- | --- | --- |
| Windows | Owner, Caretaker, Tenant and Guardian inventory rows allowed by actual routing/guards | Window sizing, DPI/scaling, mouse/keyboard, file dialogs, PDF/print, links and unavailable mobile-only plugins. | Conditional / not verified. |
| macOS | Owner, Caretaker, Tenant and Guardian inventory rows allowed by actual routing/guards | Resizable windows, menu/keyboard conventions, file/photo permissions, signing/entitlements, links and print/share behavior. | Conditional / not verified. |
| Linux | Owner, Caretaker, Tenant and Guardian inventory rows allowed by actual routing/guards | Resizing, desktop scaling, system dialogs, external viewer/printer dependencies and plugin availability. | Conditional / not verified. |

- [ ] Review native plugin support before exposing OCR, camera, notifications, background location, deep links or gateway flows on a desktop runner.
- [ ] Provide an understandable unavailable state or authorized alternative for unsupported native capabilities; do not crash or bypass security checks.
- [ ] Run the relevant role inventory, shared component checklist, connectivity/recovery and accessibility checks independently for each delivered desktop OS.
- [ ] Treat macOS native app support separately from Safari support, and Windows native app support separately from the browser portal.

## Cross-role and cross-platform workflow checks

Run only with authorized disposable test accounts/data. These are acceptance targets for future implementation, not tests already completed by this documentation task.

| Workflow | Roles/surfaces to compare | Expected UI result |
| --- | --- | --- |
| Account creation/invitation → verification → onboarding → access | Authorized staff web/mobile; Tenant/Guardian mobile entry | Clear progress and requirements; correct role routing and no duplicate records or bypassed access gate. |
| Room/contract preparation → signatures → verification → activation | Owner web/Android/iOS; Tenant mobile; Guardian authorized view | Room/bed, approved rent, document versions and next action agree; no hidden repricing or assignment changes. |
| Room transfer → review → updated assignment | Authorized staff surfaces and affected Tenant/Guardian views | Same approved assignment/status everywhere, traceable history and understandable pending/denied states. |
| Bill → manual proof → review → receipt | Tenant mobile; authorized Owner/Caretaker web/mobile; Guardian permitted view | Correct amount/reference/status, compact readable records and safe rejection/retry recovery. |
| Bill → gateway checkout → confirmation after app closure | Tenant Android/iOS; staff web/mobile; authorized linked view | Server-confirmed state and one canonical receipt; no invented success from client navigation alone. |
| Maintenance/concern → triage → response/status → history | Tenant mobile and authorized staff surfaces | Matching dates/categories/status; confidential/internal content remains scoped through every detail/export path. |
| Conduct report → explanation → warning/investigation → appeal | Owner/Caretaker authorized surfaces; Tenant mobile | Status/timeline/eligible actions agree without counting all complaints as confirmed violations. |
| Visitor or curfew request → linked approval → staff outcome | Tenant/Guardian mobile and authorized staff surfaces | Clear pending/approved/rejected/expired states and useful role-specific notifications. |
| Presence event → acknowledgement/status request → response | Tenant mobile monitoring; Guardian mobile; staff web/mobile | Timestamp/source/current-versus-unavailable state clear; no disciplinary confirmation from unreliable events. |
| Cleaning schedule → assigned duty → report/inspection | Staff web/mobile and Tenant mobile | Same current assignment/date; compact history and authorized report visibility. |
| Move-out/departure → clearance → deposit settlement | Authorized staff surfaces and permitted resident-linked views | Required steps and totals remain visible; no invented departure penalty or automatic policy change. |
| Announcement publication/expiry → notice → notification | Staff web/mobile and intended Tenant/Guardian mobile audiences | Correct audience, readable dates/status and no stale or duplicate delivery claims. |
| Message initiation → conversation → unread/read state | All permitted role pairs across delivered platforms | Recipient discovery works before a conversation exists; role scope and unread counts stay consistent. |
| Analytics date/filter → graph → export/print | Authorized staff platforms | Same scope and amounts on screen/PDF; responsive exports and readable labels/TEST separation. |
| Agreement publication → audience review → explicit acceptance | Owner administration; Tenant/Guardian mobile | Correct approved version/audience and own-user acceptance; historical text/acceptance unchanged. |
| Logout/login as another role or resident selection switch | All delivered role/platform combinations | No stale cards, attachments, totals, drafts or notifications from the previous account/selection. |

## Accessibility, reliability and system states

- [ ] Check light/dark themes, contrast, focus, labels, touch targets, screen readers, text scaling and reduced motion on every delivered surface.
- [ ] Check long resident names, room labels, references, notes and documents; do not truncate the only information distinguishing two records.
- [ ] Check zero records, one record, multiple pages, archived options, missing attachments and inaccessible/deleted linked records.
- [ ] Check first load, refresh, pagination loading, partial/stale data, server rejection, session expiry and retry without dumping raw database exceptions into normal page content.
- [ ] Check offline entry and connection loss before upload, during upload, after a committed save and before receiving confirmation. Explain uncertain outcomes without deleting saved evidence or encouraging duplicate payments.
- [ ] Check pending writes during navigation, app lifecycle changes, browser tab switching and role/resident switching.
- [ ] Check simultaneous staff changes: indicate stale/conflicting data and refresh/retry safely while preserving protected history.
- [ ] Check displayed dates/times and export scope consistently with the intended property timezone, including cross-midnight and year-boundary records.
- [ ] Check slow or unavailable image, map, OCR, PDF, notification and gateway dependencies without blocking unrelated navigation.
- [ ] Check privacy for list, search, detail, media preview, export, deep link and error states—not only whether a sidebar item is hidden.

## Review tracking and evidence

Use one entry per inventory row and platform. Clone the template as needed; do not replace pending manual/device evidence with a single shared-widget test result.

| Inventory ID | Role | Platform/browser/device | Screen/record state | Status | Change needed / expected behavior | Evidence | Reviewer/date |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Example: O14 | Owner | Web / actual browser and viewport | Billing list, filtered page 2 | Pending | Five-row pagination and visible billing actions | Not captured | Not reviewed |
| Example: T09 | Tenant | Android / actual device | Interrupted proof submission | Pending | Clear uncertain-save state; evidence retained | Not captured | Not reviewed |
| Example: G04 | Guardian | iOS / actual device | Pending linked-resident approval | Pending | Visible decision actions and readable reason | Not captured | Not reviewed |

Required completion evidence for each applicable row:

- [ ] Before/after UI captures or a recorded explanation where an existing screen needs no change.
- [ ] Search/filter/pagination and list/detail navigation behavior with enough authorized data to exercise the controls.
- [ ] Narrow/wide layout and appropriate keyboard/touch/accessibility checks.
- [ ] Relevant success, empty, denied, error and recovery states.
- [ ] Role/record scope and deep-link behavior after any move or merge.
- [ ] Platform-specific evidence from the actual browser/device/runtime, or an explicit blocker/N/A reason.

## Implementation references

| Area | Existing source locations |
| --- | --- |
| Staff web navigation and shared role destinations | `lib/web/dashboard/staff_web_portal_shell.dart` |
| Profile, Settings and personal preferences | `lib/views/shared/shared_views.dart`, `lib/views/shared/profile_edit_page.dart` |
| Room cards and occupancy | `lib/views/owner/room_monitoring_page.dart`, `lib/views/owner/room_occupancy_widgets.dart` |
| Transfer, eviction and move-out | `lib/views/shared/room_transfer_page.dart`, `lib/views/shared/eviction_page.dart`, `lib/views/shared/move_out_settlement_page.dart` |
| Cleaning schedules/reports | `lib/views/shared/cleaning_schedule_management_page.dart`, `lib/views/shared/room_cleaning_pages.dart` |
| Billing and collection settings | `lib/views/owner/billing_management_page.dart`, `lib/views/owner/payment_collection_settings_card.dart` |
| Presence, visitors, report hub, confidential reports, announcements, messaging, contacts and analytics | Corresponding page classes in `lib/views/owner/owner_pages.dart` |
| Maintenance | `lib/views/owner/staff_maintenance_page.dart` |
| Conduct and employee curfew | `lib/views/shared/conduct_case_pages.dart`, `lib/views/shared/employee_curfew_profile_pages.dart` |
| Contracts | `lib/views/owner/contracts_page.dart` |
| Accounts and guardian links | `lib/views/shared/account_management_page.dart`, `lib/views/owner/guardian_link_management_page.dart` |
| Security/retention | `lib/views/shared/retention_settings_page.dart` and related shared settings pages |
| Caretaker navigation | `lib/views/caretaker/caretaker_shell.dart` and reused staff/shared pages |
| Tenant navigation and pages | `lib/views/tenant/tenant_shell.dart`, `lib/views/tenant/tenant_pages.dart`, `lib/views/tenant/tenant_requirements_page.dart` |
| Guardian navigation and pages | `lib/views/guardian/guardian_shell.dart`, `lib/views/guardian/guardian_pages.dart`, `lib/views/guardian/guardian_documents_page.dart` |
| Mobile bootstrap, links and role routing | `lib/main.dart`, `lib/app.dart`, `lib/core/widgets/adaptive_shell.dart`, `lib/core/widgets/role_guard.dart` |
| Dedicated web entry, public/staff/recovery routes and access guard | `lib/main_web.dart`, `lib/web/app/carmelink_web_app.dart`, `lib/web/app/web_routes.dart`, `lib/web/auth/staff_gate.dart` |
| Public site and staff sign-in | `lib/web/landing/landing_page.dart`, `lib/web/auth/staff_access_page.dart` |
| Welcome/login, verification and recovery | `lib/views/auth/auth_views.dart`, `lib/views/auth/mobile_auth_entry.dart` |
| Tenant onboarding/access and staff invitations | `lib/views/tenant/onboarding_form_page.dart`, `lib/views/tenant/tenant_access_gate.dart`, `lib/views/owner/onboarding_invitation_page.dart` |
| Contract requirements, document preview and signatures | `lib/views/owner/contract_onboarding_checklist_page.dart`, `lib/views/tenant/tenant_requirements_page.dart`, `lib/views/shared/signature_pad_dialog.dart` |
| Staff curfew requests and inspection details | `lib/views/shared/staff_curfew_requests_page.dart`, `lib/views/shared/room_inspection_pages.dart` |
| Deposits, gateway checkout/session history and receipts | `lib/views/shared/staff_security_deposits_section.dart`, `lib/views/shared/paymongo_payment_page.dart`, `lib/views/shared/paymongo_sessions_section.dart`, `lib/views/shared/payment_receipt_history.dart` |
| Private concerns, case responses/investigation/appeals and agreements | `lib/views/shared/confidential_report_history.dart`, `lib/views/shared/conduct_official_responses.dart`, `lib/views/shared/conduct_investigation_panel.dart`, `lib/views/shared/conduct_case_appeal_panel.dart`, `lib/views/shared/confidentiality_agreements_page.dart` |
| Notifications, record links and staff contact discovery | `lib/views/shared/notification_destination.dart`, `lib/views/shared/staff_message_contacts.dart` |
| Dynamic configuration and floor labels | `lib/views/owner/dormitory_configuration_page.dart`, `lib/views/owner/floor_management_page.dart` |
| Android runner configuration/native integration | `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`, native sources under `android/app/src/main/kotlin/` |
| iOS runner configuration/native integration | `ios/Runner/Info.plist`, `ios/Runner/AppDelegate.swift`, `ios/Runner/Runner.entitlements`, `ios/Runner.xcodeproj/` |
| Browser hosting and conditional desktop runners | `web/`, `vercel.json`, `tool/vercel_build.sh`, `windows/`, `macos/`, `linux/` |

## Suggested work order and completion checks

1. Establish shared compact cards, page spacing, list/filter/pagination controls and button visibility.
2. Update Profile/Settings and relocate room transfer/eviction entry points without losing existing access.
3. Refine Rooms, Cleaning, Visitors and Presence/Curfew; then apply shared changes to Caretaker.
4. Simplify Billing/Payment verification and report lists; review proposed merges individually.
5. Refine Accounts, guardian links, announcements, contacts, contracts and analytics/export controls.
6. Complete the full Tenant/Guardian screen inventories and corresponding Owner/Caretaker mobile checks; verify role-specific information boundaries.
7. Complete independent web, Android and iOS platform checks, then document the delivery decision and validation/N/A state for each desktop-native runner.
8. Run cross-role workflows and fill the screen/platform evidence ledger before calling the system-wide UI review complete.

- [ ] Finalize proposed merges and the unclear Accounts note before dependent implementation.
- [ ] Verify each action remains reachable and notification links still open the correct record after consolidation.
- [ ] Check search/filter/pagination behavior with enough data to exceed one page; filters must not apply only to the visible page.
- [ ] Test narrow and wide layouts, long names, empty/error/loading states, dark mode and keyboard navigation.
- [ ] Recheck account/record privacy and existing Owner/Caretaker/Tenant/Guardian permissions.
- [ ] Keep balances, signed terms, geofence rules, approvals and historical records unchanged unless a separate approved requirement explicitly changes them.
- [ ] Complete every applicable Owner/Caretaker web, Owner/Caretaker/Tenant/Guardian Android and iOS inventory cell; a shared code change does not mark other platform cells as passed automatically.
- [ ] Record Tenant/Guardian dedicated-web limitations explicitly; no new web workspace is assumed or authorized by this checklist.
- [ ] Record every skipped/blocked runtime check and every desktop-platform N/A decision with a reason.
- [ ] Review public/authentication screens and nested forms/dialogs as well as primary navigation destinations.
- [ ] Publish a final UI completion summary separating changes implemented, existing acceptable screens, verified platforms, proposed merges awaiting a decision and outstanding device/environment checks.
