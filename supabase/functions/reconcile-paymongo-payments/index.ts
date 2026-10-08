import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { PayMongoClient, gatewayConfig } from '../_shared/paymongo.ts'
import { generatePaymentQr, synchronizePayment } from '../_shared/paymongo_store.ts'

Deno.serve(async request => {
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 })
  const bearer = request.headers.get('Authorization')?.replace(/^Bearer\s+/i, '').trim()
  if (!bearer) return new Response('Unauthorized', { status: 401 })
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } })
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(bearer)))
  const hash = Array.from(digest, b => b.toString(16).padStart(2, '0')).join('')
  const { data: credential, error } = await admin.from('guardian_alert_cron_credentials')
    .select('id').eq('token_hash', hash).eq('is_active', true).maybeSingle()
  if (error || !credential) return new Response('Unauthorized', { status: 401 })
  const config = gatewayConfig(name => Deno.env.get(name))
  if (!config.ready) return Response.json({ skipped: 'not_configured' })
  const { data: sessions, error: claimError } = await admin.rpc('claim_paymongo_reconciliation')
  if (claimError) return new Response('Retry later', { status: 503 })
  const client = new PayMongoClient(config)
  let checked = 0
  let failed = 0
  // Bound concurrency and provider calls; leases keep overlapping runs apart.
  for (let i = 0; i < (sessions?.length ?? 0); i += 2) {
    await Promise.all(sessions.slice(i, i + 2).map(async (session: any) => {
      try {
        if (session.status === 'creating' && Date.parse(session.created_at) > Date.now() - 23 * 3600_000) {
          await generatePaymentQr(admin, client, session)
        } else if (session.provider_intent_id) await synchronizePayment(admin, client, session)
        else await admin.from('paymongo_payment_sessions').update({ status: 'failed',
          issue: 'Payment request could not be created. Start a new request.' }).eq('id', session.id).eq('status', 'creating')
        checked++
      } catch (_) { failed++ }
    }))
  }
  return Response.json({ checked, failed })
})
