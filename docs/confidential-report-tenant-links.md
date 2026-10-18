# Tenant links in confidential concerns

Implemented locally October 19, 2026. One optional tenant per report, as requested.

Tenant concern forms offer an optional name search. The report author remains
`tenant_id`; the separate `reported_tenant_id` identifies the tenant involved.
The database validates an active tenant other than the reporter and captures the
name itself. Submitted links/names are immutable; corrections use existing
addenda. Missing or unavailable search never requires selecting a tenant. A
failed submission with a selected tenant does not silently discard that link.

The directory RPC requires an authenticated tenant with the existing
confidentiality agreement, or staff. It requires a 2–80 character query, returns
20 matching names/IDs per page, excludes self/inactive accounts, and exposes no
phone, email, financial, room or conduct information. Duplicate names should be
left unspecified and described for staff to investigate.

Staff see the reporter and involved tenant separately and can open the involved
tenant's existing staff directory record. The reporter also sees their submitted
selection in history/details. Existing report RLS remains unchanged: being named
does not expose the report, reporter, addenda or staff review to that tenant or
their guardian, and creates no notification to the named tenant.

Conduct creation's confidential-source picker uses a new audited staff RPC. It
returns reports naming the selected case tenant, with category/date/ID only.
Backend creation validates the same subject relationship. Reporter identity,
report summary and source identifiers are not copied into tenant-visible case
text. Staff must write a separate reviewed allegation and explicitly publish it.
Selection/linking does not confirm a violation or alter residency. Existing
investigation decisions remain responsible for confirmed incident counts.

Historical reports remain unspecified, and existing case links are preserved.
Unspecified reports are not automatically offered against their authors. They
remain reviewable; staff may create a manually documented case following review.
Maintenance, visitor, payment and inspection linking retain their existing rules.

Apply `202610190004_confidential_report_subject.sql` after existing migrations
before releasing the updated client. The client still submits unspecified reports
without the new field, but tenant search, selected-subject submissions and new
confidential-source linking need this migration. No live migration was applied.

Validation: 20 disposable PostgreSQL reporting checks pass, including seven new
subject/link/privacy checks; eight Flutter tests pass (five new selector behavior
tests at 320/1280 px and three tenant queue regressions). Changed Dart files pass
targeted analysis. Full app/widget walkthrough remains blocked by existing
unrelated shared-screen compile errors (missing feedback service and mismatched
notification parameters). Device verification, full Supabase migration replay
and authenticated report-to-case walkthrough remain release checks.

October 19 repair follow-up: the unrelated shared-screen errors above have since
been repaired locally. Full analysis now passes, and the previously blocked
conduct investigation/agreement widget suite passes as part of a 60-test run.
See [shared-screen and transfer repair](shared-screen-and-room-transfer-repair.md).
