// Disposable PostgreSQL only. No deployed database or real tenant records.
import { PGlite } from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { randomUUID } from 'node:crypto';
import assert from 'node:assert/strict';
import { bootstrapRoomCapacity, source, actor, owner, approve } from './room_capacity_occupancy_fixture.mjs';

const db = new PGlite();
const one = async (sql, args = []) => (await db.query(sql, args)).rows[0];
const fn = (file, name) => {
  const sql = source(file), start = sql.indexOf(`create or replace function public.${name}(`);
  assert.ok(start >= 0);
  return sql.slice(start, sql.indexOf('$$;', sql.indexOf('as $$', start)) + 3);
};
let passed = 0;
const check = async (name, run) => { await run(); console.log(`PASS ${++passed}: ${name}`); };
const contract = id => one('select * from tenant_contracts where id=$1', [id]);
const deposit = id => one('select * from security_deposit_receipts where contract_id=$1', [id]);
const renew = async (id, future = false) => (await one(`select renew_tenant_contract($1,
  (now() at time zone 'Asia/Manila')::date + $2::int,
  (now() at time zone 'Asia/Manila')::date + 365,3200,'Agreed renewal') id`, [id, future ? 31 : 0])).id;
const prepare = async (mode, count = 1, future = false) => {
  const room = (await one("select create_room_with_capacity($1,'Ground') id", [randomUUID()])).id;
  const beds = (await db.query('select id from bed_spaces where room_id=$1 order by label', [room])).rows;
  const members = [];
  for (let i = 0; i < count; i++) {
    const tenant = randomUUID();
    await db.query("insert into profiles values($1,'tenant','Resident',now())", [tenant]);
    await db.query('insert into tenant_details(profile_id) values($1)', [tenant]);
    members.push({ tenant_id: tenant, bed_id: beds[i].id, security_deposit: 1000, monthly_rent: 2500 });
  }
  const ids = (await one(`select prepare_contract_occupancy($1,$2,5000,$3::jsonb,
    (now() at time zone 'Asia/Manila')::date-61,
    (now() at time zone 'Asia/Manila')::date+$4::int) ids`, [room, mode, JSON.stringify(members), future ? 30 : -1])).ids;
  for (const id of ids) {
    await approve(db, id);
    await db.query('select activate_tenant_contract($1)', [id]);
  }
  return { room, ids, members };
};

