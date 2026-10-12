// Isolated PostgreSQL: no live database connection.
import { PGlite } from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db = new PGlite();
try {
  await db.exec(`create role anon; create role authenticated; create schema storage;
    create table storage.objects(bucket_id text,name text);
    create table public.tenant_contracts(id uuid primary key,status text,signature_status text);
    create table public.contract_documents(contract_id uuid,document_type text,version integer,review_status text,storage_path text);
    create table public.contract_signers(contract_id uuid,signer_role text,is_required boolean,status text);`);
  await db.exec(readFileSync('supabase/migrations/202610120002_signed_contract_activation.sql','utf8'));
  const id = '00000000-0000-0000-0000-000000000001';
  await db.query("insert into tenant_contracts values($1,'draft','not_generated')",[id]);
  await db.query("insert into contract_signers values($1,'tenant',true,'verified'),($1,'lessor',true,'verified')",[id]);
  await db.exec(`create trigger doc_sync after insert on contract_documents for each row execute function sync_contract_signature_status();`);
  await db.query("insert into contract_documents values($1,'generated',1,'not_required','original')",[id]);
  assert.equal((await db.query('select signature_status from tenant_contracts')).rows[0].signature_status,'verified');
  const activate = () => db.exec("update tenant_contracts set status='active'");
  await assert.rejects(activate,/signed contract copy before activation/);
  await db.query("insert into contract_documents values($1,'signed',1,'pending','signed')",[id]);
  await assert.rejects(activate,/signed contract copy before activation/);
  await db.exec("update contract_documents set review_status='verified' where document_type='signed'");
  await assert.rejects(activate,/signed contract copy before activation/);
  await db.exec("insert into storage.objects values('contract-documents','signed')");
  await db.exec("update contract_documents set version=2 where document_type='generated'");
  await assert.rejects(activate,/signed contract copy before activation/);
  await db.exec("update contract_documents set version=1 where document_type='generated'");
  await activate();
  assert.equal((await db.query('select status from tenant_contracts')).rows[0].status,'active');
  await db.exec("delete from storage.objects");
  await db.exec("update tenant_contracts set signature_status='verified'");
  assert.equal((await db.query('select status from tenant_contracts')).rows[0].status,'active');
  console.log('Passed: signature-first ordering, missing/pending/stale/deleted file guards, valid activation, existing lifecycle preservation.');
} finally { await db.close(); }
