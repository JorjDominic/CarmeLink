# Owner eviction and departure workflow

Open **Profile > Eviction & departure notices**. An owner can also open the
workflow from a conduct case with a termination-review recommendation. A conduct
recommendation alone never evicts a tenant.

1. **Record owner decision:** choose an active tenant contract, document the
   reason, and choose a departure deadline. The draft stays private to staff.
   Saving it keeps the signed rent, contract, room assignment, and deposit intact.
2. **Review and publish:** preview the notice PDF, then publish it as a separate
   owner action. The app stores its hash, notifies the tenant and linked
   guardians, and creates an eviction move-out workspace. The tenant can read
   the notice and submit a response. A response records no consent to eviction.
3. **Record actual departure:** owner or caretaker records the actual date and
   departure/key-handover evidence. This does not immediately close the contract.
4. **Complete inspection and settlement:** use the linked inspection, clearance,
   and deposit workspace. Deductions require evidence and owner approval. The
   existing deposit-to-charge process applies credits once, records refund
   evidence when needed, and leaves any damage shortfall payable.
5. **Close tenancy:** only the owner can confirm final closure. The database
   rechecks actual departure, completed inspection, resolved clearance, finalized
   settlement, outstanding charges, and pending payment proofs/gateway requests.
   It atomically terminates the matching contract, ends the matching assignment
   on the actual departure date, and marks residency inactive. Original signed
   terms, charges, payments, deposit evidence, and case history remain available.

The owner can rescind a draft or published notice before actual departure and
before settlement is finalized. This restores active residency and keeps the
contract, room assignment, and held deposit. A closed case remains read-only;
the tenant can still acknowledge its settlement.

## Rules and access

- Owner decisions specify the deadline; the feature does not automatically
  determine notice eligibility or legal notice periods. The existing 30-day
  rule continues to apply to voluntary move-out notices. In-app publication and
  a saved PDF do not represent proof of external formal service.
- A linked conduct recommendation must belong to this tenant and be eligible
  when the decision is recorded and notice published. Pending or accepted
  appeals block using that recommendation. Later conduct-review changes do not
  rewrite issued notices or prevent recording an already completed departure
  and settlement as history. Owners review tenant responses before proceeding.
- Pending eviction blocks competing room transfers, renewals, term/rent edits,
  and shortcuts through the old contract/assignment controls. After closure, a
  later tenancy can use the normal voluntary move-out and room-transfer flows.
- There is no automatic penalty, deposit forfeiture, refund, rent proration, or
  bill waiver. Future rent invoices remain in the ledger for owner review using
  the existing billing controls. Unpaid non-deposit charges other than future
  rent block final closure, including damage shortfalls.
- Owner and caretaker can read staff cases; only the owner decides, publishes,
  rescinds, and closes. Tenants and linked guardians see issued notices for their
  tenancy. Guardians have read-only access. Drafts are not tenant-visible.
- The notice bucket is private; the app verifies the PDF hash when opening an
  issued notice. Registered notices cannot be replaced/deleted by app users.
  Case changes append audit snapshots. Direct app writes to cases/events are
  revoked; server functions enforce authorization and transition checks.
- Closing does not delete/deactivate the login account. Existing contract access
  rules restrict residence features after termination. **Documents > Departure
  notices & history** keeps notice history reachable from the restricted tenant
  screen. Notifications also open the eviction workspace.

## Verification and deployment

- Migration: `202610090007_owner_eviction_workflow.sql`.
- `node tool/test_evictions.mjs`: 17 isolated PostgreSQL checks, loading the
  deposit, signed-room-transfer, and eviction migrations together.
- Existing PostgreSQL regressions: 20 renewal, 14 room-transfer, and 17
  deposit-to-charge checks.
- Focused Flutter verification: 47 checks covering notice PDF integrity, server
  requests, closure controls, owner form validation, narrow-phone layout,
  notification routing, existing conduct, tenant documents, and settlement.
- `flutter analyze --no-pub`: no issues.
- Deployment checks use `supabase/tests/eviction_deployment_snapshot.sql` to
  compare existing records and `eviction_deployment_verification.sql` for roles,
  policies, private storage, realtime, and guards. A schema-only rollback trial
  runs before deployment; no production tenant eviction is used as a test.

The migration was applied to the linked Supabase project on October 9, 2026.
All 16 existing-record fingerprint groups matched before and after deployment;
the new case and event tables remained empty. Access, storage, realtime, and
workflow guard checks passed against the deployed schema.
Reload/rebuild the Flutter app to load the new screens.
