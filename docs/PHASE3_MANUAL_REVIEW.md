# Phase 3 manual review — original CarmeLink

Implementation is in `C:\Users\ligay\OneDrive\Documents\Capstone\CarmeLink`, branch `main`. Phase 2 is already integrated. No clone transfer or navigation changes are included.

## Run locally

```powershell
cd "C:\Users\ligay\OneDrive\Documents\Capstone\CarmeLink"
flutter run -d chrome -t lib/main_web.dart
```

Use `flutter run` for native mobile. Review the newly launched local app, rather than the deployed website or the old clone server.

## Manual acceptance checks

Review at 320, 360, 390, 768px and desktop, including enlarged text and an open keyboard in forms.

| Area | Check |
|---|---|
| Billing & charges | Compare the overview amounts/counts against existing data. Open rent, utility, other/manual, deposit-history and overdue records. Check balance, due date, period, notes, filters, upcoming toggle and existing Load more. Open/cancel Utility Charge Cart, other-charge and management forms. |
| Payments & verification | Check pending, verified, rejected, partial and overdue records. Compare submitted amount, bill total, remaining balance, payer, reference, date and method. Check Copy, proof thumbnail/fullscreen, print, and existing confirm/reject behavior. |
| Tenant payments & OCR | Check current/future/history filters, paid and overdue cards, existing checkout/proof actions, receipt details and readable scan results. Scanning/autofill remains unchanged; browser OCR availability remains the existing platform behavior. |
| Receipts | Open saved payment receipts. Check amount, payer, method, received date/time, references, test notices and print retry. Open issued receipt/photo records and the existing void/replacement forms. |
| Deposits & settlement | Check required/received/held amounts, searchable deposit list and Show more. Compare deductions, refund, shortfall and outcome with existing records. Inspect itemized deductions and existing propose/approve/reject, refund proof, finalize and acknowledge actions for the appropriate role. |
| Maintenance & confidential reports | Check queue filters/search, long tenant/category/location values, status and urgency colors, report content and attachments. Open maintenance details, assignments, history and response controls. Verify confidential addenda, staff history and administrative actions remain role restricted. |
| Reporting & exports | Open existing reporting queues, finances and analytics. Check the export document cards and Print / Download PDF action. Verify generated report data and filters against existing records. |

Do not perform financial writes merely to check the layout. Use appropriate existing test records when intentionally exercising actions.

## Automated checks

- 53 presentation/payment/receipt/maintenance layout checks passed after fixing dialog intrinsic sizing.
- 35 additional receipt/report/billing/deposit workflow and policy checks passed.
- Final affected-screen recheck and Flutter analysis are recorded in the implementation report.
- New record-layout regression cases cover 320–1280px with normal and 1.6x text.
- Existing PDF tests emit font-support warnings; the PDF generation service and templates were not changed.

Manual authenticated browser/device acceptance is still pending. The user authorized local Phase 3 commits on October 18, 2026; this does not imply manual acceptance or deployment approval. No backend, service, calculation, policy, permission, theme, navigation or generated-platform files were changed.

## 3D / 3E continuation

Completed without restarting 3A–3C:

- Maintenance filters now wrap visibly; floor-plan headings and history transitions wrap safely.
- Maintenance/damage categories retain their original report data and actions.
- Confidential report empty states, review responses, staff history and addenda have structured presentation. Closed-report restrictions remain unchanged.
- Analytics exports use a responsive one/two-column layout. Export action footers stack before overflowing. All six original document-generator callbacks remain unchanged.
- Financial category totals use the same precomputed rent and utility collections.

Verification: 26 affected existing reporting/maintenance/configuration regressions passed. The 16 new presentation cases passed at 320, 390, 768 and 1280px, including damage-category maintenance records, floor-plan controls, closed-report history, unchanged financial totals and existing PDF actions. Final `flutter analyze --no-pub` and `git diff --check` passed. A whitespace-normalized audit found all 474 existing action/export callback expressions unchanged.

Scope limitations: no new paging/search/filter state was added to queues lacking it. No CSV exporter or new report-configuration form exists in these screens; adding those would require functional changes. Existing PDF preview controls live in the unchanged report service and are preserved. No live browser or physical-device testing was performed.

## Subsequent billing refinements

- Billing overview and deposit totals use responsive financial summary cards, with existing values and calculations preserved.
- Payment collection explanations are grouped visually; mode selection, readiness checks, saving and retry behavior remain unchanged.
- User-requested numbered pagination replaces Load more for charges (20 per page) and Show more for deposits (6 per page). This changes only the displayed slice of already-loaded records. Search/filter resets and page bounds prevent inaccessible results.
- Below 600px, billing actions wrap in the page body so the app bar retains room for its title and existing global actions. Payment, alert and refresh callbacks remain unchanged.
- Focused pagination and billing regressions: 9 passed. Subsequent mobile header checks: 9 existing regressions passed. Financial summary/payment/deposit checks: 18 passed. Analysis and diff checks passed. These are automated checks, not authenticated manual browser/device acceptance.

The earlier checklist references to Load more and Show more should now be tested using the numbered page controls instead.

### File map

- 3A: `lib/views/owner/billing_management_page.dart`, `lib/views/owner/utility_charge_cart_dialog.dart`.
- 3B: payment sections in `lib/views/owner/owner_pages.dart` and `lib/views/tenant/tenant_pages.dart`; `lib/views/shared/staff_payment_received_dialog.dart`, `lib/views/shared/payment_receipt_history.dart`, `lib/views/shared/issued_receipt_register.dart`.
- 3C: `lib/views/shared/security_deposit_card.dart`, `lib/views/shared/staff_security_deposits_section.dart`, `lib/views/shared/move_out_settlement_page.dart`.
- 3D: reporting sections in `lib/views/owner/owner_pages.dart`, `lib/views/owner/staff_maintenance_page.dart`, `lib/views/shared/confidential_report_history.dart`, `lib/views/shared/report_addenda.dart`.
- 3E: analytics/export/financial category sections in `lib/views/owner/owner_pages.dart`.
- Shared presentation only: `lib/core/widgets/record_details.dart`.
- Tests: `test/ui/phase3_record_details_test.dart`, `test/ui/phase3_reports_presentation_test.dart`; updated display assertions in `test/views/owner_payment_verification_test.dart` and `test/views/staff_security_deposits_section_test.dart`.
