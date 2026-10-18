import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';

export async function checkSystemMaintenance({db, ids, actor, check}) {
  const one = async (sql,args=[]) => (await db.query(sql,args)).rows[0];
  await db.exec('reset role');
  await db.exec(readFileSync('supabase/migrations/202610190002_repeat_violation_status.sql','utf8'));
  // Relevant option schema fixture; production uses the existing configuration table.
  await db.exec(`create table dormitory_options(id uuid primary key default gen_random_uuid(),
    group_key text not null,code text not null,label text not null check(length(label)>=2),
    category_code text,sort_order integer not null default 0,is_active boolean not null default true,
    is_system boolean not null default false,instructions text not null default '',unique(group_key,label));`);
  await db.exec(readFileSync('supabase/migrations/202610190003_system_maintenance.sql','utf8'));
  const tenant=randomUUID();
  await db.query("insert into profiles values($1,'tenant','Repeat fixture')",[tenant]);
  const add = async ({days=0,source=null,outcome='investigation_confirmed',status='under_review',published=true}={}) => {
    await actor('owner',false);
    const id=randomUUID();
    await db.query(`insert into conduct_cases(id,tenant_id,category,title,description,incident_at,status,
      opened_by,tenant_notified_at,source_module,source_record_id) values($1,$2,'rule_violation',
      'Repeat fixture','Documented fixture incident',now()-make_interval(days=>$3),$4,$5,
      case when $6 then now() end,$7,$8)`,[id,tenant,days,status,ids.owner,published,source?'curfew':'manual',source]);
    if(outcome) await db.query(`insert into conduct_case_events(case_id,event_type,actor_id,actor_name,notes)
      values($1,$2,$3,'Owner','Fixture outcome')`,[id,outcome,ids.owner]);
    await actor('owner');return id;
  };
  const status = async () => (await one('select get_tenant_conduct_status($1) s',[tenant])).s;
  await check('repeat status ignores allegations, warnings, drafts, dismissed and future incidents',async()=>{
    await add({outcome:null});await add({outcome:'warning_issued'});
    await add({status:'draft',published:false});await add({status:'dismissed'});await add({days:-1});
    assert.equal((await status()).status,'no_confirmed');
  });
  await check('two confirmed incidents flag repeated violations; duplicates count once',async()=>{
    const source=randomUUID();await add({days:100,source});await add({days:1,source});
    assert.equal((await status()).confirmed,1);assert.equal((await status()).recent_confirmed,0);
    await add({days:91});assert.equal((await status()).status,'repeated_violations');
  });
  let recent;
  await check('three incidents within 90 days flag continuous violations',async()=>{
    await add({days:89});await add({days:4});recent=await add({days:1});
    const s=await status();assert.equal(s.status,'continuous_violations');assert.equal(s.recent_confirmed,3);
    const detail=(await one('select get_conduct_investigation($1) s',[recent])).s;
    assert.equal(detail.tenant_status.status,s.status);
  });
  await check('overturned and dismissed incidents immediately remove continuous flag',async()=>{
    await actor('owner',false);
    await db.query(`insert into conduct_case_events(case_id,event_type,actor_id,actor_name,notes,created_at)
      values($1,'investigation_overturned',$2,'Owner','Fixture correction',clock_timestamp()+interval '1 second')`,[recent,ids.owner]);
    await actor('owner');assert.equal((await status()).status,'repeated_violations');
  });
  await check('conduct status enforces tenant isolation, guardian denial and staff-only list',async()=>{
    for(const role of ['tenant','guardian','missing']) {
      await actor(role);await assert.rejects(db.query('select get_tenant_conduct_status($1)',[tenant]),/not available/);
      await assert.rejects(db.query('select get_tenant_conduct_status(null)'),/not available/);
      await assert.rejects(db.query('select list_conduct_tenant_statuses()'),/Staff access/);
    }
    await actor('missing');await assert.rejects(db.query('select get_tenant_conduct_status($1)',[ids.missing]),/not available/);
    await db.exec('reset role');await db.query("select set_config('test.actor',$1,false)",[tenant]);await db.exec('set role authenticated');
    assert.equal((await status()).tenant_id,tenant);
    for(const role of ['owner','caretaker']) {await actor(role);assert.ok((await db.query('select list_conduct_tenant_statuses(0,200)')).rows.length>0);}
  });
  await check('maintenance mode is owner-only, version checked and audited',async()=>{
    await actor('owner');const s=await one('select * from system_maintenance_settings');
    await db.query("select set_system_maintenance(true,'Scheduled maintenance',$1)",[s.updated_at]);
    await assert.rejects(db.query("select set_system_maintenance(false,'Scheduled maintenance',$1)",[s.updated_at]),/Settings changed/);
    for(const role of ['caretaker','tenant','guardian']) {
      await actor(role);assert.equal((await one('select * from system_maintenance_settings')).enabled,true);
      await assert.rejects(db.query("select set_system_maintenance(false,'Unauthorized change',now())"),/Only owners/);
      assert.equal((await db.query('select * from system_configuration_backups')).rows.length,0);
    }
    await actor('caretaker');assert.equal((await db.query('select * from system_maintenance_audit')).rows.length,1);
    await actor('tenant');assert.equal((await db.query('select * from system_maintenance_audit')).rows.length,0);
    await assert.rejects(db.exec('update system_maintenance_settings set enabled=false'),/permission denied/);
  });
  await check('configuration restore recovers saved values and creates a safety snapshot',async()=>{
    await actor('owner',false);
    await db.exec("insert into dormitory_options(group_key,code,label) values('common_area','garden','Garden')");
    await actor('owner');const id=(await one('select create_system_configuration_backup() id')).id;
    await actor('owner',false);await db.exec("update dormitory_options set label='Changed',is_active=false");
    await actor('owner');await db.query('select restore_system_configuration_backup($1)',[id]);
    await actor('owner',false);const restored=await one('select * from dormitory_options');
    assert.equal(restored.label,'Garden');assert.equal(restored.is_active,true);
    assert.equal(Number((await one('select count(*) n from system_configuration_backups')).n),2);
    await actor('caretaker');await assert.rejects(db.query('select restore_system_configuration_backup($1)',[id]),/Only owners/);
    await assert.rejects(db.query('select create_system_configuration_backup()'),/Only owners/);
    await actor('owner');await assert.rejects(db.exec('delete from system_configuration_backups'),/permission denied/);
  });
  await check('failed restore rolls back its safety backup and leaves current configuration intact',async()=>{
    await actor('owner');const id=(await one('select create_system_configuration_backup() id')).id;
    await actor('owner',false);await db.exec("update dormitory_options set code='changed-identity',label='Keep current'");
    const before=Number((await one('select count(*) n from system_configuration_backups')).n);
    await actor('owner');await assert.rejects(db.query('select restore_system_configuration_backup($1)',[id]),/identity changed/);
    await actor('owner',false);
    assert.equal((await one('select label from dormitory_options')).label,'Keep current');
    assert.equal(Number((await one('select count(*) n from system_configuration_backups')).n),before);
  });
}
