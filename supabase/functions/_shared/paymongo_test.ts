import { GatewayError, PayMongoClient, confirmedPayment, gatewayConfig, qrDetails, safeTestUrl,
  validateIntent, verifyWebhookSignature, type Session } from './paymongo.ts'
import { handleRequest } from '../paymongo-payments/handler.ts'
import { cancelUnpaidRequests, generatePaymentQr, synchronizePayment } from './paymongo_store.ts'

function assert(value: unknown, message = 'Assertion failed'): asserts value { if (!value) throw new Error(message) }
function rejects(action: () => unknown) {
  try { action() } catch (error) { assert(error instanceof GatewayError); return }
  throw new Error('Expected validation failure')
}
const session: Session = { id:'session',charge_id:'bill',tenant_id:'tenant',enabled_by:'owner',environment:'test',
  amount_centavos:350000,status:'pending',provider_intent_id:'pi_Test',provider_method_id:'pm_Test',created_at:new Date().toISOString() }
function paidIntent() {
  return { data:{ id:'pi_Test',type:'payment_intent',attributes:{ status:'succeeded',amount:350000,currency:'PHP',livemode:false,
    metadata:{gateway_session_id:'session',charge_id:'bill'}, payments:[{id:'pay_Test',attributes:{
      status:'paid',amount:350000,currency:'PHP',livemode:false,payment_intent_id:'pi_Test',source:{type:'qrph'},paid_at:1791417600,
    }}] } } }
}

for (const outcome of ['cancelled', 'succeeded', 'unconfirmed']) {
  Deno.test(`manual switch cancels unpaid requests and handles ${outcome}`, async () => {
    let stored = {...session}
    let cancelled = false
    let settles = 0
    const query = {
      select(){return this},
      in(_column: string, statuses: string[]){
        assert(JSON.stringify(statuses) === JSON.stringify(['creating', 'pending']))
        return Promise.resolve({data:[stored],error:null})
      },
      update(patch: any){ stored = {...stored,...patch}; return this },
      eq(){return this}, neq(){return this},
      single(){return Promise.resolve({data:stored,error:null})},
    }
    const admin = {from:()=>query, rpc:async()=>{
      settles++
      stored = {...stored,status:'succeeded'}
      return {data:stored,error:null}
    }}
    const client = {
      config:{ready:true,environment:'test'},
      retrieve:async()=> {
        if (outcome === 'succeeded') return paidIntent()
        const payload = paidIntent()
        Object.assign(payload.data.attributes, {
          status:cancelled && outcome === 'cancelled' ? 'cancelled' : 'processing', payments:[],
        })
        return payload
      },
      request:async(path:string)=>{
        assert(path === 'payment_intents/pi_Test/cancel')
        cancelled = true
        return {}
      },
    } as unknown as PayMongoClient
    if (outcome === 'unconfirmed') {
      let failed = false
      try { await cancelUnpaidRequests(admin,client) } catch (error) {
        assert(error instanceof GatewayError && error.message.includes('Manual mode is saved'))
        failed = true
      }
      assert(failed && stored.status !== 'cancelled')
    } else {
      await cancelUnpaidRequests(admin,client)
      assert(stored.status === outcome)
      assert(outcome === 'succeeded' ? settles === 1 && !cancelled : cancelled)
    }
  })
}

