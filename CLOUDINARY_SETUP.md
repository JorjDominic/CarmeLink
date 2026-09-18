# Secure Cloudinary setup

CarmeLink stores maintenance photos and payment receipts as Cloudinary
`authenticated` assets. Flutter never receives the Cloudinary API secret and
cannot upload directly to Cloudinary.

## Required Supabase secrets

```sh
supabase secrets set CLOUDINARY_CLOUD_NAME=your_cloud_name
supabase secrets set CLOUDINARY_API_KEY=your_api_key
supabase secrets set CLOUDINARY_API_SECRET=your_api_secret
```

Never put these values in Flutter, a committed `.env`, or an unsigned upload
preset.

## Deploy

```sh
supabase db push
supabase functions deploy cloudinary-media-upload
supabase functions deploy cloudinary-media-url
supabase functions deploy cloudinary-media-delete
```

Keep Supabase function JWT verification enabled. Do not use `--no-verify-jwt`.

## Security behavior

- Uploads accept only JPG, PNG, or WEBP images up to 5 MB.
- Upload authorization checks access to the target maintenance report or
  payment through RLS.
- Assets use Cloudinary's `authenticated` type; ordinary public URLs cannot
  display them.
- Existing tenant, linked guardian, caretaker, and owner RLS rules determine
  who can request a URL.
- Authorized private-download links expire after five minutes.
- Database rows store opaque `cloudinary://authenticated/...` references.
- Legacy Supabase Storage paths keep their existing signed-URL behavior.

## Verification

Test with separate tenant, guardian, caretaker, and owner accounts. Confirm an
unrelated tenant or guardian receives a forbidden response. Also verify that
replaced or deleted images are removed from Cloudinary.
