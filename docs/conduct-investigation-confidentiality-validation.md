# Conduct investigation and confidentiality validation

> October 18 follow-up: this report retains its October 16 scope and results.
> Tenant photo attachments have since been implemented for responses and appeals;
> see [tenant evidence](tenant-conduct-evidence.md). Agreement access now uses
> mandatory module gates; see [agreement workflow](module-agreement-workflow.md).
> The earlier tenant-attachment and optional-access limitations below describe
> the historical implementation, not the current source. Physical-device checks
> and approved agreement wording remain outstanding.


Date: 2026-10-16. Branch: `main`. Implementation and database validation were local only. Changes are committed separately at the client's subsequent request; no pushes, deployment, linked-project resets or production writes performed for this work. Three existing room/contract commits were already ahead of `origin/main` before these commits.

## Task status

| Request | Status | Result / remaining requirement |
| --- | --- | --- |
| 1. Existing feature audit | COMPLETED AND TESTED | Reviewed conduct pages/services, statuses, tenant explanations, official responses, staff evidence, history, appeals, notifications, role policies, confidential concerns and profile/onboarding entry points. Relevant paths were reported before editing. |
| 2. Investigation workflow | COMPLETED AND TESTED | Explicit documented Owner outcomes reuse append-only case events. Reasons, actor, server timestamp, version checks and request IDs are required. Case status is separate; no allegation, warning, reply or closure automatically confirms a violation. |
| 3. Staff evidence | IMPLEMENTED BUT NOT VERIFIED | Database authorization, registration, retry, metadata matching and historical protection are tested. Added private signed image preview, uploading staff identifier and retry-safe upload dialog. Real Storage HTTP upload/download and successful image rendering on desktop/Android/iOS still require integration/device verification. |
| 4. Structured responses | ALREADY IMPLEMENTED AND VERIFIED | Separate explanations, tenant-visible official responses and internal administrative notes retained. Existing RPC/widget regressions pass. Added a cross-operation request-ID guard so a response cannot reuse a decision entry as its own retry. |
| 5. Permissions | COMPLETED AND TESTED | Client explicitly confirmed preserving existing permissions. Existing Owner/Caretaker case, warning, dismissal, closure, recommendation and appeal permissions remain unchanged. No assignment restriction or additional Caretaker access is introduced. |
| 6. Repeat tracking | COMPLETED AND TESTED | Shared guarded database projection distinguishes published cases, confirmed incidents, pending investigations, dismissed/unconfirmed, closed without outcome and cases with appeals. Exact linked duplicate incidents count once when confirmed. |
| 7. Confidentiality agreements | BLOCKED BY DEPENDENCY | Version/acceptance infrastructure implemented and tested. Client confirmed that no approved wording is available yet. Approved tenant and guardian content remains a dependency; nothing is seeded or published. |
| 8. Acceptance workflow | COMPLETED AND TESTED | Review page, unchecked explicit acceptance, awaited save confirmation, retry and historical display tested. Owner publishing/verification screens implemented; full authenticated UI/Storage stack verification remains outstanding. No mandatory onboarding gate or account suspension added. |
| 9. Privacy and access | COMPLETED AND TESTED | Direct SQL API role tests, tenant isolation, guardian restrictions, internal-note separation, staff evidence RLS and immutable agreements pass in disposable databases. This is scoped validation, not a complete penetration test. |
| 10. Notifications/navigation | ALREADY IMPLEMENTED AND VERIFIED | Existing destinations retained. New decision events use existing transactional notification producer; retry and rollback tested. Existing authenticated notification navigation tests pass. Actual push delivery on devices remains unverified. |
| 11. Mobile/web UI | IMPLEMENTED BUT NOT VERIFIED | Automated 320 px / desktop-width agreement and outcome tests, long text, decision dialog with keyboard inset, loading/error/retry states pass. No physical Android/iOS test performed. |
| 12. Database/migrations | COMPLETED AND TESTED | Two additive migrations tested in disposable PGlite and standalone PostgreSQL. Legacy cases/history/evidence retained; no inferred historical confirmations. Full Supabase migration-chain and Storage service compatibility require staging validation. |
| 13. Regression | COMPLETED AND TESTED | Formatting, analyzer, relevant Flutter tests, isolated SQL tests and independent PostgreSQL concurrency tests run. Exact commands and limits below. |

At the October 16 assessment, tenant image attachments were **NOT IMPLEMENTED**: the existing tenant explanation and appeal workflows support text/supporting information. The existing evidence bucket is staff-only. It was not opened to tenants or guardians; a separately approved upload/access design is needed before adding tenant files.

## Existing implementation and permission audit