try {
  await bootstrapRoomCapacity(db, { randomUUID });
  const receipts = source('202610040002_separate_security_deposit_receipts.sql');
  await db.exec(receipts.slice(0, receipts.indexOf('-- Backfill')) + '\ncommit;');
  await db.exec(`alter table security_deposit_receipts add column transferred_to_contract_id uuid;
    alter table move_out_cases add column id uuid default gen_random_uuid();
    create table move_out_settlements(case_id uuid,deposit_received_amount numeric,updated_by uuid,refund_status text);
    create table payment_transactions(charge_id uuid,status text);
    create table legacy_security_deposit_links(charge_id uuid);
    create function refresh_move_out_settlement(uuid) returns void language sql as $$select$$;`);
  await db.exec(fn('202610080002_contract_deposit_auto_receipt.sql', 'initialize_contract_deposit_receipt'));
  for (const name of ['receive_deposit_on_contract_creation', 'guard_renewal_deposit_receipt', 'transfer_renewal_deposit']) {
    await db.exec(fn('202610090004_contract_renewals.sql', name));
  }
  await db.exec(`create trigger receive_contract_deposit after insert on tenant_contracts for each row execute function receive_deposit_on_contract_creation();
    create trigger renewal_deposit_guard before insert or update on security_deposit_receipts for each row execute function guard_renewal_deposit_receipt();
    create trigger renewal_deposit_transfer after update of status on tenant_contracts for each row execute function transfer_renewal_deposit();
    create unique index tenant_contracts_one_live_renewal on tenant_contracts(previous_contract_id) where previous_contract_id is not null and status<>'terminated';`);
  await db.exec(source('202610190006_occupancy_contract_renewals.sql'));

  for (const mode of ['solo', 'standard_shared']) {
    await check(`${mode}: same-bed renewal preserves history, signatures, billing and deposit carryover`, async () => {
      const prepared = await prepare(mode, mode === 'solo' ? 1 : 2);
      const old = await contract(prepared.ids[0]);
      const roommate = mode === 'standard_shared' ? await contract(prepared.ids[1]) : null;
      const charges = (await db.query('select * from billing_charges where contract_id=$1 order by id', [old.id])).rows;
      const next = await renew(old.id);
      assert.equal(await renew(old.id), next, 'retry returns the same renewal');
      const draft = await contract(next);
      const roomBeforeActivation = (await one('select get_room_contract_occupancies($1) groups', [prepared.room])).groups;
      assert.equal(roomBeforeActivation[0].members.find(m => m.tenant_id === old.tenant_id).contract_id, old.id);
      assert.equal(draft.occupancy_id, old.occupancy_id);
      assert.equal(draft.previous_contract_id, old.id);
      assert.equal(draft.status, 'draft');
      assert.equal(draft.monthly_rent, '3200.00');
      assert.equal((await deposit(next)).received_amount, '0.00');
      assert.equal((await deposit(old.id)).received_amount, '1000.00');
      assert.deepEqual(await contract(old.id), old);
      await assert.rejects(db.query('select activate_tenant_contract($1)', [next]), /signed|sign|Signature|document/i);
      await approve(db, next);
      await db.query('select activate_tenant_contract($1)', [next]);
      assert.equal((await contract(old.id)).status, 'expired');
      assert.equal((await contract(next)).status, 'active');
      assert.deepEqual((await contract(old.id)).occupancy_snapshot, old.occupancy_snapshot);
      assert.deepEqual((await db.query('select * from billing_charges where contract_id=$1 order by id', [old.id])).rows, charges);
      assert.ok((await db.query('select * from billing_charges where contract_id=$1', [next])).rows.every(c => Number(c.original_amount) === 3200));
      assert.equal((await deposit(next)).received_amount, '1000.00');
      assert.equal((await deposit(old.id)).received_amount, '0.00');
      assert.equal((await deposit(old.id)).transferred_to_contract_id, next);
      assert.equal((await one("select count(*)::int n from tenant_assignments where tenant_id=$1 and status='active'", [old.tenant_id])).n, 1);
      if (roommate) assert.deepEqual(await contract(roommate.id), roommate);
      const projection = (await one('select get_room_contract_occupancies($1) groups', [prepared.room])).groups;
      assert.equal(projection[0].members.length, prepared.ids.length);
      assert.equal(projection[0].members.find(m => m.tenant_id === old.tenant_id).contract_id, next);
      if (mode === 'solo') {
        assert.equal(Number(projection[0].total_rent_cents), 320000);
        assert.equal(projection[0].starts_on, (await one('select starts_on::text d from tenant_contracts where id=$1', [next])).d);
      }
      await assert.rejects(renew(old.id), /already has a renewal/);
      await assert.rejects(db.query('update tenant_contracts set monthly_rent=4000 where id=$1', [old.id]), /immutable|terms/);
      const second = (await one(`select renew_tenant_contract($1,
        (select ends_on+1 from tenant_contracts where id=$1),
        (select ends_on+366 from tenant_contracts where id=$1),3500,null) id`, [next])).id;
      assert.equal((await contract(second)).previous_contract_id, next);
      assert.equal((await contract(second)).occupancy_id, old.occupancy_id);
    });
  }
  await check('future renewal drafts remain available but cannot activate before the new term', async () => {
    const { ids } = await prepare('solo', 1, true);
    const next = await renew(ids[0], true);
    await approve(db, next);
    await assert.rejects(db.query('select activate_tenant_contract($1)', [next]), /on or after/);
    assert.equal((await contract(ids[0])).status, 'active');
  });
  await check('expired contracts renew, and move-out cases block renewal', async () => {
    const { ids } = await prepare('solo');
    await db.query("update tenant_contracts set status='expired' where id=$1", [ids[0]]);
    await db.query("insert into move_out_cases(contract_id,status) values($1,'notice_submitted')", [ids[0]]);
    await assert.rejects(renew(ids[0]), /move-out/);
    await db.query('delete from move_out_cases where contract_id=$1', [ids[0]]);
    assert.equal((await contract(await renew(ids[0]))).status, 'draft');
  });
  await check('released rooms, departed tenants and exclusive group leases cannot use individual renewal', async () => {
    const { ids, members } = await prepare('solo');
    await db.query("update tenant_assignments set status='ended' where tenant_id=$1", [members[0].tenant_id]);
    await assert.rejects(renew(ids[0]), /active bed assignment/);
    await db.query("update tenant_contracts set status='expired' where id=$1", [ids[0]]);
    await assert.rejects(renew(ids[0]), /released/);
    const shared = await prepare('shared', 2);
    await assert.rejects(renew(shared.ids[0]), /group amendment/);
  });
  await check('caretakers and tenants cannot create renewals', async () => {
    const { ids, members } = await prepare('solo');
    for (const who of ['00000000-0000-0000-0000-000000000002', members[0].tenant_id]) {
      await actor(db, who);
      await assert.rejects(renew(ids[0]), /Owner access/);
    }
    await actor(db, owner);
  });
  await check('direct writes cannot forge occupancy snapshots or change the resident’s bed', async () => {
    const { ids } = await prepare('solo');
    const old = await contract(ids[0]);
    const forged = structuredClone(old.occupancy_snapshot);
    forged.members[0].bed_id = randomUUID();
    await assert.rejects(db.query(`insert into tenant_contracts(tenant_id,starts_on,ends_on,monthly_rent,
      security_deposit,previous_contract_id,occupancy_id,occupancy_snapshot)
      select tenant_id,ends_on+1,ends_on+366,3200,security_deposit,id,occupancy_id,$2::jsonb
      from tenant_contracts where id=$1`, [old.id, JSON.stringify(forged)]), /confirmed occupancy terms/);
    const next = await renew(old.id);
    await assert.rejects(db.query("update tenant_contracts set occupancy_snapshot=occupancy_snapshot||'{\"room_number\":\"Changed\"}'::jsonb where id=$1", [next]), /snapshots cannot/);
  });
  console.log(`${passed} occupancy renewal scenarios passed.`);
} catch (error) {
  console.error(error.message, error.where ?? '', error.stack?.split('\n').slice(1, 4).join('\n'));
  process.exitCode = 1;
} finally { await db.close(); }
