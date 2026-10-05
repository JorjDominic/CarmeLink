import { handleRequest } from './handler.ts'
import type { authenticatedClients } from '../_shared/cloudinary.ts'

function assert(value: unknown, message: string) {
  if (!value) throw new Error(message)
}

function fixture() {
  const rows = new Map<string, Record<string, unknown>>()
  const sent: string[] = []
  let failGuardian = true
  let devicesPresent = true
  const admin = {
    from(table: string) {
      const filters: Record<string, unknown> = {}
      let operation = 'select', payload: Record<string, unknown> = {}
      let previous = false, staffQuery = false
      const query = {
        select(_value?: string) {
          return query
        },
        eq(key: string, value: unknown) {
          filters[key] = value
          return query
        },
        neq(_key: string, _value: unknown) {
          previous = true
          return query
        },
        not(_key: string, _op: string, _value: unknown) {
          return query
        },
        lt(_key: string, _value: unknown) {
          return query
        },
        order(_key: string, _value: unknown) {
          return query
        },
        limit(_value: number) {
          return query
        },
        is(_key: string, _value: unknown) {
          return query
        },
        in(_key: string, _value: unknown) {
          staffQuery = true
          return query
        },
        single() {
          return query
        },
        maybeSingle() {
          return query
        },
        insert(value: Record<string, unknown>) {
          operation = 'insert'
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
          if (table === 'gate_events' && !previous) {
            data = {
              id: 'event',
              tenant_id: 'tenant',
              direction: 'OUT',
              status: 'Allowed',
              verification_method: 'GPS',
              checked_at: new Date().toISOString(),
              created_by: 'tenant',
            }
          }
          if (table === 'profiles') {
            data = staffQuery ? [{ id: 'staff' }] : { id: 'tenant', role: 'tenant', full_name: 'Tenant' }
          }
          if (table === 'guardian_tenant_links') data = [{ guardian_id: 'guardian' }]
          if (table === 'guardian_alert_preferences') data = []
          if (table === 'app_notifications') {
            if (operation === 'insert') {
              const id = payload.recipient_id as string
              rows.set(id, { ...payload, id, push_sent_at: null })
              data = rows.get(id)
            } else if (operation === 'update') {
              Object.assign(rows.get(filters.id as string)!, payload)
            } else data = rows.get(filters.recipient_id as string) ?? null
          }
          if (table === 'push_device_tokens') {
            data = devicesPresent ? [{ id: filters.user_id, fcm_token: filters.user_id }] : []
          }
          return Promise.resolve(resolve({ data, error: null }))
        },
      }
      return query
    },
  }
  const auth = { admin, caller: admin, user: { id: 'tenant' } } as unknown as NonNullable<
    Awaited<ReturnType<typeof authenticatedClients>>
  >
  const run = () =>
    handleRequest(
      new Request('https://example.test', {
        method: 'POST',
        body: JSON.stringify({ event_id: 'event' }),
      }),
      {
        authenticate: async () => auth,
        accessToken: async () => ({ projectId: 'test', token: 'test' }),
        send: async (_auth, token) => {
          sent.push(token)
          return new Response('', { status: token === 'guardian' && failGuardian ? 503 : 200 })
        },
      },
    )
  return {
    rows,
    sent,
    run,
    accept: () => {
      failGuardian = false
    },
    setDevices: (value: boolean) => {
      devicesPresent = value
    },
  }
}

Deno.test('failed guardian push retries its existing row and skips successful staff', async () => {
  const f = fixture()
  assert((await f.run()).status === 503, 'FCM failure incorrectly acknowledged')
  assert(f.rows.get('staff')?.push_sent_at, 'successful staff not marked')
  assert(!f.rows.get('guardian')?.push_sent_at, 'failed guardian marked')
  f.accept()
  assert((await f.run()).status === 200, 'retry did not succeed')
  assert(f.rows.size === 2, 'retry duplicated notification rows')
  assert(f.sent.filter((token) => token === 'staff').length === 1, 'successful staff was sent again')
  assert(f.sent.filter((token) => token === 'guardian').length === 2, 'failed guardian was not retried')
})

Deno.test('recipient without a device token stays pending until registration', async () => {
  const f = fixture()
  f.setDevices(false)
  assert((await f.run()).status === 503, 'missing tokens treated as delivery')
  assert(f.sent.length === 0, 'sent without devices')
  f.setDevices(true)
  f.accept()
  assert((await f.run()).status === 200, 'new device did not receive retry')
  assert(f.rows.size === 2, 'registration retry duplicated rows')
})

Deno.test('fully accepted event is idempotent on retry', async () => {
  const f = fixture()
  f.accept()
  await f.run()
  await f.run()
  assert(f.sent.length === 2, 'already accepted recipients were sent twice')
})