- `lib/views/shared/conduct_case_pages.dart` and `lib/services/conduct_case_service.dart`: staff case list/detail, tenant-owned published cases, original descriptions, tenant explanations, warning/status controls and staff image uploads.
- `lib/views/shared/conduct_official_responses.dart`: structured responses, explicit visibility, immutable retry payloads, backend save confirmation.
- `lib/views/shared/conduct_case_appeal_panel.dart`, `lib/services/conduct_case_appeal_service.dart`: existing reconsideration flow. Accepted appeals never automatically rewrite a case or reverse a warning.
- `lib/views/shared/notification_destination.dart`: staff/tenant-specific case destinations; backend reads continue to enforce authorization.
- `20260924070000_phase4a_conduct_cases.sql`, `20260924090000_phase4c_conduct_case_appeals.sql`, `202610140001_phase5_report_and_conduct_responses.sql`: existing staff-only case/event/evidence policies, tenant-safe RPCs, warnings, appeals, internal/visible response separation. The last filename is pre-existing; this work does not start another project phase.
- Confidential concern reporting retains its existing staff access/audit functions and tenant isolation (`202609190003_tenant_confidential_reports.sql`, `202609190004_owner_confidential_report_review.sql`, subsequent reporting migrations).
- Profile/onboarding inspection found no dedicated confidentiality version/acceptance table. Rental-contract signatures are not reused as confidentiality acceptance.

| Action | Existing Owner | Existing Caretaker | Tenant / Guardian |
| --- | --- | --- | --- |
| Read conduct cases/history/evidence | Yes | Yes; staff scope, not assignment-limited | Tenant safe own published case reads; Guardian no new conduct access |
| Read/triage confidential concerns | Existing staff permissions | Existing staff permissions | Existing own-report rules retained |
| Review explanations; add official/internal responses | Yes | Yes | Tenant own explanation and tenant-visible responses only |
| Publish, investigate, warn, resolve or dismiss | Yes | Yes | No staff actions |
| Recommend termination review | Yes | Yes | No staff actions |
| Actual eviction workflow | Existing Owner-only workflow | No added authority | Unchanged |
| Review/decide appeals | Yes | Yes | Tenant own eligible appeal/withdrawal |
| Explicit confirmed/not-confirmed/overturned outcome | New Owner-only documented action | No added permission | Own permitted outcome reads only |
| Publish agreement / verify everyone's acceptance | New Owner-only action | No added permission | Own audience/version/history and own acceptance only |

There was no pre-existing explicit confirmation capability to remove from Caretakers. The new Owner outcome action follows the requested oversight structure while all existing Caretaker disciplinary/appeal actions remain intact. The client explicitly chose to preserve those existing actions and permissions.

## Changes and files

- `lib/services/conduct_case_service.dart`: guarded investigation projection/decision calls; paged staff/tenant case reads and batched profile names to avoid silently truncated recorded-case totals; evidence storage path/uploader metadata; short-lived signed previews; stable upload request IDs; no destructive cleanup following an ambiguous registration reply. Duplicate-storage retries reuse their original path and immutable caption.
- `lib/views/shared/conduct_case_pages.dart`: shared outcome panel for staff and tenants, evidence preview/uploader, guarded upload/retry dialog, scrolling tenant response dialog, evidence/appeal refresh subscriptions, refreshed recorded-case total and guarded asynchronous detail refreshes. Failed authorization/reload hides cached case details/actions instead of retaining a stale record.
- `lib/views/shared/conduct_investigation_panel.dart`: separate investigation outcome, current metrics/history, Owner-only explicit decisions and selection of an accepted appeal for an overturn. Backend enforces every action; visibility of a button is not authorization.
- `lib/services/confidentiality_agreement_service.dart`: paged version/history/account reads and guarded publication/acceptance RPCs.
- `lib/views/shared/confidentiality_agreements_page.dart`: Owner publication with explicit approved-wording attestation and verification of current/historical acceptance; participant review and acceptance; no-content state and historical versions. Full agreement is scrollable; acceptance is initially unchecked and enabled after the end is reached. Opening/reaching the end alone does not save acceptance.
- `lib/views/shared/profile_edit_page.dart`: Tenant/Guardian agreement entry point.
- `lib/views/owner/owner_pages.dart`: Owner-only agreement administration entry point in Reports & Cases.
- `test/views/conduct_investigation_agreements_test.dart`: new behavior/widget tests.
- `tool/test_conduct_investigation_agreements.mjs`: guarded disposable database workflow/security/upgrade tests.
- `tool/test_conduct_investigation_concurrency.mjs`: independent local PostgreSQL session tests.
- This validation report and the two migrations below.

## Database and repeat-count behavior

`202610160006_conduct_investigation_evidence.sql` extends existing case events with three explicit outcome types and an accepted-appeal reference. It adds Owner-only versioned/idempotent decision RPC and role-safe summary RPC. Existing status/warning/reply/appeal functions retain their permissions. Registered objects are excluded from staff Storage UPDATE/DELETE policies; a database trigger also protects registered objects against replacement/deletion. Registration checks case/path, real object existence, matching stored MIME/size, uploader and immutable duplicate metadata, under row locks.

