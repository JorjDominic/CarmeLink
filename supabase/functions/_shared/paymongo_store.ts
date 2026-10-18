import { GatewayError, PayMongoClient, Session, confirmedPayment, qrDetails, validateIntent } from './paymongo.ts'

async function updateSession(admin: any, id: string, patch: object) {
  const { data, error } = await admin.from('paymongo_payment_sessions').update(patch)
    .eq('id', id).neq('status', 'succeeded').neq('status', 'needs_review').select().single()
  if (error) {
    // A webhook may have settled the session concurrently.
    const { data: current, error: lookupError } = await admin.from('paymongo_payment_sessions').select().eq('id', id).single()
    if (!lookupError && ['succeeded','needs_review'].includes(current?.status)) return current as Session
    throw new GatewayError('Could not save the payment status. Please refresh.', 503)
  }
  return data as Session
}
export async function synchronizePayment(admin: any, client: PayMongoClient, session: Session, mayCancelExpired = true): Promise<Session> {
  if (session.status === 'needs_review') return session
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
  const overdue = !!session.expires_at && Date.parse(session.expires_at) <= Date.now()
  if (a.status === 'cancelled' || a.status === 'canceled') patch.status = overdue ? 'expired' : 'cancelled'
  else if (a.status === 'awaiting_payment_method' && session.provider_method_id) {
    patch.status = session.expires_at && Date.parse(session.expires_at) <= Date.now() ? 'expired' : 'failed'
  } else if (a.status === 'awaiting_next_action') {
    if (overdue) {
      // Sandbox intents can keep waiting long after the QR deadline. Retire the
      // provider intent before releasing the bill for another payment request.
      if (mayCancelExpired) {
        try {
          await client.request(`payment_intents/${session.provider_intent_id}/cancel`, 'POST', {}, `${session.id}:expire`)
        } catch (_) {
          // Cancellation may race with payment or lose its response. A fresh
          // provider read, not the clock or cancel response, decides the result.
        }
        return await synchronizePayment(admin, client, session, false)
      }
      Object.assign(patch, { qr_image: null, test_url: null,
        issue: 'This QR has expired. Checking the previous payment before a new request can be created.' })
    } else Object.assign(patch, qrDetails(payload), { status: 'pending', issue: null })
  } else if (a.status === 'processing') {
    Object.assign(patch, { qr_image: null, test_url: null,
      issue: 'Payment is processing. Wait for confirmation before starting another request.' })
  }
  if (['expired', 'failed', 'cancelled'].includes(String(patch.status))) {
    Object.assign(patch, { qr_image: null, test_url: null, issue: null })
  }
  // Do not expire a processing payment by a device/server clock alone.
  return await updateSession(admin, session.id, patch)
}

// The billing RPC serializes requests on the bill. Run it again only after the
// provider-confirmed terminal state has released the old request's reservation.
export async function createOrResumePayment(admin: any, client: PayMongoClient,
  begin: () => PromiseLike<{ data: any; error: any }>): Promise<Session> {
  for (let attempt = 0; attempt < 2; attempt++) {
    const { data, error } = await begin()
    if (error) throw new GatewayError(error.message, 409)
    if (!data?.session) throw new GatewayError('Could not prepare payment request', 503)
    let session: Session = data.session
    if (data.is_new) return await generatePaymentQr(admin, client, session)
    if (session.status === 'creating') {
      const { data: claimed, error: claimError } = await admin.rpc('claim_paymongo_creation', { p_session_id: session.id })
      if (claimError) throw new GatewayError('Could not resume payment creation. Try again.', 503)
      if (claimed) session = await generatePaymentQr(admin, client, claimed)
    } else session = await synchronizePayment(admin, client, session)
    if (attempt === 0 && ['expired','failed','cancelled'].includes(session.status)) continue
    return session
  }
  throw new GatewayError('Check the previous payment before trying again.', 409)
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
        metadata: { gateway_session_id: session.id, charge_id: session.charge_id, tenant_id: session.tenant_id },
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
      // This is a navigation hint only. QR simulators/wallet apps may ignore it;
      // payment confirmation always uses authenticated provider reads/webhooks.
      return_url: `https://carmelitasdormitory.site/payment/return?session_id=${encodeURIComponent(session.id)}`,
    }, `${session.id}:attach`)
    a = validateIntent(payload, session)
    if (a.status !== 'awaiting_next_action') return await synchronizePayment(admin, client, session)
    const details = qrDetails(payload)
    return await save({ ...details, status: 'pending', issue: null,
      // QR validity starts on attach, not when the payment method was created.
      expires_at: new Date(Date.now() + 1800_000).toISOString(), last_checked_at: new Date().toISOString() })
  } catch (error) {
    // Keep the same IDs/idempotency keys for uncertain network outcomes.
    await save({ issue: 'QR generation was interrupted. Refresh to resume the same payment request.' })
    throw error
  }
}

export async function cancelUnpaidRequests(admin: any, client: PayMongoClient) {
  const { data: requests, error } = await admin.from('paymongo_payment_sessions')
    .select().in('status', ['creating', 'pending'])
  if (error) throw new GatewayError('Manual mode is saved, but QR requests could not be loaded. Select Manual again to retry.', 503)
  let incomplete = 0
  for (const original of requests ?? []) {
    try {
      if (!client.config.ready || original.environment !== client.config.environment) {
        throw new GatewayError('Payment configuration unavailable')
      }
      let session = original
      if (session.status === 'creating') {
        // Resolve interrupted provider creation using its original idempotency keys.
        // Never mark a request cancelled while another worker is creating its QR.
        const { data: claimed, error: claimError } = await admin.rpc('claim_paymongo_creation', { p_session_id: session.id })
        if (claimError || !claimed) throw new GatewayError('QR generation is in progress')
        session = await generatePaymentQr(admin, client, claimed)
      }
      session = await synchronizePayment(admin, client, session)
      if (['succeeded', 'needs_review', 'cancelled', 'expired', 'failed'].includes(session.status)) continue
      if (!session.provider_intent_id) throw new GatewayError('Provider request unavailable')
      await client.request(`payment_intents/${session.provider_intent_id}/cancel`, 'POST', {}, `${session.id}:cancel`)
      session = await synchronizePayment(admin, client, session)
      if (!['cancelled', 'succeeded', 'needs_review', 'expired', 'failed'].includes(session.status)) {
        throw new GatewayError('Cancellation not confirmed')
      }
    } catch (_) {
      incomplete++
    }
  }
  if (incomplete) throw new GatewayError(
    `Manual mode is saved, but ${incomplete} unpaid QR request(s) could not be cancelled yet. Select Manual again to retry.`, 409)
}
