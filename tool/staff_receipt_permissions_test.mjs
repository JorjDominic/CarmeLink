// Exercise the real attachment policy with fake database responses; no network.
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import assert from 'node:assert/strict';
const source=(await readFile('supabase/functions/_shared/cloudinary.ts','utf8'))
  .replace(/^import .*supabase-js.*\r?\n/m,'');
const js=stripTypeScriptTypes(source);
const {canAttachRecord}=await import(`data:text/javascript;base64,${Buffer.from(js).toString('base64')}`);
const caller=(role,category='rent',owned=false,exists=true)=>({
  from(table) {
    const filters={};
    const result=()=> table==='profiles'
      ? {data:{role},error:null}
      : filters.tenant_id ? {data:owned?[{id:'bill'}]:[],error:null}
      : {data:exists?{id:'bill',category}:null,error:null};
    const query={select(){return query},eq(key,value){filters[key]=value;return query},
      limit(){return Promise.resolve(result())},single(){return Promise.resolve(result())}};
    return query;
  },
});
for(const role of ['owner','caretaker']) {
  assert.equal(await canAttachRecord(caller(role),'payment','bill','staff'),true);
  assert.equal(await canAttachRecord(caller(role,'deposit'),'payment','bill','staff'),false);
  assert.equal(await canAttachRecord(caller(role,'rent',false,false),'payment','bill','staff'),false);
  assert.equal(await canAttachRecord(caller(role),'maintenance','report','staff'),false);
}
assert.equal(await canAttachRecord(caller('guardian'),'payment','bill','guardian'),false);
assert.equal(await canAttachRecord(caller('tenant','rent',false),'payment','bill','tenant'),false);
assert.equal(await canAttachRecord(caller('tenant','rent',true),'payment','bill','tenant'),true);
assert.equal(await canAttachRecord(caller('tenant','rent',true),'maintenance','report','tenant'),true);
console.log('Receipt attachment permissions passed for owner, caretaker, tenant and guardian.');
