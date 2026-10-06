import { handleRequest } from './handler.ts'
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

function assert(condition: unknown, message: string) { if (!condition) throw new Error(message) }
function fixture() {
  const deliveries = new Set<string>()
  const completed: string[] = []
  const payloads: Record<string, string>[] = []
  let failSecond = true, validCredential = true, tokens = true, claims = 0
  const notification = { id: 'report-notification', recipient_id: 'owner', title: 'New cleaning report', body: 'Open to review', route_type: 'cleaning_report', route_id: 'report-id', notification_type: 'safety' }
  const admin = {
    rpc() { claims++; return Promise.resolve({ data: [notification], error: null }) },
    from(table: string) {
      let operation = 'select', payload: Record<string, unknown> = {}
      const query = {
        select() { return query }, eq() { return query }, is() { return query }, maybeSingle() { return query },
        update(value: Record<string, unknown>) { operation = 'update'; payload = value; return query },
        upsert(value: Record<string, unknown>) { operation = 'upsert'; payload = value; return query },
        then(resolve: (value: { data: unknown, error: null }) => unknown) {
          let data: unknown = null
          if (table === 'guardian_alert_cron_credentials') data = validCredential ? { id: 'credential' } : null
          if (table === 'push_device_tokens') data = tokens ? [{ id: 'first', fcm_token: 'first' }, { id: 'second', fcm_token: 'second' }] : []
          if (table === 'notification_push_deliveries') {
            if (operation === 'upsert') deliveries.add(payload.device_id as string)
            else data = Array.from(deliveries).map(device_id => ({ device_id }))
          }
          if (table === 'notification_push_jobs' && operation === 'update') completed.push(payload.completed_at as string)
          return Promise.resolve(resolve({ data, error: null }))
        },
      }
      return query
    },
  }
  const dependencies = {
    createAdmin: () => admin as unknown as SupabaseClient,
    accessToken: () => Promise.resolve({ projectId: 'project', token: 'authorization' }),
    send: (_auth: unknown, token: string, _title: string, _body: string, data: Record<string, string>) => {
      payloads.push(data)
      return Promise.resolve(new Response('', { status: token === 'second' && failSecond ? 503 : 200 }))
    },
  }
  const run = () => handleRequest(new Request('https://test', { method: 'POST', headers: { Authorization: 'Bearer test-secret' } }), dependencies)
  return { run, deliveries, completed, payloads, accept: () => { failSecond = false }, deny: () => { validCredential = false }, noTokens: () => { tokens = false }, claims: () => claims }
}

Deno.test('push retry skips devices already delivered and preserves record routing', async () => {
  const f = fixture()
  assert((await f.run()).status === 200, 'initial batch failed')
  assert(f.deliveries.has('first') && !f.deliveries.has('second'), 'wrong per-device delivery state')
  assert(f.completed.length === 0, 'failed delivery must remain retryable')
  f.accept()
  await f.run()
  assert(f.payloads.length === 3, 'retry resent an already delivered device')
  assert(f.completed.length === 1, 'successful retry did not complete')
  assert(f.payloads.every(p => p.route_type === 'cleaning_report' && p.route_id === 'report-id' && p.notification_id === 'report-notification'), 'push lost exact record destination')
})
Deno.test('invalid credential cannot claim work', async () => {
  const f = fixture(); f.deny()
  assert((await f.run()).status === 401 && f.claims() === 0, 'unauthorized dispatch reached queue')
})
Deno.test('users without a registered device retain inbox notification without retry loop', async () => {
  const f = fixture(); f.noTokens()
  await f.run()
  assert(f.completed.length === 1 && f.payloads.length === 0, 'no-device job should finish without an FCM call')
})
