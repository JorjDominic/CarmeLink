# Signed room transfer amendments

For a tenant with an active contract, Room management's occupied-bed action
**Move to another bed** opens the room-transfer workspace. The owner proposes
an available destination, effective date within the active lease, and reason.
The system reserves the destination, prepares an amendment PDF, and sends an
in-app notice to the tenant and linked guardians when that PDF is published.

The current assignment remains active. The original lease, term, monthly rent,
deposit receipt, and billing records are preserved. This amendment changes
the room and bed; it does not renew the lease or apply a different rent rate.

All roles can open **Profile → Room transfers & amendments**. Notice taps open
the same workspace. Tenants and the owner review the PDF before drawing their
own electronic signature. The owner verifies submitted tenant signatures.
Guardian and witness requirements are copied from the original contract.
A designated linked guardian can sign electronically; the owner can also
record and verify an actual guardian or witness signed image with their name.

Once every required signature is verified and the agreed date arrives, the
owner explicitly confirms the physical move. The database ends the old
assignment and creates the new assignment atomically. Confirmation retries
do not create duplicate assignments. The original signed lease and earlier
amendments remain available; subsequent transfers use the current assignment.

The owner can cancel a pending transfer with a reason. Cancellation frees the
destination reservation and preserves the current room. Failed PDF publication
leaves a resumable draft with **Generate amendment & send notice** and
**Cancel transfer** controls.

## Enforcement and evidence

- Legacy assignment RPCs and direct staff writes cannot bypass the amendment
  requirement for an active contract. Initial assignments without an active
  contract continue to use the existing assignment flow.
- Destination reservations prevent competing assignments. Pending amendments
  also protect the affected room names, bed labels, and availability settings.
- Pending amendments block changes to contract terms/status and starting
  move-out. A pending renewal or relevant move-out must be resolved before
  proposing a transfer. Changed required signers prevent final confirmation.
- Amendment PDFs live in the private `room-amendments` bucket. Electronic
  signatures record the reviewed PDF hash, signature hash, signer identity,
  signing time, and owner review. Registered documents cannot be overwritten
  or deleted through the app.
- Signature submission and review snapshots are retained in
  `room_transfer_signature_events`. Rejected and superseded evidence stays
  protected, including when a guardian is subsequently unlinked.
- Owners create, publish, review, cancel and confirm. Caretakers can read;
  tenants and currently linked guardians can read relevant records. Direct
  writes to workflow tables are revoked; authenticated RPCs enforce each role.

## Validation and deployment

Migration `202610090006_signed_room_transfers.sql` was applied to linked
Supabase project `iuplkgvitovzjbmtzpme` on October 9, 2026, after a rolled-back
full-schema trial. The remote database is up to date. Post-deployment checks
confirmed table row security, private storage, RPC permissions, legacy
assignment guards, and evidence protection.

All 16 aggregate fingerprints from
`supabase/tests/room_transfer_deployment_snapshot.sql` matched before/after:
existing room/bed/assignment records, contracts/documents/signers, financial
records, move-out records, tenant details, and seven activation/billing
functions. Deployment did not execute transfers for real tenants.

Local verification:

- `flutter analyze --no-pub`: no issues.
- Focused proposal/signature widgets, notifications, room selector, room
  management, room models and local service API checks: **53 Flutter tests**.
- `node tool/test_room_transfers.mjs`: **14 PostgreSQL checks**.
- Existing renewal and deposit-settlement scripts: **20 + 17 checks**.
- `git diff --check`: passed.

The PostgreSQL script uses isolated PGlite, repository room/assignment tables,
the legacy assignment functions, and this migration. Other services use small
fixtures. It requires the existing local installation under
`build/phase2_sql_tests`. Tests cover reservations, document publication,
signature gates and consent hashes, required signers, cancellation, early
confirmation, repeat confirmation, successive transfers, access control,
legacy bypass attempts, and retained rejected evidence. They do not establish
simultaneous transaction behavior or exercise real storage uploads/push
delivery. Rebuild/reload the app and test the full owner/tenant flow using a
test account before an actual tenant move.
