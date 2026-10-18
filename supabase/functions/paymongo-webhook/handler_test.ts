import {handleWebhook} from './handler.ts'
import {gatewayConfig,PayMongoClient,type Session} from '../_shared/paymongo.ts'
import {synchronizePayment} from '../_shared/paymongo_store.ts'
function assert(value:unknown,message='Assertion failed'):asserts value {if(!value)throw Error(message)}
const secrets:Record<string,string>={PAYMONGO_ENVIRONMENT:'test',PAYMONGO_DEPLOYMENT_ENVIRONMENT:'staging',
 SUPABASE_URL:'https://staging.example',PAYMONGO_TEST_SUPABASE_URL:'https://staging.example',
 PAYMONGO_PUBLIC_KEY:'pk_test_fixture',PAYMONGO_SECRET_KEY:'sk_test_fixture',PAYMONGO_WEBHOOK_SECRET:'fixture-hook'}
const now=1792100000
const initial:Session={id:'session',charge_id:'bill',tenant_id:'tenant',enabled_by:'owner',environment:'test',amount_centavos:100000,
 status:'pending',provider_intent_id:'pi_Fixture',provider_method_id:'pm_Fixture',created_at:new Date().toISOString()}
const payload=()=>({data:{id:'pi_Fixture',type:'payment_intent',attributes:{status:'succeeded',amount:100000,currency:'PHP',livemode:false,
 metadata:{gateway_session_id:'session',charge_id:'bill',tenant_id:'tenant'},payments:[{id:'pay_Fixture',attributes:{status:'paid',amount:100000,
 currency:'PHP',livemode:false,payment_intent_id:'pi_Fixture',source:{type:'qrph'},paid_at:now}}]}}})
