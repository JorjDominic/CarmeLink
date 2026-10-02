import { authenticatedClients, corsHeaders, json } from '../_shared/cloudinary.ts'
import { fcmAccessToken, sendFcm } from '../_shared/fcm.ts'

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  try {
    const auth = await authenticatedClients(request)
    if (!auth) return json({ error: 'Unauthorized' }, 401)

    const input = await request.json().catch(() => null)
    const tenantId = typeof input?.tenant_id === 'string' ? input.tenant_id : ''
    if (!tenantId) return json({ error: 'Tenant ID is required' }, 400)

    // The caller-scoped RPC is the security boundary: it verifies the guardian
    // link and applies both cooldown and daily limits before recording the audit.
    const { data: requestId, error: requestError } = await auth.caller.rpc(
      'request_tenant_status_update', { p_tenant_id: tenantId },
    )
    if (requestError) {
      const message = requestError.message || 'Unable to request a presence update'
      const limited = message.includes('30 minutes') || message.includes('daily limit')
      return json({ error: message }, limited ? 429 : 403)
    }

    const [{ data: guardian }, { data: tenant }] = await Promise.all([
      auth.admin.from('profiles').select('full_name').eq('id', auth.user.id).single(),
      auth.admin.from('profiles').select('full_name').eq('id', tenantId).single(),
    ])
    const guardianName = guardian?.full_name?.trim() || 'Your guardian'
    const tenantName = tenant?.full_name?.trim() || 'Tenant'
    const title = 'Presence update requested'
    const body = `${guardianName} asked you to refresh your dormitory presence. Turn on Location and open CarmeLink to update your status.`

    const { data: notification, error: notificationError } = await auth.admin
      .from('app_notifications').insert({
        recipient_id: tenantId,
        notification_type: 'safety',
        title,
        body,
        route_type: 'location_status_request',
        route_id: requestId,
        data: {
          request_id: requestId,
          guardian_id: auth.user.id,
          tenant_id: tenantId,
          tenant_name: tenantName,
          action: 'refresh_presence',
        },
      }).select('id').single()
    if (notificationError || !notification) {
      throw new Error(notificationError?.message || 'Unable to create tenant notification')
    }

    const dispatchedAt = new Date().toISOString()
    await auth.admin.from('guardian_status_update_requests')
      .update({ dispatched_at: dispatchedAt }).eq('id', requestId)

    const { data: devices } = await auth.admin.from('push_device_tokens')
      .select('id, fcm_token').eq('user_id', tenantId).is('revoked_at', null)
    let delivered = 0
    const failures: string[] = []

    if ((devices?.length ?? 0) > 0) {
      try {
        const authorization = await fcmAccessToken()
        for (const device of devices ?? []) {
          const response = await sendFcm(authorization, device.fcm_token, title, body, {
            notification_id: notification.id,
            notification_type: 'safety',
            route_type: 'location_status_request',
            route_id: requestId,
            tenant_id: tenantId,
            action: 'refresh_presence',
          })
          if (response.ok) {
            delivered++
          } else {
            const detail = await response.text()
            failures.push(`FCM ${response.status}`)
            if (response.status === 404 || detail.includes('UNREGISTERED')) {
              await auth.admin.from('push_device_tokens')
                .update({ revoked_at: new Date().toISOString() }).eq('id', device.id)
            }
          }
        }
      } catch (error) {
        failures.push(error instanceof Error ? error.message : 'Push delivery failed')
      }
    } else {
      failures.push('Recipient has no active device token')
    }

    await auth.admin.from('app_notifications').update(
      delivered > 0
        ? { push_sent_at: new Date().toISOString(), push_error: failures.length ? failures.join(', ').slice(0, 500) : null }
        : { push_error: failures.join(', ').slice(0, 500) },
    ).eq('id', notification.id)
    if (delivered > 0) {
      await auth.admin.from('guardian_status_update_requests')
        .update({ push_delivered_at: new Date().toISOString() }).eq('id', requestId)
    }

    return json({ request_id: requestId, delivered, cooldown_minutes: 30 })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unable to request a presence update' }, 500)
  }
})
