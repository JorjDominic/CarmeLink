import { handleRequest } from './handler.ts'
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

function assert(value: unknown, message: string) {
  if (!value) throw new Error(message)
}

function fixture() {
  const incident = {
    id: 'incident',
    tenant_id: 'tenant',
    reason: 'LOCATION_SERVICES_DISABLED',
    started_at: new Date().toISOString(),
    guardian_notified_at: null as string | null,
    escalated_at: null,
  }
  const notifications = new Map<string, Record<string, unknown>>()
  let tokens = true
  let acceptPush = false
  let sends = 0
  const admin = {
    from(table: string) {
      let operation = 'select'
      let payload: Record<string, unknown> = {}
      const filters: Record<string, unknown> = {}
      const query = {
        select(_columns?: string) {
          return query
        },
        eq(key: string, value: unknown) {
          filters[key] = value
          return query
        },
        is(_key: string, _value: unknown) {
          return query
        },
        or(_value: string) {
          return query
        },
        in(_key: string, _value: unknown) {
          return query
        },
        single() {
          return query
        },
        maybeSingle() {
          return query
        },
        upsert(value: Record<string, unknown>, _options: unknown) {
          operation = 'upsert'
          payload = value
          return query
        },
        update(value: Record<string, unknown>) {
          operation = 'update'
          payload = value
          return query
        },
        then(resolve: (value: { data: unknown; error: null }) => unknown) {
          let data: unknown = null
          if (table === 'guardian_alert_cron_credentials') {
            data = { id: 'credential' }
          }
          if (table === 'profiles') data = { full_name: 'Tenant' }
          if (table === 'guardian_tenant_links') {
            data = [{ guardian_id: 'guardian' }]
          }
          if (table === 'location_monitoring_incidents') {
            if (operation === 'update') Object.assign(incident, payload)
            else data = incident.guardian_notified_at ? [] : [incident]
          }
          if (table === 'app_notifications') {
            if (
              operation === 'upsert' && !notifications.has(payload.id as string)
            ) {
              notifications.set(payload.id as string, {
                ...payload,
                push_sent_at: null,
              })
            }
            if (operation === 'update') {
              Object.assign(notifications.get(filters.id as string)!, payload)
            }
            data = notifications.get(filters.id as string)
          }
          if (table === 'push_device_tokens') {
            data = tokens ? [{ id: 'device', fcm_token: 'token' }] : []
          }
          return Promise.resolve(resolve({ data, error: null }))
        },
      }
      return query
    },
  }
  const run = () =>
    handleRequest(
      new Request('https://example.test', {
        method: 'POST',
        headers: { Authorization: 'Bearer test' },
      }),
      {
        createAdmin: () => admin as unknown as SupabaseClient,
        accessToken: async () => ({ projectId: 'test', token: 'test' }),
        send: async () => {
          sends++
          return new Response('', { status: acceptPush ? 200 : 503 })
        },
      },
    )
  return {
    incident,
    notifications,
    run,
    sends: () => sends,
    setTokens: (value: boolean) => {
      tokens = value
    },
    accept: () => {
      acceptPush = true
    },
  }
}

Deno.test('failed FCM is retried with the same notification and marked only after success', async () => {
  const f = fixture()
  assert((await f.run()).status === 200, 'first run failed')
  assert(
    f.incident.guardian_notified_at === null,
    'failed push marked delivered',
  )
  assert(f.notifications.size === 1, 'notification missing')
  f.accept()
  assert((await f.run()).status === 200, 'retry failed')
  assert(f.notifications.size === 1, 'retry duplicated notification')
  assert(
    f.incident.guardian_notified_at !== null,
    'successful push not marked',
  )
  await f.run()
  assert(f.sends() === 2, 'successful recipient was sent again')
})

Deno.test('missing device token remains pending until a device registers', async () => {
  const f = fixture()
  f.setTokens(false)
  await f.run()
  assert(
    f.incident.guardian_notified_at === null,
    'missing token marked delivered',
  )
  assert(f.sends() === 0, 'sent without token')
  f.setTokens(true)
  f.accept()
  await f.run()
  assert(
    f.incident.guardian_notified_at !== null,
    'new device was not retried',
  )
  assert(f.notifications.size === 1, 'new device duplicated notification')
})
