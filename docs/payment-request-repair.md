# Payment request repair — 2026-10-18

The manual form and automatic resume/receipt paths passed a Dart list of maps to
PostgREST `contains` for the JSONB `bill_breakdown` column. The SDK serialized the
list as a PostgreSQL array rather than JSON. All three lookups now pass an
explicitly JSON-encoded array. The HTTP regression tests inspect and decode the
actual service requests so this failure is no longer hidden by gateway mocks.

The app's rent payment screen sends `charge_ids`, including for a single rent
month. The previously deployed October 8 payment handler only accepted
`charge_id`, returning "Choose a valid bill" before creating a QR. The current
payment, webhook and reconciliation functions were deployed together to support
the existing multi-bill database schema and request contract.

The user confirmed automatic payments are for defense/demo testing and that the
connected project contains only demo/sample accounts and bills. Its test
configuration was aligned accordingly:

- Database deployment designation: `staging`.
- Edge deployment designation: `staging`, pinned to the connected demo project.
- PayMongo environment: `test`; live collection remains disabled.
- Existing demo test credits remain enabled.
- All 68 existing non-deposit sample bills were registered in `paymongo_test_bills`.
- Collection mode was preserved. No balances were reset or payments simulated.

Future sample bills must also be explicitly registered before sandbox checkout.
These designations are for a sample-only project. Before using real tenants or
collecting real money, configure a production/live deployment separately and
review the existing sandbox isolation setup.

The backend deployment is complete. Clients need a new app/web build containing
the `PaymongoPaymentService` fix; deploying Edge Functions cannot change code
already installed in an app or cached in the browser.

Validation: 24 focused Flutter tests, 25 Deno gateway/webhook tests, and static
analysis passed. Tests cover manual request checks, automatic resume and receipt
queries, request validation, QR data handling and settlement verification.
No real payment was collected during validation.
