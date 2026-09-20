# Resend email verification setup

The `create-user` Edge Function creates an unverified account without sending
an email. After the user attempts to sign in, CarmeLink shows the verification
screen and sends a code only when the user selects **Send code**.

Deploy the account functions after changes:

```powershell
supabase functions deploy create-user
supabase functions deploy manage-user
```

## Current verification behavior

- A new account starts with email verification Pending.
- Account creation does not send an email or consume an email rate-limit slot.
- After an unverified sign-in, the verification screen remains visible until
  verification succeeds or the user chooses a different account.
- Selecting **Send code** asks Supabase Auth to generate and deliver a
  six-digit, expiring, single-use signup OTP.
- The user enters the OTP in CarmeLink, which confirms the email and
  synchronizes the verified timestamp.
- Account Management also reconciles the timestamp from Supabase Auth.
- Staff can resend verification after a 60-second cooldown, up to five times
  per rolling 24-hour window.
- A tenant contract cannot transition to Active until email is verified.
- SMS fields display On hold. No OTP is generated and phone verification is not
  currently enforced.

## Password-recovery email

Password recovery uses the same six-digit, code-only experience through
Supabase Auth's mailer. Entering an email does not send immediately; the user
must select **Send code**, after which the 60-second resend cooldown applies.

To send verification and recovery messages through the verified Resend domain,
enable custom SMTP under **Authentication > Email > SMTP Settings** and enter:

- Host: `smtp.resend.com`
- Port: `465` (SSL) or `587` (STARTTLS)
- Username: `resend`
- Password: the Resend API key
- Sender email: `noreply@carmelitasdormitory.site`
- Sender name: `CarmeLink`

Deploy the confirmation and recovery email templates with the Supabase project
configuration so neither message contains a browser URL.
