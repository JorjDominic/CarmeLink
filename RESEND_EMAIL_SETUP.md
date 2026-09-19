# Resend email verification setup

The app sends account-verification links from the `create-user` Supabase Edge
Function. The Resend API key must never be placed in Flutter code, `pubspec`, or
any committed file.

## Production secrets

In the Supabase Dashboard, open **Edge Functions > Secrets** and add:

- `RESEND_API_KEY` — the API key created in Resend.
- `RESEND_FROM_EMAIL` — for example,
  `CarmeLink <onboarding@mail.yourdomain.com>`. The domain must be verified in
  Resend before production sending.
- `APP_INVITE_REDIRECT_URL` — optional onboarding URL opened after Supabase
  confirms the link. Add the same URL under **Authentication > URL
  Configuration > Redirect URLs** in Supabase.

Alternatively, from an already linked Supabase CLI project:

```powershell
supabase secrets set RESEND_API_KEY=re_replace_me
supabase secrets set "RESEND_FROM_EMAIL=CarmeLink <onboarding@mail.yourdomain.com>"
supabase secrets set APP_INVITE_REDIRECT_URL=https://your-app.example/onboarding
```

Then deploy the updated function:

```powershell
supabase functions deploy create-user
supabase functions deploy manage-user
```

For local development, copy `supabase/functions/.env.example` to
`supabase/functions/.env` and replace the placeholders. The real `.env` path is
gitignored.

## Current verification behavior

- A new account starts with email verification Pending.
- Supabase generates the signed, expiring confirmation URL.
- Resend delivers the URL; the API key never reaches the mobile app.
- After confirmation and sign-in, the app synchronizes the verified timestamp.
- Account Management also reconciles the timestamp from Supabase Auth.
- Staff can resend verification after a 60-second cooldown, up to five times
  per rolling 24-hour window.
- A tenant contract cannot transition to Active until email is verified.
- SMS fields display On hold. No OTP is generated and phone verification is not
  currently enforced.
