# Issued payment receipt register

Open Payments → Payment receipts → Issued receipt records. Owners and caretakers
can record the actual number and issue date from a management-issued receipt,
with an optional JPG, PNG or WebP photo up to 5 MB. Verified payments only are
eligible. The existing PAY-* receipt remains the immutable system payment snapshot.

Tenants and currently linked guardians can view receipt records and authorized
photos. Staff can void a receipt with a reason and record a replacement. Original
numbers, attachments, issuer, dates, void actor and replacement links remain saved.
Voiding a receipt does not reverse payment or change bill balances.

Receipt numbers are unique ignoring case and whitespace; voided numbers stay
reserved. Test payments have a separate number namespace and show `(TEST)`.
Repeated submissions reuse the same request ID. A lost response freezes the form
so retrying cannot accidentally create another record.

The register records an already issued document; it does not assign tax-registered
receipt numbers or turn generated payment PDFs into registered tax documents.

Deploy migration `202610180004_issued_payment_receipts.sql` and redeploy
`cloudinary-media-url` and `cloudinary-media-delete` before releasing the client.
Attached photos remain protected even when their receipt is voided.

Validation: `node tool/test_issued_payment_receipts.mjs`, Flutter receipt register
and history widget tests, and `_shared/cloudinary_test.ts` Deno tests.

Deployment update - October 18, 2026: migration `202610180004` was applied to the
connected sample-data project, and both media functions were redeployed. Live
receipt issuance/voiding validation was rolled back, leaving no diagnostic receipt
records. Source was pushed in `9ef871c`; client builds and physical-device photo/
printing checks remain. See [the session record](session-updates-2026-10-18.md).
