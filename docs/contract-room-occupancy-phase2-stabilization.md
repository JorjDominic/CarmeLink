# Phase 2 stabilization and validation

This report supersedes the validation limitations in the original Phase 2 report. The existing implementation is preserved. Validation was completed on `main` before committing; the user subsequently authorized the grouped commits and push. No production deployment, shared database mutation, reset, or migration-history repair was performed. Phase 3 is reported separately.

## Status of the six issues

| Issue | Status | Evidence and remaining limit |
| --- | --- | --- |
| 1. Group contract amendments | DEFERRED | Approved business rules recorded below. A complete amendment/version, deposit-reference, and credit-reconciliation workflow is absent; existing blocks remain. |
| 2. Independent database concurrency | FIXED AND TESTED | Original deadlock reproduced on PostgreSQL 17.6; eight independent-session contention checks passed after the corrective migration. |
| 3. Signing and activation against Supabase | PENDING EXTERNAL VERIFICATION | Executable, guarded solo/2/3/4-person Auth/Storage workflow prepared; skipped because no disposable full Supabase stack is configured. |
| 4. Browser and physical-device checks | PENDING EXTERNAL VERIFICATION | Verified deposit, stale-room, and enlarged-text overflow bugs fixed; automated responsive checks passed. Browser execution failed on SDK assets; no physical-device testing occurred. |
| 5. Contract authorization | FIXED AND TESTED | Backend role audit, actual contract read policies, forbidden lifecycle writes, and null-role/session evidence RPC checks passed locally. Actual Supabase JWT integration remains part of issue 3. |
| 6. Migration rollout | PENDING EXTERNAL VERIFICATION | Original and corrective occupancy migrations applied to disposable PostgreSQL test schemas; rollback guards tested. The complete historical migration chain and deployed schema compatibility still need staging verification. |

Phase 2 is **not production-ready**. Passing the isolated database and Flutter tests does not replace full-stack staging, migration-chain, browser, or device verification. Group amendments remain unsupported.

## Approved amendment rules and why the workflow remains blocked

The Owner-supplied rules are recorded as requirements, not as implemented behavior:

- Preserve billed and paid history. New shares begin at an approved effective date, preferably the next cycle. Proration needs explicit approval; departure never automatically raises the remaining tenants' rent.
- Cancel and replace unpaid future charges while retaining their originals. Leave paid charges unchanged. Apply prepaid value only through a **separately approved credit reconciliation process**; do not automatically transfer it.
- Keep separate deposit ledgers per tenant, with complete history. No automatic transfer or redistribution; departing tenants' deductions/refunds follow their existing agreements and settlement process.
- Require Owner approval and signatures from every tenant whose obligations or occupancy rights change, incoming acceptance, and applicable departing-tenant acknowledgments. Guardian signatures remain conditional on existing contractual/legal requirements; the application must not invent an exemption.
- Activate only when every required approval and signature is complete. Apply contract, reservation/assignment, and future billing changes atomically. Original signed contracts and financial records remain intact; incomplete amendments stay pending.

The current architecture cannot apply all those rules through the individual renewal/transfer RPCs:

1. `billing_charges_contract_period_kind_uidx` in `202609200001_contract_billing_synchronization.sql` remains unique on contract/category/period even for cancelled charges. Replacing a charge under the same contract ID conflicts with it. Weakening this constraint is not acceptable.
2. `guard_contract_price_terms` in `202610080006_jorge_contracts_and_staff_receipts.sql` protects existing rent and deposit terms; a change requires a new contract. The existing renewal guard accepts subsequent terms, not a coordinated mid-term replacement.
3. `202610080002_contract_deposit_auto_receipt.sql` creates deposit evidence on initial contract creation. A naive replacement with the old deposit could record money twice. Existing renewal deposit carryover moves/zeros prior receipts, contrary to the approved no-automatic-transfer rule for amendments.
4. There is no approved credit-reconciliation transaction tying prepaid amounts to replacement contracts, nor a coordinated amendment evidence record containing the affected-tenant/signature matrix and deposit-ledger references.

A complete implementation needs immutable amendment/version relationships, original deposit-source references and settlement integration, replacement-contract billing under new IDs, separately approved prepaid reconciliation, signed amendment PDFs, all affected signers, and one activation transaction. Those are dependencies of the requested workflow, not safe isolated changes to the existing renewal button. No partial amendment UI or bypass was added. Solo/shared conversions, roommate/count/rent changes, grouped renewals, and grouped transfers remain blocked. Ending physical occupancy does not recalculate contractual shares.

## Targeted fixes

### Database locks