Deno.test('configuration is disabled without keys and live requires explicit enablement', () => {
  assert(!gatewayConfig(() => undefined).ready)
  const secrets: Record<string,string> = { PAYMONGO_DEPLOYMENT_ENVIRONMENT:'staging',SUPABASE_URL:'https://staging.example',PAYMONGO_TEST_SUPABASE_URL:'https://staging.example',PAYMONGO_ENVIRONMENT:'test',PAYMONGO_PUBLIC_KEY:'pk_test_abc',
    PAYMONGO_SECRET_KEY:'sk_test_abc',PAYMONGO_WEBHOOK_SECRET:'hook' }
  assert(gatewayConfig(k => secrets[k]).ready)
  secrets.PAYMONGO_ENVIRONMENT='live'; assert(!gatewayConfig(k => secrets[k]).ready)
  secrets.PAYMONGO_PUBLIC_KEY='pk_live_abc'; secrets.PAYMONGO_SECRET_KEY='sk_live_abc'
  assert(!gatewayConfig(k => secrets[k]).ready)
  secrets.PAYMONGO_ALLOW_LIVE='true'; assert(!gatewayConfig(k => secrets[k]).ready)
  secrets.PAYMONGO_DEPLOYMENT_ENVIRONMENT='production'; assert(gatewayConfig(k => secrets[k]).ready)
})
Deno.test('verified payment must match identity, amount, currency, environment and source', () => {
  assert(confirmedPayment(paidIntent(),session)?.id==='pay_Test')
  for (const mutate of [
    (p:any) => p.data.id='pi_Wrong',
    (p:any) => p.data.attributes.amount=1,
    (p:any) => p.data.attributes.currency='USD',
    (p:any) => p.data.attributes.livemode=true,
    (p:any) => p.data.attributes.metadata.charge_id='different',
    (p:any) => p.data.attributes.payments[0].attributes.status='failed',
    (p:any) => p.data.attributes.payments[0].attributes.amount=1,
    (p:any) => p.data.attributes.payments[0].attributes.payment_intent_id='pi_Wrong',
    (p:any) => p.data.attributes.payments[0].attributes.source.type='gcash',
    (p:any) => p.data.attributes.payments.push(p.data.attributes.payments[0]),
  ]) { const p=paidIntent(); mutate(p); rejects(() => confirmedPayment(p,session)) }
  const pending=paidIntent(); pending.data.attributes.status='processing'
  assert(confirmedPayment(pending,session)===null)
})
Deno.test('webhooks authenticate exact raw body, mode and freshness', async () => {
  const raw='{"data":{"status":"paid"}}'
  const timestamp=1791417600
  const secret='test-webhook-secret'
  const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['sign'])
  const digest=new Uint8Array(await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(`${timestamp}.${raw}`)))
  const signature=Array.from(digest,b => b.toString(16).padStart(2,'0')).join('')
  const header=`t=${timestamp},te=${signature},li=`
  assert(await verifyWebhookSignature(raw,header,secret,'test',timestamp))
  assert(!await verifyWebhookSignature(raw+' ',header,secret,'test',timestamp))
  assert(!await verifyWebhookSignature(raw,header,'wrong','test',timestamp))
  assert(!await verifyWebhookSignature(raw,header,secret,'live',timestamp))
  assert(!await verifyWebhookSignature(raw,header,secret,'test',timestamp+301))
  assert(!await verifyWebhookSignature(raw,null,secret,'test',timestamp))
})
Deno.test('QR rendering and test navigation accept only provider-safe data', () => {
  const qr=qrDetails({data:{attributes:{next_action:{code:{image_url:'data:image/png;base64,aGVsbG8=',test_url:'https://test-sources.paymongo.com/example'}}}}})
  assert(qr.test_url?.startsWith('https://test-sources.paymongo.com'))
  assert(safeTestUrl('https://paymongo.com.evil.example')===null)
  assert(safeTestUrl('javascript:alert(1)')===null)
  rejects(() => qrDetails({data:{attributes:{next_action:{code:{image_url:'https://evil.example/image'}}}}}))
})
Deno.test('provider writes use stable operation keys and correct authentication', async () => {
  const requests: RequestInit[]=[]
  const config=gatewayConfig(k => ({PAYMONGO_DEPLOYMENT_ENVIRONMENT:'staging',SUPABASE_URL:'https://staging.example',PAYMONGO_TEST_SUPABASE_URL:'https://staging.example',PAYMONGO_PUBLIC_KEY:'pk_test_abc',PAYMONGO_SECRET_KEY:'sk_test_abc',PAYMONGO_WEBHOOK_SECRET:'hook'} as Record<string,string>)[k])
  const client=new PayMongoClient(config,((_url:unknown,init:RequestInit) => {
    requests.push(init); return Promise.resolve(Response.json({data:{id:'pi_Test'}}))
  }) as typeof fetch)
  await client.request('payment_intents','POST',{amount:100},'session:intent')
  await client.request('payment_intents','POST',{amount:100},'session:intent')
  await client.request('payment_methods','POST',{type:'qrph'},'session:method',true)
  const first=requests[0].headers as Record<string,string>
  assert(first['Idempotency-Key']===(requests[1].headers as Record<string,string>)['Idempotency-Key'])
  assert(first.Authorization===`Basic ${btoa('sk_test_abc:')}`)
  assert((requests[2].headers as Record<string,string>).Authorization===`Basic ${btoa('pk_test_abc:')}`)
})
Deno.test('anonymous and caretaker requests cannot modify owner payment mode', async () => {
  const request=() => new Request('https://app.example/payments',{method:'POST',body:JSON.stringify({action:'set_mode',mode:'paymongo'})})
  const denied=await handleRequest(request(),{authenticate:async () => null})
  assert(denied.status===401)
  for (const role of ['caretaker','tenant','guardian']) {
    const query={select(){return this},eq(){return this},single(){return Promise.resolve({data:{role,mode:'manual'},error:null})}}
    const response=await handleRequest(request(),{env:() => undefined,
      authenticate:async () => ({caller:{from:() => query},admin:{},user:{id:'user'}} as any)})
    assert(response.status===403)
  }
})
Deno.test('owner cannot enable automatic collection without credentials', async () => {
  const query={select(){return this},eq(){return this},single(){return Promise.resolve({data:{role:'owner',mode:'manual'},error:null})}}
  const response=await handleRequest(new Request('https://app.example',{method:'POST',body:JSON.stringify({action:'set_mode',mode:'paymongo'})}),
    {env:() => undefined,authenticate:async () => ({caller:{from:() => query},admin:{},user:{id:'owner'}} as any)})
  assert(response.status===400)
})

