import { GatewayError, PayMongoClient, Session, confirmedPayment, qrDetails, validateIntent } from './paymongo.ts'

async function updateSession(admin: any, id: string, patch: object) {
  const { data, error } = await admin.from('paymongo_payment_sessions').update(patch)
    .eq('id', id).neq('status', 'succeeded').select().single()
  if (error) {
    // A webhook may have settled the session concurrently.
    const { data: current, error: lookupError } = await admin.from('paymongo_payment_sessions').select().eq('id', id).single()
    if (!lookupError && current?.status === 'succeeded') return current as Session
    throw new GatewayError('Could not save the payment status. Please refresh.', 503)
  }
  return data as Session
}
export async function synchronizePayment(admin: any, client: PayMongoClient, session: Session) {
  if (!session.provider_intent_id || session.environment !== client.config.environment) return session
  const payload = await client.retrieve(session.provider_intent_id)
  const a = validateIntent(payload, session)
  const payment = confirmedPayment(payload, session)
  if (payment) {
    const { data, error } = await admin.rpc('settle_paymongo_payment', {
      p_session_id: session.id, p_intent_id: session.provider_intent_id,
      p_payment_id: payment.id, p_amount_centavos: session.amount_centavos,
      p_currency: 'PHP', p_environment: session.environment, p_paid_at: payment.paidAt,
    })
    if (error) throw new GatewayError('Payment confirmation could not be saved. Please refresh.', 503)
    return data as Session
  }
  if (session.status === 'succeeded') return session
  const patch: Record<string, unknown> = { last_checked_at: new Date().toISOString() }
  if (a.status === 'cancelled' || a.status === 'canceled') patch.status = 'cancelled'
  else if (a.status === 'awaiting_payment_method' && session.provider_method_id) {
    patch.status = session.expires_at && Date.parse(session.expires_at) <= Date.now() ? 'expired' : 'failed'
  } else if (a.status === 'awaiting_next_action') {
    Object.assign(patch, qrDetails(payload), { status: 'pending', issue: null })
  }
  // Do not expire a processing payment by a device/server clock alone.
  return await updateSession(admin, session.id, patch)
}
export async function generatePaymentQr(admin: any, client: PayMongoClient, original: Session) {
  let session = original
  if (session.environment !== client.config.environment) throw new GatewayError('Payment environment changed. Contact staff.', 409)
  const save = async (patch: object) => session = await updateSession(admin, session.id, patch)
  try {
    let payload: any
    if (session.provider_intent_id) payload = await client.retrieve(session.provider_intent_id)
    else {
      payload = await client.request('payment_intents', 'POST', {
        amount: Number(session.amount_centavos), currency: 'PHP', payment_method_allowed: ['qrph'],
        description: `Dormitory bill ${session.charge_id}`,
        metadata: { gateway_session_id: session.id, charge_id: session.charge_id },
      }, `${session.id}:intent`)
      if (!/^pi_[A-Za-z0-9]+$/.test(payload?.data?.id)) throw new GatewayError('Could not create the payment request', 502)
      await save({ provider_intent_id: payload.data.id })
    }
    let a = validateIntent(payload, session)
    if (a.status !== 'awaiting_payment_method') return await synchronizePayment(admin, client, session)
    if (!session.provider_method_id) {
      const method = await client.request('payment_methods', 'POST', { type: 'qrph', expiry_seconds: 1800 },
        `${session.id}:method`, true)
      if (!/^pm_[A-Za-z0-9]+$/.test(method?.data?.id)) throw new GatewayError('Could not create the QR payment method', 502)
      const createdAt = method.data.attributes?.created_at
      await save({ provider_method_id: method.data.id,
        expires_at: new Date((Number.isSafeInteger(createdAt) ? createdAt * 1000 : Date.now()) + 1800_000).toISOString() })
    }
    payload = await client.request(`payment_intents/${session.provider_intent_id}/attach`, 'POST', {
      payment_method: session.provider_method_id, client_key: a.client_key,
    }, `${session.id}:attach`)
    a = validateIntent(payload, session)
    if (a.status !== 'awaiting_next_action') return await synchronizePayment(admin, client, session)
    const details = qrDetails(payload)
    return await save({ ...details, status: 'pending', issue: null,
      expires_at: session.expires_at ?? new Date(Date.now() + 1800_000).toISOString(), last_checked_at: new Date().toISOString() })
  } catch (error) {
    // Keep the same IDs/idempotency keys for uncertain network outcomes.
    await save({ issue: 'QR generation was interrupted. Refresh to resume the same payment request.' })
    throw error
  }
}