`202610160007_confidentiality_agreements.sql` adds immutable published versions and immutable self-acceptances, role-safe SELECT policies, Owner publication and participant acceptance functions. Ordinary users cannot insert/update/delete these tables. The backend derives the accepting user and timestamp, accepts only the appropriate audience/current version, and makes retries idempotent. Publication/acceptance serialize per audience. Existing acceptances always retain their exact immutable version/content. No real legal content is included.

Counts use only published cases in both staff and tenant projections. Staff additionally retain a separately labelled recorded-case count including drafts. A confirmed incident needs the latest explicit `investigation_confirmed` event and a non-dismissed case. Generic `resolved`, warning or recommendation statuses never establish confirmation. Legacy closed cases are shown separately without fabricated decisions.

Confirmed deduplication uses tenant-scoped `(source_module, source_record_id)` where there is a concrete non-manual/non-other linked source. Manual/unlinked cases are separate incident identities; arbitrary similar descriptions are not merged. Staff must review possible manual duplicates. Published case totals still count each case; confirmed incident totals may therefore be smaller and the categories are not an arithmetic partition.

Pending/accepted appeals are identified separately. An accepted appeal alone keeps the previous outcome; the Owner must record a documented overturn linked to an accepted appeal on the same case. An overturn may be recorded after administrative closure without reopening the case or deleting warnings/history. Duplicate case records for a linked incident retain their independent decision histories and require their own reviewed corrections.

Registered historical objects/metadata are preserved, including older paths that would not qualify for a new registration. Unregistered files left after interrupted uploads are not presented as completed evidence and are deliberately not deleted after an ambiguous RPC failure. Future orphan cleanup must distinguish unregistered objects from immutable registered evidence.

## Executed validation

- `dart format` on modified/new Dart files.
- `flutter analyze`: no issues found.
- Relevant Flutter run: 61 tests passed across conduct configuration, conduct/appeal policies, official responses, new agreements/outcomes (9 new widget tests), profile-entry contracts, notifications/navigation and room-operation regression checks.
- `node tool/test_phase5_report_conduct.mjs`: 17 existing isolated PostgreSQL regression checks passed (responses, confidential reporting, privacy, notifications/rollback, warnings, appeals and closure).
- `node tool/test_conduct_investigation_agreements.mjs`: 14 new disposable PGlite checks passed, including upgrade/historical compatibility, authorization, valid outcomes, linked duplicate counts, appeals, evidence registration/protection and immutable agreement acceptance.
- The same workflow harness was executed against a separate empty disposable loopback PostgreSQL database using `--disposable --local-config <ignored local config>`; no linked Supabase project was used.
- `node tool/test_conduct_investigation_concurrency.mjs --disposable --local-config <ignored local config>`: five independent-session PostgreSQL checks passed: concurrent self-acceptance, publication versus stale acceptance, conflicting decisions, duplicate evidence registration and storage deletion versus registration.
- `git diff --check`: passed.
- `flutter devices`: Windows, Chrome and Edge available; no connected physical Android/iOS device. Physical Android/iOS testing, actual native pickers/image previews and device push delivery were not performed.

The SQL harness uses actual migrations for the relevant modules with disposable auth/storage/notification fixtures. It does not represent a full Supabase stack, full migration-chain replay, Storage HTTP integration or end-to-end signed-image rendering. These limitations apply even when standalone PostgreSQL tests pass.

## Deployment/readiness and remaining client decisions

This work is ready for review and controlled integration testing, **not production release sign-off**. No staging Supabase project or approved legal documents are configured.

Before deployment: review both migrations in repository order after `202610160005`, replay the full migration chain on disposable Supabase/staging, verify Storage's actual `owner_id`/metadata shape and permission checks, exercise upload/failed-upload/retry/signed download through the Storage HTTP API for both staff roles, and verify original registered files remain unchanged after attempted overwrite/delete. Test authenticated Owner publication/verification and Tenant/Guardian review/acceptance through the complete UI. Test device layouts/pickers/previews, notifications and deep links with permitted and unauthorized accounts. Apply to production only with separate authorization.

Confirmed client decisions: preserve existing Owner/Caretaker permissions; no approved confidentiality wording is available yet. Remaining dependencies: approved exact tenant and guardian wording, full integration/device validation and a separately approved tenant-file evidence access design. Caretaker agreement verification and mandatory acceptance blocking are not enabled; either would require a future explicit policy decision. Accounts remain usable and no placeholder terms are published.

Separate commits authorized by the client:

1. `Violation investigation and evidence protection implemented`
2. `Tenant and guardian confidentiality agreement acceptance implemented`
3. `Conduct investigation and confidentiality regression coverage added`
4. `Conduct investigation and confidentiality validation documentation added`

Investigation and evidence changes share a migration, service and case-detail panel and are kept together as one coherent commit. No push has been made for this work.
