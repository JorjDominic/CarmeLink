import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {readFileSync} from 'node:fs';

export async function checkReportSubjects({db,ids,actor,check}) {
  const one=async(sql,args=[])=>(await db.query(sql,args)).rows[0];
  await actor('owner',false);
  await db.exec(`create table tenant_details(profile_id uuid primary key references profiles,residency_status text);
    create function require_module_agreement(text) returns void language plpgsql as $$begin
      if current_setting('test.agreement',true) is distinct from 'accepted' then raise exception 'Agreement required';end if;
    end $$;`);
  await db.exec(readFileSync('supabase/migrations/202610190004_confidential_report_subject.sql','utf8'));
  const inactive=randomUUID();
  await db.query("insert into profiles values($1,'tenant','Inactive fixture')",[inactive]);
  await db.query("insert into tenant_details values($1,'inactive')",[inactive]);
  await db.exec("select set_config('test.agreement','accepted',false)");
  let reportId;
  const submit=async(subject=ids.other,name='Forged name')=>one(`insert into confidential_reports(
    tenant_id,category,summary,reported_tenant_id,reported_tenant_name)
    values($1,'safety_concern','A documented concern for staff review',$2,$3) returning *`,[ids.tenant,subject,name]);
  await check('reporter and reported tenant are separate; subject name is a trusted snapshot',async()=>{
    await actor('tenant');const r=await submit();reportId=r.id;
    assert.equal(r.tenant_id,ids.tenant);assert.equal(r.reported_tenant_id,ids.other);assert.equal(r.reported_tenant_name,'other');
  });
  await check('tenant links are optional and invalid, self, inactive and staff targets are rejected',async()=>{
    await actor('tenant');assert.equal((await submit(null)).reported_tenant_name,null);
    for(const subject of [ids.tenant,ids.owner,inactive,randomUUID()]) await assert.rejects(submit(subject));
  });
  await check('being named does not grant report access, including to other tenants or guardians',async()=>{
    for(const role of ['other','guardian']) {await actor(role);assert.equal((await db.query('select id from confidential_reports where id=$1',[reportId])).rows.length,0);}
    await actor('tenant');assert.equal((await db.query('select id from confidential_reports where id=$1',[reportId])).rows.length,1);
  });
  await check('tenant search returns only names and IDs, excludes self and inactive accounts, and validates queries',async()=>{
    await actor('tenant');const rows=(await db.query("select * from search_reportable_tenants('other')")).rows;
    assert.deepEqual(rows,[{id:ids.other,display_name:'other'}]);
    assert.equal((await db.query("select * from search_reportable_tenants('tenant')")).rows.length,0);
    assert.equal((await db.query("select * from search_reportable_tenants('Inactive')")).rows.length,0);
    await assert.rejects(db.query("select * from search_reportable_tenants('')"));
    await assert.rejects(db.query("select * from search_reportable_tenants('a')"));
    for(const role of ['guardian',null]) {await actor(role);await assert.rejects(db.query("select * from search_reportable_tenants('other')"));}
    await actor('tenant');await db.exec("select set_config('test.agreement','missing',false)");
    await assert.rejects(db.query("select * from search_reportable_tenants('other')"),/Agreement required/);
    await db.exec("select set_config('test.agreement','accepted',false)");
  });
  await check('subject links and names are immutable during staff review and cannot be forged on update',async()=>{
    await actor('owner',false);
    await assert.rejects(db.query('update confidential_reports set reported_tenant_id=$1 where id=$2',[ids.owner,reportId]),/cannot be changed/);
    await assert.rejects(db.query("update confidential_reports set reported_tenant_name='Forged' where id=$1",[reportId]),/cannot be changed/);
    await db.query("update confidential_reports set status='under_review' where id=$1",[reportId]);
    assert.equal((await one('select reported_tenant_name from confidential_reports where id=$1',[reportId])).reported_tenant_name,'other');
  });
  await check('audited confidential source picker uses subject, hides reporter/text and rejects tenant access',async()=>{
    for(const role of ['owner','caretaker']) {
      await actor(role);
      const rows=(await db.query('select * from list_conduct_confidential_sources($1)',[ids.other])).rows;
      assert.ok(rows.some(r=>r.id===reportId));assert.deepEqual(Object.keys(rows[0]).sort(),['category','created_at','id']);
      assert.equal((await db.query('select * from list_conduct_confidential_sources($1)',[ids.tenant])).rows.length,0);
      assert.ok(Array.isArray((await one('select list_confidential_reports_v2() reports')).reports));
    }
    await actor('tenant');await assert.rejects(db.query('select * from list_conduct_confidential_sources($1)',[ids.other]),/Staff access/);
  });
  await check('case creation links to reported tenant and rejects reporter or unrelated tenant',async()=>{
    await actor('owner');
    const create=tenant=>one("select create_conduct_case($1,'Curfew','Reviewed allegation','Staff reviewed allegation without reporter details',now(),'confidential_report',$2) id",[tenant,reportId]);
    assert.ok((await create(ids.other)).id);
    await assert.rejects(create(ids.tenant),/does not belong/);
    await actor('caretaker');assert.ok((await create(ids.other)).id);
    await actor('tenant');await assert.rejects(create(ids.other),/Only owners and caretakers/);
  });
}
