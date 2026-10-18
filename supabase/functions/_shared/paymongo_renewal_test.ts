import {createOrResumePayment,synchronizePayment} from './paymongo_store.ts'
import {PayMongoClient,type GatewayConfig,type Session} from './paymongo.ts'
const assert=(v:unknown,m='Assertion failed')=>{if(!v)throw Error(m)}
const config:GatewayConfig={environment:'test',ready:true,publicKey:'pk_test_fixture',secretKey:'sk_test_fixture',webhookSecret:'fixture'}
const initial:Session={id:'old',charge_id:'bill',tenant_id:'tenant',enabled_by:'owner',environment:'test',amount_centavos:10000,
 status:'pending',provider_intent_id:'pi_Old',provider_method_id:'pm_Old',created_at:'2026-01-01T00:00:00Z',expires_at:'2026-01-01T00:30:00Z'}
function fixture(options:{provider?:string;cancelResult?:string;cancelFails?:boolean;lookupFails?:boolean;future?:boolean;newCreation?:boolean}={}){
 let stored={...initial,expires_at:options.future?'2099-01-01T00:00:00Z':initial.expires_at}
 let provider=options.provider??'awaiting_next_action',begins=0,created=0,cancels=0,credits=0,reads=0
 const admin={from(){let patch:any={};return{update(p:any){patch=p;return this},eq(){return this},neq(){return this},select(){return this},
 single(){stored={...stored,...patch};return Promise.resolve({data:stored,error:null})}}},
 rpc(name:string){assert(name==='settle_paymongo_payment');credits++;stored={...stored,status:'succeeded'};return Promise.resolve({data:stored,error:null})}}
 const client=new PayMongoClient(config,(async(input:any,init:any)=>{
  const url=String(input)
  if(url.endsWith('/payment_methods'))return Response.json({data:{id:'pm_New',attributes:{created_at:Math.floor(Date.now()/1000)}}})
  if(url.endsWith('/payment_intents')&&init?.method==='POST'){
    provider='awaiting_payment_method'
    return Response.json({data:{id:'pi_New',type:'payment_intent',attributes:{status:provider,amount:10000,currency:'PHP',livemode:false,
      client_key:'client-key',metadata:{gateway_session_id:stored.id,charge_id:'bill',tenant_id:'tenant'}}}})
  }
  if(url.endsWith('/attach'))provider='awaiting_next_action'
  if(url.endsWith('/cancel')){cancels++;if(options.cancelFails)throw Error('Cancel response lost');provider=options.cancelResult??'cancelled';return Response.json({})}
  reads++;if(options.lookupFails&&reads>1)throw Error('Provider unavailable')
  return Response.json({data:{id:stored.provider_intent_id,type:'payment_intent',attributes:{status:provider,
   amount:10000,currency:'PHP',livemode:false,metadata:{gateway_session_id:stored.id,charge_id:'bill',tenant_id:'tenant'},
   next_action:{code:{image_url:'data:image/png;base64,aGVsbG8='}},
   payments:provider==='succeeded'?[{id:'pay_Confirmed',attributes:{status:'paid',amount:10000,currency:'PHP',livemode:false,
     payment_intent_id:stored.provider_intent_id,source:{type:'qrph'},paid_at:1792100000}}]:[]}}})
 }) as typeof fetch)
 const begin=async()=>{
  begins++
  if(['expired','cancelled','failed'].includes(stored.status)){
   // Represents the second atomic billing RPC acquiring/resuming a new request.
   created++;stored={...stored,id:'replacement',status:'creating',provider_intent_id:null,provider_method_id:null,expires_at:undefined}
   // Another overlapping creator already holds its creation lease.
   return {data:{session:{...stored},is_new:options.newCreation??false},error:null}
  }
  return {data:{session:{...stored},is_new:false},error:null}
 }
 const creatorAdmin={...admin,rpc(name:string,...args:any[]){
  if(name==='claim_paymongo_creation')return Promise.resolve({data:null,error:null})
  return admin.rpc(name,...args as [])
 }}
 return {admin,client,begin,creatorAdmin,get stored(){return stored},get begins(){return begins},get created(){return created},get cancels(){return cancels},get credits(){return credits}}
}
Deno.test('expired waiting QR is retired at provider before a new atomic request begins',async()=>{
 const f=fixture();const result=await createOrResumePayment(f.creatorAdmin,f.client,f.begin)
 assert(f.cancels===1&&f.begins===2&&f.created===1&&result.id==='replacement')
})
Deno.test('valid QR reuses existing request without cancellation or another bill reservation',async()=>{
 const f=fixture({future:true});const result=await createOrResumePayment(f.creatorAdmin,f.client,f.begin)
 assert(result.id==='old'&&result.status==='pending'&&f.begins===1&&f.cancels===0)
})
Deno.test('renewal generates a fresh provider intent, method and usable QR in the same request',async()=>{
 const f=fixture({newCreation:true});const result=await createOrResumePayment(f.creatorAdmin,f.client,f.begin)
 assert(result.id==='replacement'&&result.provider_intent_id==='pi_New'&&result.provider_method_id==='pm_New')
 assert(result.status==='pending'&&typeof result.qr_image==='string'&&Date.parse(result.expires_at!)>Date.now())
})
Deno.test('processing payment never expires from the clock or creates a replacement',async()=>{
 const f=fixture({provider:'processing'});const result=await createOrResumePayment(f.creatorAdmin,f.client,f.begin)
 assert(result.status==='pending'&&result.qr_image===null&&f.cancels===0&&f.begins===1)
})
Deno.test('payment racing cancellation is credited and never replaced',async()=>{
 const f=fixture({cancelResult:'succeeded'});const result=await createOrResumePayment(f.creatorAdmin,f.client,f.begin)
 assert(result.status==='succeeded'&&f.credits===1&&f.begins===1&&f.created===0)
})
Deno.test('provider cancellation refusal leaves old request blocking and hides unusable QR',async()=>{
 const f=fixture({cancelFails:true});const result=await createOrResumePayment(f.creatorAdmin,f.client,f.begin)
 assert(result.status==='pending'&&result.qr_image===null&&result.test_url===null&&!!result.issue&&f.begins===1)
})
Deno.test('unavailable provider recheck never releases the old bill reservation',async()=>{
 const f=fixture({lookupFails:true});let failed=false
 try{await createOrResumePayment(f.creatorAdmin,f.client,f.begin)}catch{failed=true}
 assert(failed&&f.stored.status==='pending'&&f.begins===1&&f.created===0)
})
Deno.test('needs-review payment stays reserved without automatic provider cancellation',async()=>{
 const f=fixture();const result=await synchronizePayment(f.admin,f.client,{...initial,status:'needs_review'})
 assert(result.status==='needs_review'&&f.cancels===0)
})
