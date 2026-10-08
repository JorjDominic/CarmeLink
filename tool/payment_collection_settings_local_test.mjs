// Runs against an isolated PostgreSQL instance; no live payment settings change.
// node tool/payment_collection_settings_local_test.mjs <pglite/dist/index.js>
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import assert from 'node:assert/strict';
const { PGlite } = await import(pathToFileURL(process.argv[2]).href);
const db = new PGlite();
const owner = '00000000-0000-0000-0000-000000000001';
const caretaker = '00000000-0000-0000-0000-000000000002';
const login = (user, role) => db.query(
  "select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claim.role',$2,false)", [user, role]);
const setMode = mode => db.query('select public.set_payment_collection_mode($1) as settings', [mode]);
try {
  await db.exec(`
    create role authenticated; create role anon; create schema auth;
    create function auth.uid() returns uuid language sql as $$
      select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    create function public.current_user_role() returns text language sql as $$
      select current_setting('request.jwt.claim.role',true) $$;
    create table public.profiles(id uuid primary key);
    insert into public.profiles values('${owner}'),('${caretaker}');
  `);
  await db.exec(await readFile('supabase/migrations/202610080003_owner_payment_mode.sql', 'utf8'));
  assert.equal((await db.query('select mode,maya_ready from public.payment_collection_settings')).rows[0].mode, 'manual');
  for (const role of ['caretaker', 'tenant', 'guardian', '']) {
    await login(caretaker, role);
    await assert.rejects(() => setMode('manual'), /Only the owner/);
  }
  await login('', 'owner');
  await assert.rejects(() => setMode('manual'), /Only the owner/);
  await login(owner, 'owner');
  await assert.rejects(() => setMode('invalid'), /Choose manual or Maya/);
  await assert.rejects(() => setMode(null), /Choose manual or Maya/);
  await assert.rejects(() => setMode('maya'), /not connected yet/);
  await setMode('manual');
  assert.equal((await db.query('select count(*)::int as n from public.payment_collection_settings_history')).rows[0].n, 0);
  // Even an owner JWT cannot write readiness or bypass the privileged RPC.
  await db.exec('set role authenticated');
  assert.equal((await db.query('select mode from public.payment_collection_settings')).rows[0].mode, 'manual');
  await assert.rejects(() => db.exec('update public.payment_collection_settings set maya_ready=true'), /permission denied/);
  await assert.rejects(() => db.exec("insert into public.payment_collection_settings_history(previous_mode,new_mode,changed_by) values('manual','maya','" + owner + "')"), /permission denied/);
  await db.exec('reset role');
  // Simulate a future trusted backend rollout in this isolated fixture only.
  await db.exec('update public.payment_collection_settings set maya_ready=true');
  await setMode('maya');
  await setMode('maya');
  await setMode('manual');
  const changes = (await db.query('select previous_mode,new_mode,changed_by from public.payment_collection_settings_history order by id')).rows;
  assert.equal(changes.length, 2);
  assert.equal(changes[0].changed_by, owner);
  assert.equal(changes[0].previous_mode, 'manual');
  assert.equal(changes[1].new_mode, 'manual');
  await login(caretaker, 'caretaker');
  await db.exec('set role authenticated');
  assert.equal((await db.query('select * from public.payment_collection_settings_history')).rows.length, 0);
  await assert.rejects(() => setMode('maya'), /Only the owner/);
  console.log('Payment mode SQL checks passed: safe default, owner-only RPC, RLS, readiness guard, validation and audit history.');
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally {
  await db.close();
}