Deno.test('advance requests validate month IDs and use the server-calculated session', async () => {
  const ids = ['00000000-0000-0000-0000-000000000070', '00000000-0000-0000-0000-000000000071']
  let calls = 0
  const saved = {...session, provider_intent_id:null, status:'succeeded', amount_centavos:650000,
    bill_breakdown:ids.map((id,i)=>({charge_id:id,title:`Month ${i+1}`,amount_centavos:i===0?300000:350000}))}
  const query = {select(){return this},eq(){return this},single(){return Promise.resolve({data:{role:'tenant',environment:'test'},error:null})}}
  const caller = {from:()=>query, rpc:async (name:string,args:any)=>{
    calls++
    assert(name==='begin_paymongo_advance_payment')
    assert(JSON.stringify(args.p_charge_ids)===JSON.stringify(ids))
    return {data:{session:saved,is_new:false},error:null}
  }}
  const dependencies = {env:(k:string)=>({PAYMONGO_DEPLOYMENT_ENVIRONMENT:'staging',SUPABASE_URL:'https://staging.example',PAYMONGO_TEST_SUPABASE_URL:'https://staging.example',PAYMONGO_PUBLIC_KEY:'pk_test_abc',PAYMONGO_SECRET_KEY:'sk_test_abc',PAYMONGO_WEBHOOK_SECRET:'hook'} as Record<string,string>)[k],
    authenticate:async()=>({caller,admin:{},user:{id:'tenant'}} as any)}
  for(const invalid of [[],[ids[0],ids[0]],['not-a-uuid'],[null],Array(61).fill(ids[0])]) {
    const result=await handleRequest(new Request('https://app.example',{method:'POST',body:JSON.stringify({action:'create',charge_ids:invalid})}),dependencies)
    assert(result.status===400)
  }
  assert(calls===0)
  const result=await handleRequest(new Request('https://app.example',{method:'POST',body:JSON.stringify({action:'create',charge_ids:ids,amount_centavos:1})}),dependencies)
  assert(result.status===200)
  const body=await result.json()
  assert(body.session.amount_centavos===650000 && body.session.bill_breakdown.length===2)
  assert(Number(calls)===1)
})

Deno.test('interrupted QR attachment resumes the original provider intent', async () => {
  let stored: Session = { ...session, status:'creating',provider_intent_id:null,provider_method_id:null }
  let intentCreates=0
  let methodCreates=0
  let attached=false
  const admin:any = {from() {
    let patch:object={}
    return {update(p:object){patch=p;return this},eq(){return this},neq(){return this},select(){return this},
      single(){stored={...stored,...patch};return Promise.resolve({data:{...stored},error:null})}}}
  }
  const config=gatewayConfig(k => ({PAYMONGO_DEPLOYMENT_ENVIRONMENT:'staging',SUPABASE_URL:'https://staging.example',PAYMONGO_TEST_SUPABASE_URL:'https://staging.example',PAYMONGO_PUBLIC_KEY:'pk_test_abc',PAYMONGO_SECRET_KEY:'sk_test_abc',PAYMONGO_WEBHOOK_SECRET:'hook'} as Record<string,string>)[k])
  const payload=() => ({data:{id:'pi_Test',type:'payment_intent',attributes:{
    amount:350000,currency:'PHP',livemode:false,client_key:'client',
    metadata:{gateway_session_id:'session',charge_id:'bill'},payments:[],
    status:attached ? 'awaiting_next_action' : 'awaiting_payment_method',
    next_action:attached ? {code:{image_url:'data:image/png;base64,aGVsbG8=',test_url:'https://test-sources.paymongo.com/test'}} : null,
  }}})
  const client=new PayMongoClient(config)
  client.retrieve=async () => payload()
  client.request=async (path:string) => {
    if (path==='payment_intents') {intentCreates++;return payload()}
    if (path==='payment_methods') {methodCreates++;return {data:{id:'pm_Test',attributes:{created_at:Math.floor(Date.now()/1000)}}}}
    attached=true
    throw new Error('Connection lost after provider accepted attachment')
  }
  let interrupted=false
  try {await generatePaymentQr(admin,client,stored)} catch (_) {interrupted=true}
  assert(interrupted)
  assert(stored.provider_intent_id==='pi_Test' && stored.provider_method_id==='pm_Test')
  const resumed=await generatePaymentQr(admin,client,stored)
  assert(resumed.status==='pending')
  assert(intentCreates===1 && methodCreates===1)
  assert(typeof resumed.qr_image==='string')
})

Deno.test('pending or tampered provider reads never invoke ledger settlement', async () => {
  let settlements=0
  const admin:any = {rpc(){settlements++;return Promise.resolve({data:session,error:null})},
    from(){return {update(){return this},eq(){return this},neq(){return this},select(){return this},
      single(){return Promise.resolve({data:session,error:null})}}}
  }
  const client=new PayMongoClient({environment:'test',publicKey:'',secretKey:'',webhookSecret:'',ready:true})
  const payload=paidIntent(); payload.data.attributes.status='processing'
  client.retrieve=async () => payload
  await synchronizePayment(admin,client,session)
  assert(settlements===0)
  payload.data.attributes.status='succeeded'; payload.data.attributes.amount=1
  let rejected=false
  try {await synchronizePayment(admin,client,session)} catch (_) {rejected=true}
  assert(rejected && settlements===0)
})
