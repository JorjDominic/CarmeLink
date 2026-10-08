import { authenticatedClients, corsHeaders, json } from '../_shared/cloudinary.ts'
import { GatewayError, PayMongoClient, gatewayConfig } from '../_shared/paymongo.ts'
import { generatePaymentQr, synchronizePayment } from '../_shared/paymongo_store.ts'

const uuid = (value: unknown) => typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)
export async function handleRequest(request: Request, dependencies: {
  authenticate?: typeof authenticatedClients;
  env?: (name: string) => string | undefined;
} = {}) {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  try {
    const auth = await (dependencies.authenticate ?? authenticatedClients)(request)
    if (!auth) return json({ error: 'Sign in to continue' }, 401)
    const { caller, admin, user } = auth
    const body = await request.json()
    const { data: profile, error: profileError } = await caller.from('profiles').select('role').eq('id', user.id).single()
    if (profileError || !profile) return json({ error: 'Account access unavailable' }, 403)
    const env = dependencies.env ?? ((name: string) => Deno.env.get(name))
    const config = gatewayConfig(env)
    const client = new PayMongoClient(config)
    const { data: settings, error: settingsError } = await caller.from('payment_collection_settings').select().eq('id', true).single()
    if (settingsError) throw new GatewayError('Could not load payment options', 503)
    if (body.action === 'settings') return json({ settings: {
      ...settings, paymongo_ready: config.ready, environment: config.environment,
    } })
    if (body.action === 'set_mode') {
      if (profile.role !== 'owner') return json({ error: 'Only the owner can change payment collection mode' }, 403)
      if (!['manual', 'paymongo'].includes(body.mode)) throw new GatewayError('Choose manual or PayMongo')
      if (body.mode === 'paymongo') {
        if (!config.ready) throw new GatewayError('PayMongo is not connected yet. Manual payments remain available.')
        // Confirm the merchant key works and a matching active webhook exists.
        const webhooks = await client.request('webhooks')
        const callback = `${env('SUPABASE_URL')}/functions/v1/paymongo-webhook`
        const connected = webhooks.data?.some((w: any) => w.attributes?.url === callback
          && w.attributes?.status === 'enabled' && w.attributes?.events?.includes('payment.paid')
          && (!w.attributes.secret_key || w.attributes.secret_key === config.webhookSecret))
        if (!connected) throw new GatewayError('Register and enable the PayMongo payment webhook before switching modes.')
        if (settings.environment !== config.environment) {
          const { count, error } = await admin.from('paymongo_payment_sessions').select('id', { count: 'exact', head: true })
            .in('status', ['creating', 'pending', 'needs_review'])
          if (error || count) throw new GatewayError('Reconcile active payment requests before changing environments.', 409)
        }
        const { error } = await admin.from('payment_collection_settings')
          .update({ paymongo_ready: true, environment: config.environment }).eq('id', true)
        if (error) throw new GatewayError('Could not save gateway configuration', 503)
      }
      const { data, error } = await caller.rpc('set_payment_collection_mode', { p_mode: body.mode })
      if (error) throw new GatewayError('Could not save payment mode. Refresh and try again.', 409)
      return json({ settings: { ...data, paymongo_ready: config.ready, environment: config.environment } })
    }
    if (!config.ready) throw new GatewayError('PayMongo is not connected yet. Contact dormitory staff.', 503)
    if (body.action === 'create') {
      if (profile.role !== 'tenant') return json({ error: 'Tenant access required' }, 403)
      if (!uuid(body.charge_id)) throw new GatewayError('Choose a valid bill')
      if (settings.environment !== config.environment) throw new GatewayError('Payment configuration needs owner attention', 409)
      const { data, error } = await caller.rpc('begin_paymongo_payment', { p_charge_id: body.charge_id })
      if (error) throw new GatewayError(error.message, 409)
      let session = data.session
      if (data.is_new) session = await generatePaymentQr(admin, client, session)
      else if (session.status === 'creating') {
        const { data: claimed } = await admin.rpc('claim_paymongo_creation', { p_session_id: session.id })
        if (claimed) session = await generatePaymentQr(admin, client, claimed)
      } else session = await synchronizePayment(admin, client, session)
      return json({ session })
    }
    if (!['status', 'cancel'].includes(body.action) || !uuid(body.session_id)) throw new GatewayError('Invalid payment request')
    const { data: found, error } = await caller.from('paymongo_payment_sessions').select().eq('id', body.session_id).single()
    if (error || !found) return json({ error: 'Payment request not found' }, 404)
    if (found.environment !== config.environment) throw new GatewayError('Payment environment changed. Contact staff.', 409)
    let session = found
    if (session.status === 'creating') {
      const { data: claimed } = await admin.rpc('claim_paymongo_creation', { p_session_id: session.id })
      if (claimed) session = await generatePaymentQr(admin, client, claimed)
    } else session = await synchronizePayment(admin, client, session)
    if (body.action === 'cancel' && !['succeeded','needs_review','cancelled','expired','failed'].includes(session.status)) {
      if (!session.provider_intent_id) throw new GatewayError('QR generation is still in progress. Try again shortly.', 409)
      await client.request(`payment_intents/${session.provider_intent_id}/cancel`, 'POST', {}, `${session.id}:cancel`)
      session = await synchronizePayment(admin, client, session)
      if (session.status !== 'cancelled' && session.status !== 'succeeded') {
        throw new GatewayError('Cancellation is not confirmed yet. Refresh payment status.', 409)
      }
    }
    return json({ session })
  } catch (error) {
    return json({ error: error instanceof GatewayError ? error.message : 'Payment service is temporarily unavailable. Please try again.' },
      error instanceof GatewayError ? error.status : 503)
  }
}