Independent sessions reproduced a room/bed lock inversion with SQLSTATE `40P01`. The forward migration adds a private room-lock helper using `FOR UPDATE NOWAIT`, fail-fast tenant advisory locks, room locking when ending assignments, and room locking before contract activation's row update. Room/bed and room/contract conflicts now return `55P03` with a refresh/retry message instead of deadlocking in the tested patterns. A failed transaction does not partially activate, bill, reserve, or assign. Retrying requires refreshing and obtaining a new valid user action; no blind production retry loop was added. No constraints were weakened.

### Backend permissions

Existing `role <> 'owner'` guards could evaluate to NULL for missing roles and skip denial inside PL/pgSQL. The corrective migration makes activation and seven existing document/signature/requirement RPC guards reject missing sessions/roles explicitly. Function bodies retain their established evidence, ownership, and verification checks. PUBLIC/anon execution is revoked and authenticated execution remains guarded. The internal room-lock helper is not executable by application roles.

| Actor | Preserved access |
| --- | --- |
| Owner | Prepare/create contracts; review requirements/evidence and sign as lessor; activate. Existing signed financial terms remain immutable. |
| Caretaker | Existing staff contract/reservation viewing and permitted administration only; no contract creation, evidence approval as Owner, rental changes, or activation. |
| Tenant | Own contract reads and existing own signature/requirement submission; cannot activate or edit contractual terms. |
| Guardian | Existing linked-tenant contract reads and existing explicitly supported document workflows; no Owner lifecycle powers. |
| Missing role/session, unrelated tenant/guardian | No privileged contract writes; no unauthorized contract reads. |

Future delegation should use explicit permissions for any additional caretaker operation, retain Owner final approval, and be tested at RPC/RLS level. No caretaker privilege expansion was made.

### Contract form

Removing/reselecting a roommate could show a zero deposit while retaining the old deposit value in the submitted selection. Deselection and room/mode/count resets now clear the corresponding stored deposits. A failed room load followed by refresh could retain values missing from new dropdown items; invalid cached room/bed selections are now cleared and published as an empty selection. At 320 pixels, enlarged text plus an open-keyboard inset exposed a 69-pixel mode-selector overflow; expanding the dropdown fixes it. Design and signing flows remain unchanged.

## Actual validation results

- `flutter analyze`: no issues found.
- 70 selected Flutter tests passed; **one full-stack staging test skipped**. Suite includes occupancy policy/service/PDF tests, contract models/renewals, signing safety, reservation selector synchronization, Phase 1 regressions, and responsive forms/subpages. New room/deposit regression tests fail on the old behavior and pass with the fixes.
- 18 isolated occupancy database checks passed, plus unused rollback/reapply. These include actual own/linked contract RLS policies and forbidden writes, null-session/role evidence RPC denial, signing guards, allocated rent, unchanged deposits/history, reservations, immutable terms, and destructive rollback refusal. PGlite serializes these calls; it is not the concurrency evidence.
- Independent PostgreSQL 17.6 sessions: baseline deadlock reproduced, then **eight checks passed**: inverse room/bed locks; competing room reservations; closed solo versus shared activation; unavailable/solo-reserved bed assignments; immutable group term races; activation versus assignment; room/contract signer metadata inversion; same tenant in competing rooms.
- Legacy scripts passed: 20 renewal checks, 14 signed room-transfer checks, and signed-contract activation checks. These are separate legacy fixtures, not a full migrated deployment.
- Formatting and whitespace validation performed on changed files.
- Headless Edge was available and launched, but Flutter browser tests stalled because local CanvasKit JS/WASM returned HTTP 404. The attempted runs were interrupted; browser assertions did not run successfully. No physical Android/iOS/tablet checks occurred.

Concurrency used three independent `pg.Client` connections in an isolated Docker internal network with Supabase's PostgreSQL 17.6 image. The bootstrap creates a minimal disposable schema and loads actual selected repository migrations, policies and functions. Auth uses simulated role/session contexts, not Supabase JWTs. The full historical schema chain, Auth, Storage, API, and cron integrations were not executed. Separate new databases were created for each run; no database was reset or wiped. Test fixtures and evidence are retained in the dedicated local container. Credentials are generated locally under ignored `build/phase2_stabilization_local`; they are not committed or printed.

The dedicated test container was stopped after validation; its datasets were retained. Evidence logs are local ignored artifacts: `build/phase2-real-concurrency-final.log`, `build/phase2-stabilization-flutter-final.log`, and `build/phase2-stabilization-analyze-final.log`.

### Reproduce isolated tests

