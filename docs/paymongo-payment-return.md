# Returning from payment to CarmeLink

The public return page is
`https://carmelitasdormitory.site/payment/return?session_id=<request-uuid>`.
It offers **Return to CarmeLink**, opening
`carmelink://payment-return?session_id=<request-uuid>`. The page shows no private
payment details and does not claim a successful payment. Invalid or duplicate
session parameters disable navigation; the launcher has a manual-app fallback.

The mobile app queues valid payment links until the tenant is signed in and
existing onboarding/access checks allow entry. It resolves that session through
the authenticated payment gateway; RLS and provider verification remain
authoritative. Another account's request fails without displaying its contents.
Changing accounts or losing tenant access hides the opened payment screen.
Duplicate links to an already opened return screen do not stack more copies.
Existing onboarding links remain supported.

When the payment screen resumes after the browser or wallet app, it checks the
existing request immediately. A resume while another request is busy queues one
follow-up check. It never creates another payment simply because the app resumed.
Demo previews remain local. Confirmation, processing, failures and receipts use
the existing gateway flow, not status/amount flags supplied in a return URL.

Android registers the new payment-return host. iOS already registers the
`carmelink` URL scheme. Both platforms delegate deep links to the existing
`app_links` handler instead of also letting Flutter create an implicit route.
The website registers the public return route independently of staff sign-in and
supports direct-path and Flutter hash URLs. Existing Vercel rewrites route the
HTTPS page to the Flutter web application.

New Payment Method attachments include the canonical HTTPS `return_url`. Existing
requests retain their original provider configuration. This does not migrate to
Hosted Checkout or require new keys, a new webhook, or a dashboard change.
The QR simulator/banking app may ignore a redirect URL; it cannot be forced to
reopen CarmeLink. Switching back manually triggers the resume verification.

## Release sequence and limits

1. Build/publish the website with `lib/main_web.dart` so `/payment/return` exists.
2. Release the updated Android/iOS app for the payment link and resume behavior.
3. Deploy `paymongo-payments` and `reconcile-paymongo-payments`, which package the
   updated attachment helper, before creating requests that need a return URL.
   Redeploying `paymongo-webhook` alongside them keeps the shared bundle aligned.
4. Verify actual-device cold start, logged-out sign-in, warm return, unsupported
   app/browser fallback, and provider/simulator redirect behavior. A simulator
   that does not redirect requires manual app switching; do not claim automatic
   QR redirection based only on the configured URL.

Automated checks cover strict link parsing, public-page rendering/launch/fallback,
authenticated gateway failure/retry, resume and busy-resume behavior, payment and
receipt regressions, and the provider attachment's fixed return URL. iOS build
and actual-device/browser redirect acceptance require the corresponding devices.

Local validation: 23 payment/link/return/receipt Flutter tests and the recovery
regression checks passed, along with 20 provider/webhook tests and changed-source
analysis. The web release build and Android manifest-processing task passed;
the iOS plist was parsed and its URL-scheme settings checked. Source changes are
not yet released: publish the website/app and deploy the attachment helper in the
sequence above before relying on provider return links in the live demo.

Provider reference: [Payment Intent return URLs](https://docs.paymongo.com/docs/payment-acceptance-quick-start).
That example documents a redirect-based payment method; it does not establish
that the QR simulator supports the same navigation behavior.
