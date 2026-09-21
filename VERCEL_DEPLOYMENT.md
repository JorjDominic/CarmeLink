# Vercel deployment

CarmeLink's public website and staff portal can be hosted as a static Flutter
web application on Vercel. The tenant and guardian mobile applications remain
separate, and native background geofencing is not available in a browser.

## Deploy from Git

1. Push this repository to GitHub, GitLab, or Bitbucket.
2. In Vercel, create a project and import the repository.
3. Leave **Framework Preset** as `Other`.
4. Leave the build command and output directory overrides empty. Vercel reads
   both values from `vercel.json`.
5. Deploy the project.

The first build downloads the pinned Flutter SDK and can take several minutes.
Vercel then serves `build/web`. The filesystem-first route configuration keeps
static assets working and sends application routes such as `/staff` and
`/reset-password` to Flutter's `index.html`.

## Domain and Supabase settings

Attach `carmelitasdormitory.site` to the Vercel project before production use.
In **Supabase Dashboard > Authentication > URL Configuration**:

- Set the Site URL to `https://carmelitasdormitory.site`.
- Add `https://carmelitasdormitory.site/reset-password` to Redirect URLs.
- Add the exact Vercel preview redirect URL only when preview authentication is
  needed. Avoid a broad wildcard for production authentication.

The application already defaults password recovery to the production domain.
For a preview deployment, set this Vercel build-time environment variable:

```text
PASSWORD_RECOVERY_REDIRECT_URL=https://your-preview-domain.vercel.app/reset-password
```

Because this is a Dart compile-time value, redeploy after changing it.

## Optional Flutter upgrade

The build uses Flutter `3.44.8`. To test another version without editing the
script, define `FLUTTER_VERSION` in the Vercel project settings and redeploy.
Pin the tested version for production instead of tracking the moving `stable`
branch.

## Local verification

```bash
flutter pub get
flutter build web --release --target lib/main_web.dart
```

Serve `build/web` with a static server that falls back unknown routes to
`index.html`. Opening `/`, `/staff`, and `/reset-password` directly should all
load the application.
