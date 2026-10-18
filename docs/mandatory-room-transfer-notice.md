# Mandatory room transfer notice

The tenant dashboard and My Room display a persistent card for published pending
room transfers, including destination, effective date, reason and review link.
It remains visible after acknowledgment while signatures are pending. Draft,
cancelled and completed transfers do not appear on this card. Read failures show
a retry state rather than claiming that no transfer exists.

The moving tenant reviews the amendment PDF, explicitly acknowledges the notice,
then signs. The acknowledgment records the tenant, server time and exact document
hash. Owners, caretakers and guardians cannot acknowledge on their behalf. The
backend blocks transfer completion without this acknowledgment, in addition to
the existing required verified signatures, effective date and assignment checks.
Acknowledgment does not replace a signature. Current room assignments remain
active until completion. Existing completed transfers are retained unchanged;
pending transfers require acknowledgment. Other modules remain accessible.


Apply `202610180006_room_transfer_notice_acknowledgment.sql` before releasing the
client. The migration was applied to the connected sample-data project on
2026-10-18. Live checks confirmed the acknowledgment RPC and authenticated role
reads. No acknowledgments were created by validation. The updated client must be
built/released separately.

No additional Edge Function is needed. Existing published-transfer notices still
go through in-app notifications and the push queue to the tenant/linked guardian.

Validation: disposable PostgreSQL role, completion and immutable-history tests,
320 px and desktop Flutter widget tests, transfer service tests and analyzer.
A physical-device amendment review, signature and FCM walkthrough remains.
