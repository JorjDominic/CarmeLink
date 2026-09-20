# Resend email verification setup

The app sends account-verification links from the `create-user` Supabase Edge
Function. The Resend API key must never be placed in Flutter code, `pubspec`, or
any committed file.

## Production secrets

In the Supabase Dashboard, open **Edge Functions > Secrets** and add:

- `RESEND_API_KEY` — the API key created in Resend.
- `RESEND_FROM_EMAIL` — for example,
  `CarmeLink <noreply@carmelitasdormitory.site>`. The
  `carmelitasdormitory.site` domain must be verified in Resend before
  production sending.
- `APP_INVITE_REDIRECT_URL` — optional onboarding URL opened after Supabase
  confirms the link. Add the same URL under **Authentication > URL
  Configuration > Redirect URLs** in Supabase. The production URL is
  `https://carmelitasdormitory.site/onboarding`.

Alternatively, from an already linked Supabase CLI project:

```powershell
supabase secrets set RESEND_API_KEY=re_replace_me
supabase secrets set "RESEND_FROM_EMAIL=CarmeLink <noreply@carmelitasdormitory.site>"
supabase secrets set APP_INVITE_REDIRECT_URL=https://carmelitasdormitory.site/onboarding
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

## Password-recovery email

Password recovery uses Supabase Auth's mailer and redirects successful links to
`https://carmelitasdormitory.site/reset-password`. Add that exact URL under **Supabase
Dashboard > Authentication > URL Configuration > Redirect URLs**.

To send recovery messages through the verified Resend domain, enable custom
SMTP under **Authentication > Email > SMTP Settings** and enter:

- Host: `smtp.resend.com`
- Port: `465` (SSL) or `587` (STARTTLS)
- Username: `resend`
- Password: the Resend API key
- Sender email: `noreply@carmelitasdormitory.site`
- Sender name: `CarmeLink`

The deployed web app must serve the Flutter entry point at `/reset-password`
(or rewrite that path to `/index.html`). Opening the emailed link establishes a
short-lived recovery session; CarmeLink then shows the new-password form and
updates the password through Supabase Auth.

For a local browser test, also allow
`http://localhost:7357/reset-password` in Supabase Redirect URLs, then run:

```powershell
flutter run -d chrome --web-port 7357 --dart-define=PASSWORD_RECOVERY_REDIRECT_URL=http://localhost:7357/reset-password
```

Production builds use `https://carmelitasdormitory.site/reset-password`
automatically.
