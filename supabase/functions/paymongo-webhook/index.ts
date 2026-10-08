import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { GatewayError, PayMongoClient, gatewayConfig, verifyWebhookSignature } from '../_shared/paymongo.ts'
import { synchronizePayment } from '../_shared/paymongo_store.ts'

Deno.serve(async request => {
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 })
  try {
    const config = gatewayConfig(name => Deno.env.get(name))
    if (!config.ready) return new Response('Gateway unavailable', { status: 503 })
    const raw = await request.text()
    if (raw.length > 1_000_000) return new Response('Payload too large', { status: 413 })
    if (!await verifyWebhookSignature(raw, request.headers.get('Paymongo-Signature'), config.webhookSecret, config.environment)) {
      return new Response('Invalid signature', { status: 401 })
    }
    const event = JSON.parse(raw)?.data?.attributes
    if (event?.livemode !== (config.environment === 'live')) return new Response('Environment mismatch', { status: 400 })
    if (!['payment.paid','payment.failed','payment_intent.succeeded','qrph.expired'].includes(event.type)) return new Response('Ignored')
    const resource = event.data
    const intentId = resource?.type === 'payment_intent' ? resource.id : resource?.attributes?.payment_intent_id
    const methodId = resource?.type === 'payment_method' ? resource.id : null
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { persistSession: false } })
    let query = admin.from('paymongo_payment_sessions').select().eq('environment', config.environment)
    if (typeof intentId === 'string' && /^pi_[A-Za-z0-9]+$/.test(intentId)) query = query.eq('provider_intent_id', intentId)
    else if (typeof methodId === 'string' && /^pm_[A-Za-z0-9]+$/.test(methodId)) query = query.eq('provider_method_id', methodId)
    else return new Response('Ignored')
    const { data: session, error } = await query.maybeSingle()
    if (error) return new Response('Retry later', { status: 503 })
    if (!session) return new Response('Ignored')
    // Even signed events must agree with a fresh, authenticated provider read.
    await synchronizePayment(admin, new PayMongoClient(config), session)
    return new Response('OK')
  } catch (error) {
    return new Response('Retry later', { status: error instanceof GatewayError && error.status === 409 ? 409 : 503 })
  }
})