async function signed(type='payment.paid',options:{invalid?:boolean,old?:boolean,live?:boolean,unknown?:boolean}={}) {
 const raw=JSON.stringify({data:{attributes:{type,livemode:options.live??false,data:{id:'pay_Fixture',type:'payment',attributes:{payment_intent_id:options.unknown?'pi_Unknown':'pi_Fixture'}}}}})
 const timestamp=options.old?now-301:now
 const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(secrets.PAYMONGO_WEBHOOK_SECRET),{name:'HMAC',hash:'SHA-256'},false,['sign'])
 const digest=new Uint8Array(await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(`${timestamp}.${raw}`)))
 const signature=Array.from(digest,b=>b.toString(16).padStart(2,'0')).join('')
 return new Request('https://fixture.example/webhook',{method:'POST',body:raw,headers:{'Paymongo-Signature':`t=${timestamp},te=${options.invalid?'0'.repeat(64):signature}`}})
}
function fixture() {
 let stored={...initial},data:any=payload(),settlements=0,credits=0,reads=0,unknown=false
 const admin={from(){let patch:any={};return {select(){return this},eq(_key:string,value:unknown){if(value==='pi_Unknown')unknown=true;return this},
 neq(){return this},update(value:unknown){patch=value;return this},maybeSingle(){return Promise.resolve({data:unknown?null:stored,error:null})},
 single(){stored={...stored,...patch};return Promise.resolve({data:stored,error:null})}}},rpc:(_name:string,args:any)=>{
 settlements++;assert(args.p_amount_centavos===100000&&args.p_environment==='test')
 if(stored.status!=='succeeded')credits++
 stored={...stored,status:'succeeded'};return Promise.resolve({data:stored,error:null})}}
 return {dependencies:{env:(key:string)=>secrets[key],createAdmin:()=>admin,nowSeconds:now,fetcher:(async()=>{reads++;return Response.json(data)}) as typeof fetch},
 setData:(value:any)=>data=value,get stored(){return stored},get settlements(){return settlements},get credits(){return credits},get reads(){return reads}}
}
Deno.test('test keys fail closed without a pinned staging project and reject live keys in staging',()=>{
 for(const patch of [{PAYMONGO_DEPLOYMENT_ENVIRONMENT:'production'},{PAYMONGO_TEST_SUPABASE_URL:'https://other.example'},
 {PAYMONGO_PUBLIC_KEY:'pk_live_fixture'},{PAYMONGO_SECRET_KEY:'sk_live_fixture'},
 {PAYMONGO_ENVIRONMENT:'live',PAYMONGO_PUBLIC_KEY:'pk_live_fixture',PAYMONGO_SECRET_KEY:'sk_live_fixture',PAYMONGO_ALLOW_LIVE:'true'}]){
  assert(!gatewayConfig(key=>({...secrets,...patch} as Record<string,string|undefined>)[key]).ready)
 }
})
Deno.test('HTTP webhook rejects invalid/expired signatures and live events before provider lookup',async()=>{
 for(const options of [{invalid:true},{old:true},{live:true}]){const f=fixture();const response=await handleWebhook(await signed('payment.paid',options),f.dependencies);assert([400,401].includes(response.status));assert(f.reads===0&&f.credits===0)}
})
Deno.test('duplicate signed webhooks re-read the provider and rely on idempotent database settlement',async()=>{
 const f=fixture();for(let i=0;i<2;i++)assert((await handleWebhook(await signed(),f.dependencies)).status===200)
 assert(f.reads===2&&f.settlements===2&&f.credits===1)
})
Deno.test('unknown payment references are acknowledged without financial changes',async()=>{
 const f=fixture();assert((await handleWebhook(await signed('payment.paid',{unknown:true}),f.dependencies)).status===200);assert(f.reads===0&&f.credits===0)
})
Deno.test('signed payload cannot substitute for a matching authenticated provider transaction',async()=>{
 for(const mutate of [(p:any)=>p.data.attributes.amount=1,(p:any)=>p.data.attributes.currency='USD',
 (p:any)=>p.data.attributes.metadata.tenant_id='other-tenant',(p:any)=>p.data.attributes.metadata.charge_id='other-bill',
 (p:any)=>p.data.attributes.metadata.gateway_session_id='other-session',(p:any)=>p.data.id='pi_Wrong',
 (p:any)=>p.data.attributes.livemode=true,(p:any)=>p.data.attributes.payments[0].attributes.currency='USD',
 (p:any)=>p.data.attributes.payments[0].attributes.paid_at=0]){
  const f=fixture(),p=payload();mutate(p);f.setData(p);assert((await handleWebhook(await signed(),f.dependencies)).status===409);assert(f.credits===0)
 }
})
Deno.test('an out-of-order failure event uses current paid provider state and cannot undo settlement',async()=>{
 const f=fixture();assert((await handleWebhook(await signed('payment.failed'),f.dependencies)).status===200)
 assert(f.stored.status==='succeeded'&&f.credits===1)
 const p=payload();p.data.attributes.status='processing';p.data.attributes.payments=[];f.setData(p)
 assert((await handleWebhook(await signed('qrph.expired'),f.dependencies)).status===200)
 assert(f.stored.status==='succeeded'&&f.credits===1)
})
Deno.test('verified test requests never run in an unconfigured production deployment',async()=>{
 const f=fixture();const response=await handleWebhook(await signed(),{...f.dependencies,env:key=>key==='PAYMONGO_DEPLOYMENT_ENVIRONMENT'?'production':secrets[key]})
 assert(response.status===503&&f.reads===0&&f.credits===0)
})
for(const [provider,expected] of [['processing','pending'],['cancelled','expired'],['awaiting_payment_method','expired'],['awaiting_next_action','pending']] as const){
 Deno.test(`provider ${provider} is handled without trusting the client or expiry clock alone`,async()=>{
  let result:any
  const admin={from(){return{update(p:unknown){result=p;return this},eq(){return this},neq(){return this},select(){return this},single(){return Promise.resolve({data:{...initial,...result},error:null})}}},rpc(){throw Error('Unexpected settlement')}}
  const p:any=payload();p.data.attributes.status=provider;p.data.attributes.payments=[]
  p.data.attributes.next_action={code:{image_url:'data:image/png;base64,aGVsbG8='}}
  const client=new PayMongoClient(gatewayConfig(key=>secrets[key]),(async()=>Response.json(p)) as typeof fetch)
  const saved=await synchronizePayment(admin,client,{...initial,expires_at:'2000-01-01T00:00:00Z'})
  assert(saved.status===expected)
 })
}
Deno.test('failed provider payment before expiry is displayed as failed',async()=>{
 const admin={from(){return{update(){return this},eq(){return this},neq(){return this},select(){return this},single(){return Promise.resolve({data:{...initial,status:'failed'},error:null})}}}}
 const p:any=payload();p.data.attributes.status='awaiting_payment_method';p.data.attributes.payments=[]
 const client=new PayMongoClient(gatewayConfig(key=>secrets[key]),(async()=>Response.json(p)) as typeof fetch)
 assert((await synchronizePayment(admin,client,{...initial,expires_at:'2099-01-01T00:00:00Z'})).status==='failed')
})
