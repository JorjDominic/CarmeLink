# Phase 6 authorized migration and Git follow-up

Date: 17 October 2026 (Asia/Manila).

After the Phase 6 audit, the user explicitly requested separate commits, a push and application of the necessary migrations. This superseded the earlier instruction to leave migrations and Git publication pending. The original completion report and automated results retain their audit-time findings; this document records the subsequent database changes.

## Migration selection and execution

The linked project was still at `202610140001`. All nine pending migrations support features already present in the current client or their integrity dependencies, so the complete pending sequence was needed:

| Version | Purpose |
| --- | --- |
| 202610160001 | Configurable conduct, inspection, charge, utility, deduction and feedback categories. |
| 202610160002 | Payment test/live isolation and receipt infrastructure required by receipt integrity. |
| 202610160003 | Reporting category/location snapshots and server submission-time safety. |
| 202610160004 | Physical room capacity and retained/retired bed identities. |
| 202610160005 | Standard Shared fixed-rate contracts and occupancy release safety. |
| 202610160006 | Conduct investigation outcomes and protected evidence registration. |
| 202610160007 | Versioned confidentiality agreement/acceptance infrastructure without legal text or a mandatory gate. |
| 202610160008 | Immutable receipt context, recovery provenance and billing summary metadata. |
| 202610160009 | Idempotent approved additional-charge requests. |

`supabase db push --linked --dry-run` confirmed this exact sequence. `supabase db push --linked --yes` then applied all nine successfully. A subsequent dry run reported **Remote database is up to date**. No migration repair, reset, manual history editing, synthetic production payment or destructive production test was performed.

## Snapshot and post-migration verification

Before migration, a private custom-format database snapshot was saved to ignored `build/phase6_release/before_migrations.dump` (1,507,976 bytes). It includes the `public`, `storage` and `supabase_migrations` schemas and their data, excludes ownership/ACL restoration, and was readable with `pg_restore --list`. It is not a complete platform backup: it does not include Auth, private Storage binaries or Cloudinary assets. A full restore was not performed and no disaster-recovery guarantee is implied. The archive contains application data and must remain private; do not add it to Git.

Preflight confirmed that physical bed counts matched every room's configured capacity. Before/after checks compared counts and ordered hashes of selected existing historical fields in ten tables:

- Rooms, bed spaces and tenant assignments.
- Tenant contracts, including approved rent, deposits, dates and occupancy snapshots.
- Billing charges, including original amount, due date and terms snapshot.
- Payment transactions, including amount, status, receipt path and reference.
- Conduct cases, events and evidence references.
- Contract document paths and hashes.

**All compared historical facts remained unchanged.** This comparison deliberately excludes newly added nullable metadata and is not an assertion that every column or external asset was independently audited.

Post-migration verification confirmed:

- `bed_spaces.retired_at` exists.
- `billing_charge_summaries.test_verified_amount` and `latest_gateway_session_id` exist.
- `billing_charges.additional_request_id` exists.
- All nine versions are recorded in normal Supabase migration history.
- The new PayMongo deployment-isolation setting is `production`; test credits were not enabled by this rollout.
- No confidentiality agreement version was published.

Private raw deployment logs and sanitized verification output are under ignored `build/phase6_release/`. Secrets were kept in process memory and were not committed or printed.

## Commit groups

1. `85ec56c` — Preserve uploaded evidence after uncertain database writes: three services, shared outcome classification and 19 recovery regression tests.
2. `bd21b8a` — Prevent cleanup from deleting attached private evidence: Cloudinary reference guard and six Deno tests.
3. `f56d2ba` — Align acceptance checks and preserve staff conduct permissions: current query/UI expectations and explicit Owner/Caretaker SQL checks.
4. Phase 6 acceptance documentation, sanitized automated results, manual checklist and this migration record.

The code was unchanged after the previously completed validation: 1,006 Flutter tests passed, one environment-dependent Supabase test skipped, no static-analysis issues, 42 Edge tests, 25 independent PostgreSQL contention checks, six native Android tests, PDF/browser checks and successful web/Android release builds. Git push verification is reported separately after publication.

## Remaining release limits

The database migration blocker is resolved. The Cloudinary cleanup Edge Function change is committed but **has not been deployed** by this migration-only action. A Git push does not itself deploy Supabase Edge Functions.

Actual provider callbacks, authenticated staging acceptance, complete Auth/Storage integration, physical devices, Android distribution signing and iOS/TestFlight validation remain outstanding as described in the original report. No PayMongo live activation, legal wording, mandatory acceptance gate, automatic retention deletion or unapproved roommate policy was introduced. Overall acceptance status remains **PARTIALLY VERIFIED**.
