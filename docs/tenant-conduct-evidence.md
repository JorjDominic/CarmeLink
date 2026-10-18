# Tenant conduct evidence

Tenant case details → Submit response, and eligible cases → Submit appeal, now
accept up to five optional JPG/PNG/WebP photos, each at most 5 MB, with captions.
Photos can be previewed and removed before submission. The statement and all
registered attachments commit together. Upload or save failures never silently
submit a statement without its selected photos. Retries preserve request IDs and
uploaded objects; uncertain responses freeze the payload until retried or closed.

Tenant photos use a separate private `tenant-conduct-evidence` bucket. Only the
affected tenant and authorized staff can read registered photos. Other tenants
and guardians cannot access them, and staff-only evidence remains private.
Captions, uploader, submission association and server timestamps are preserved.
Submitted metadata and objects cannot be edited, replaced or deleted. Detached
uploads can be cleaned up by their uploader when the request is known not to
have committed. Ambiguous requests preserve possible evidence.

Staff see these photos beside the corresponding response or appeal. Response
notifications reuse the existing saved-case producer; appeals notify staff from
the new transactional submission RPC. Repeated requests do not create duplicate
responses, appeals or alerts. Evidence does not decide the investigation or
automatically reverse outcomes.

Apply `202610180005_tenant_conduct_evidence.sql` before releasing the client.
The migration was applied to the connected sample-data project on 2026-10-18.
Live checks confirmed the submission RPC, private bucket and authenticated role
reads. No sample evidence or notification recipients were created by validation.
The updated client must be built/released separately.

Validation: disposable PostgreSQL role, Storage-metadata and transaction tests,
320 px and desktop Flutter widget tests, and analyzer. Physical-device photo
upload, viewing and notification delivery still require a walkthrough.