```powershell
npm install --prefix build/phase2_sql_tests --no-audit --no-fund --ignore-scripts @electric-sql/pglite pg
node tool/test_contract_occupancy.mjs
node tool/test_contract_renewals.mjs
node tool/test_signed_contract_activation.mjs
node tool/test_room_transfers.mjs
```

For real contention, use an **empty, dedicated local** PostgreSQL database named `carmelink_phase2_validation` or `phase2_validation_<unique_suffix>`. Supply its connection URL through `PHASE2_TEST_DATABASE_URL`, or a local ignored JSON file with `connectionString`. Never point it at an existing local application database or live/linked Supabase project.

```powershell
node tool/test_contract_occupancy_concurrency.mjs --disposable --local-config build/phase2_stabilization_local/connection.json
```

The script rejects non-loopback hosts, unapproved database names, and nonempty schemas. The already-created internal Docker setup is reached using the same script with `--docker-network` inside a `node:24-alpine` container on `carmelink_phase2_validation`, with a read-only workspace mount. Use a fresh database for a repeat; do not reset the retained fixtures.

## Full Supabase verification still required

`test/services/contract_occupancy_staging_test.dart` uses the existing services to prepare all four occupancy counts, reject early activation without bills, generate PDFs, upload/review test requirements, sign as tenant and Owner, finalize/download verified execution copies, activate, and verify assignments, rent shares and billing uniqueness. Synthetic signature images belong only to disposable QA actors. The test performs no deletions and leaves its evidence for review. It does not cover every guardian/witness or existing-data migration scenario; those checks remain below.

Required local environment variables: `PHASE2_STAGING_DISPOSABLE=yes`, `PHASE2_STAGING_URL` (loopback only), `PHASE2_STAGING_KEY` (local publishable key), `PHASE2_STAGING_PASSWORD`, and `PHASE2_STAGING_MANIFEST` (path). Set secrets locally; do not paste them or commit them. The manifest format is:

```json
{
  "purpose": "phase2-disposable-validation",
  "owner_email": "qa-owner@example.test",
  "owner_name": "Phase2 QA Owner",
  "groups": [
    {
      "room_id": "<registered QA room UUID>",
      "tenants": [
        {"id": "<fresh tenant UUID>", "email": "qa-tenant@example.test", "name": "Phase2 QA Tenant", "bed_id": "<QA bed UUID>"}
      ]
    }
  ]
}
```

Provide four separate groups with 1, 2, 3 and 4 tenants, separate available rooms whose names start `PHASE2-QA-`, and fresh authenticated adult tenant profiles whose names start `Phase2 QA `. They must have valid emergency/email details and no earlier contracts. All test accounts use the locally supplied QA password. Registered capacity and beds must cover each group. Provisioning those actors is an explicit fixture prerequisite; the test does not create Auth users or bypass onboarding.

```powershell
flutter test test/services/contract_occupancy_staging_test.dart
```

Without that configuration the result is SKIPPED, not a successful integration test.

## Migration dependencies, deployment and rollback

Required order: all existing prerequisite migrations, then **`202610130001_contract_room_occupancy.sql`**, then **`202610130002_contract_occupancy_stabilization.sql`**, then the matching app. The original shipped migration remains unchanged. The new forward migration replaces relevant functions without changing stored contract amounts, deposit records, reservations, original snapshots, or historical billing. It depends on the existing signing/storage/requirement RPCs and occupancy triggers; do not apply it in isolation.

If the subsequent Phase 3 room integration is included, also apply `202610130003_room_contract_occupancy_display.sql` before the matching app. Reverse that display migration first if reviewing an unused-deployment rollback; the stabilization rollback now explicitly rejects the opposite order. See [Phase 3 room integration](room-management-phase3.md) for the additional read-only summary and refresh dependencies.

Before any rollout, inspect actual migration history and schema. The isolated runner validates selected migration behavior; it does not establish that a shared deployment matches every prerequisite. A staging copy must cover representative legacy contracts, existing assignments, paid/unpaid bills, deposit evidence, and tenant/guardian links without using live tenant data.

For a dedicated full local Supabase stack, create a separate work directory with a unique project ID and nonconflicting ports. Copy the config and historical migration files, **not** linked `.temp` state or production environment files. Disable seeds, use local Auth redirects and credentials, and review outbound cron/HTTP jobs first: some historical migrations contain shared-project URLs. Keep test database outbound connectivity blocked or explicitly disable those jobs in the disposable fixture. No full stack was initialized here because those prerequisites were not established.

After safe local initialization, the exact CLI sequence is:

