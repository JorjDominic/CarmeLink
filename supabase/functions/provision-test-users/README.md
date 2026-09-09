# Provision test users

Run the profiles migration first, then deploy this temporary function with JWT
verification disabled. Set a strong one-time `BOOTSTRAP_SECRET`, call the
function once with that value in the `x-bootstrap-secret` header, and delete the
function afterward. The Supabase service-role key stays inside the function and
must never be added to the Flutter app.

This one-time version provisions the caretaker account using
`CarmeLinkTest123!`:

- `caretaker@carmelita.test`
