import { authenticatedClients, corsHeaders, json } from '../_shared/cloudinary.ts'

const encoder = new TextEncoder()

function base64Url(value: Uint8Array | string) {
  const bytes = typeof value === 'string' ? encoder.encode(value) : value
  let binary = ''
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '')
}

async function accessToken() {
  const projectId = Deno.env.get('FCM_PROJECT_ID')
  const clientEmail = Deno.env.get('FCM_CLIENT_EMAIL')
  const privateKey = Deno.env.get('FCM_PRIVATE_KEY')?.replaceAll('\\n', '\n')
  if (!projectId || !clientEmail || !privateKey) throw new Error('FCM server credentials are not configured')

  const now = Math.floor(Date.now() / 1000)
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const claims = base64Url(JSON.stringify({
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }))
  const unsigned = `${header}.${claims}`
  const der = Uint8Array.from(
    atob(privateKey.replace(/-----[^-]+-----/g, '').replace(/\s/g, '')),
    (character) => character.charCodeAt(0),
  )
  const key = await crypto.subtle.importKey(
    'pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  )
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, encoder.encode(unsigned))
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion,
    }),
  })
  const result = await response.json()
  if (!response.ok || !result.access_token) throw new Error('Unable to authorize FCM delivery')
  return { projectId, token: result.access_token as string }
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  try {
    const auth = await authenticatedClients(request)
    if (!auth) return json({ error: 'Unauthorized' }, 401)

    const { data: actor } = await auth.admin.from('profiles').select('role').eq('id', auth.user.id).single()
    if (!actor || !['owner', 'caretaker'].includes(actor.role)) return json({ error: 'Forbidden' }, 403)

    const body = await request.json().catch(() => null)
    const recipientId = typeof body?.recipient_id === 'string' ? body.recipient_id : ''
    const title = typeof body?.title === 'string' ? body.title.trim() : ''
    const messageBody = typeof body?.body === 'string' ? body.body.trim() : ''
    const type = typeof body?.notification_type === 'string' ? body.notification_type : 'system'
    const routeType = typeof body?.route_type === 'string' ? body.route_type : null
    const routeId = typeof body?.route_id === 'string' ? body.route_id : null
    if (!recipientId || !title || title.length > 120 || !messageBody || messageBody.length > 500) {
      return json({ error: 'Invalid notification' }, 400)
    }

    const { data: recipient } = await auth.admin.from('profiles').select('role').eq('id', recipientId).single()
    if (!recipient || (actor.role === 'caretaker' && !['tenant', 'guardian'].includes(recipient.role))) {
      return json({ error: 'Recipient is outside your permitted scope' }, 403)
    }

    const { data: notification, error: insertError } = await auth.admin.from('app_notifications').insert({
      recipient_id: recipientId,
      notification_type: type,
      title,
      body: messageBody,
      route_type: routeType,
      route_id: routeId,
      data: typeof body?.data === 'object' && body.data ? body.data : {},
    }).select('id').single()
    if (insertError || !notification) throw insertError ?? new Error('Notification was not created')

    const { data: devices, error: deviceError } = await auth.admin.from('push_device_tokens')
      .select('id, fcm_token').eq('user_id', recipientId).is('revoked_at', null)
    if (deviceError) throw deviceError
    if (!devices?.length) return json({ notification_id: notification.id, delivered: 0, unavailable: true })

    const fcm = await accessToken()
    let delivered = 0
    const errors: string[] = []
    for (const device of devices) {
      const response = await fetch(`https://fcm.googleapis.com/v1/projects/${fcm.projectId}/messages:send`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${fcm.token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: {
          token: device.fcm_token,
          notification: { title, body: messageBody },
          data: {
            notification_id: notification.id,
            notification_type: type,
            route_type: routeType ?? '',
            route_id: routeId ?? '',
          },
          android: { priority: 'high', notification: { channel_id: 'carmelink_updates' } },
          apns: { payload: { aps: { sound: 'default', content_available: true } } },
        } }),
      })
      if (response.ok) {
        delivered++
      } else {
        const detail = await response.text()
        errors.push(`FCM ${response.status}`)
        if (response.status === 404 || detail.includes('UNREGISTERED')) {
          await auth.admin.from('push_device_tokens').update({ revoked_at: new Date().toISOString() }).eq('id', device.id)
        }
      }
    }

    await auth.admin.from('app_notifications').update(
      delivered > 0
        ? { push_sent_at: new Date().toISOString(), push_error: errors.length ? errors.join(', ') : null }
        : { push_error: errors.join(', ') || 'No active delivery succeeded' },
    ).eq('id', notification.id)

    return json({ notification_id: notification.id, delivered, failed: errors.length })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unable to send notification' }, 500)
  }
})