```powershell
supabase migration list --local --workdir <disposable-local-workdir>
supabase db push --local --dry-run --workdir <disposable-local-workdir>
supabase db push --local --workdir <disposable-local-workdir>
supabase migration list --local --workdir <disposable-local-workdir>
```

Review the dry-run before applying. Do not use `--linked`, `db reset`, or `migration repair` for this validation. For a shared/production deployment, separately authorize the target and examine its actual history; apply pending files in migration order before app deployment, then run the same schema checks and authorized smoke tests. No production command was executed.

Read-only schema verification queries:

```sql
select to_regclass('public.contract_occupancy_arrangements');
select column_name, data_type from information_schema.columns
where table_schema='public' and table_name='tenant_contracts'
  and column_name in ('occupancy_id','occupancy_snapshot');
select indexname,indexdef from pg_indexes
where schemaname='public' and tablename in ('contract_occupancy_arrangements','billing_charges');
select relname,relrowsecurity from pg_class
where oid in ('public.contract_occupancy_arrangements'::regclass,'public.tenant_contracts'::regclass);
select tablename,policyname,roles,cmd,qual,with_check from pg_policies
where schemaname='public' and tablename in ('contract_occupancy_arrangements','tenant_contracts');
select has_function_privilege('anon','public.activate_tenant_contract(uuid)','EXECUTE') as anon_activation,
       has_function_privilege('authenticated','public.lock_contract_occupancy_room(uuid)','EXECUTE') as exposed_room_lock;
-- Both privilege checks above must be false.
select pg_get_functiondef('public.activate_tenant_contract(uuid)'::regprocedure);
```

Verify constraints reject duplicate reservations and invalid capacities, Owner-only preparation/activation, tenant own reads/signing, guardian linked reads, caretaker denial, failed signing no partial activation, exact rent and retained historical bills using disposable records. Run the independent-session and complete Supabase tests; inspect PDFs visually before approving app rollout.

Rollback is **unused-deployment only**: run `supabase/rollback/202610130002_contract_occupancy_stabilization.sql` first, then `supabase/rollback/202610130001_contract_room_occupancy.sql`. The older rollback now rejects reversal while the stabilization helper exists. Both refuse to destroy occupancy history. The corrective rollback restores earlier locks but deliberately retains hardened activation/evidence authorization; it is not a reversal to insecure guards. After any occupancy record exists, use a forward corrective migration. Never remove historical records to make rollback pass. Manual SQL rollback does not automatically repair migration history; review actual state separately before any authorized history action.

## Remaining manual checklist

- Android/iOS, tablet, Chrome and Edge: create forms at narrow and wide widths with long room/tenant names and enlarged fonts. Open/close the keyboard, search/select roommates, scroll forms/dialogs, and reach confirmation/activation controls without clipping.
- Remove/reselect roommates and change mode/count/room: confirm displayed and submitted deposits match; refresh unavailable or reassigned rooms and confirm stale room/bed values clear.
- Preview/download original and executed PDFs: confirm unchanged legal clauses, room/bed/names, exact rental shares and own deposit, readability, and all required signatures. No other tenant's deposit should appear.
- Sign/upload through real Auth and Storage for solo/2/3/4-person groups; test guardian/witness-required cases, missing/rejected/stale/deleted evidence, and denied caretaker/unauthorized activation. A failure must leave draft status, occupancy and bills consistent.
- Validate representative existing contracts, receipts and paid/unpaid rent after the full migration chain. Check repeated activation does not duplicate bills and a departing roommate does not increase anyone else's rent.
- Confirm unsupported group changes remain blocked. Do not use individual renewal/transfer paths to simulate amendments.

## Files and suggested commits

Modified: `lib/views/owner/contract_occupancy_fields.dart`, `test/views/contract_occupancy_fields_test.dart`, `tool/test_contract_occupancy.mjs`, `supabase/rollback/202610130001_contract_room_occupancy.sql`, and the original Phase 2 report.

Added: `supabase/migrations/202610130002_contract_occupancy_stabilization.sql`, `supabase/rollback/202610130002_contract_occupancy_stabilization.sql`, `tool/contract_occupancy_test_fixture.mjs`, `tool/test_contract_occupancy_concurrency.mjs`, `test/services/contract_occupancy_staging_test.dart`, and this report.

Suggested commit wording, following the repository's plain descriptive style:

1. Contract occupancy locking and authorization fixes implemented
2. Contract roommate deposit and room refresh issues fixed
3. Phase 2 concurrency and staging validation tests added
4. Phase 2 stabilization deployment and approval notes updated

Shared fixture/test hunks accompany the database change needed to reproduce its evidence. The user subsequently authorized these grouped commits and push; database deployment remains separate.
