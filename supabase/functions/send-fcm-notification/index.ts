import { authenticatedClients, corsHeaders, json } from '../_shared/cloudinary.ts'
import { fcmAccessToken, sendFcm } from '../_shared/fcm.ts'

type Profile = { id: string; role: string }
const allowedTypes = new Set(['announcement', 'payment', 'maintenance', 'curfew', 'visitor', 'gate', 'safety', 'onboarding', 'message', 'system'])

function stringList(value: unknown) {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === 'string' && item.length > 0)
    : []
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  try {
    const auth = await authenticatedClients(request)
    if (!auth) return json({ error: 'Unauthorized' }, 401)
    const { data: actor } = await auth.admin.from('profiles').select('id, role').eq('id', auth.user.id).single()
    if (!actor) return json({ error: 'Profile not found' }, 403)

    const input = await request.json().catch(() => null)
    const title = typeof input?.title === 'string' ? input.title.trim() : ''
    const body = typeof input?.body === 'string' ? input.body.trim() : ''
    const type = typeof input?.notification_type === 'string' ? input.notification_type.trim().toLowerCase() : 'system'
    const routeType = typeof input?.route_type === 'string' && input.route_type.trim() ? input.route_type.trim() : null
    const routeId = typeof input?.route_id === 'string' && input.route_id.trim() ? input.route_id.trim() : null
    const tenantId = typeof input?.tenant_id === 'string' ? input.tenant_id : null
    const recipientRole = typeof input?.recipient_role === 'string' ? input.recipient_role.trim().toLowerCase() : null
    if (!title || title.length > 120 || !body || body.length > 500 || !allowedTypes.has(type)) {
      return json({ error: 'Invalid notification' }, 400)
    }

    const isStaff = actor.role === 'owner' || actor.role === 'caretaker'
    const requested = new Set<string>(stringList(input?.recipient_ids))
    if (typeof input?.recipient_id === 'string' && input.recipient_id) requested.add(input.recipient_id)

    const roles = new Set<string>()
    if (recipientRole === 'staff') {
      roles.add('owner'); roles.add('caretaker')
    } else if (recipientRole === 'all') {
      if (!isStaff) return json({ error: 'Only staff may broadcast' }, 403)
      ;['tenant', 'guardian', 'owner', 'caretaker'].forEach((role) => roles.add(role))
    } else if (recipientRole === 'tenant' || recipientRole === 'guardian') {
      if (!isStaff) return json({ error: 'Only staff may broadcast to residents' }, 403)
      roles.add(recipientRole)
    } else if (recipientRole) {
      return json({ error: 'Invalid recipient role' }, 400)
    }
    if (roles.size) {
      const { data, error } = await auth.admin.from('profiles').select('id, role').in('role', [...roles])
      if (error) throw error
      data?.forEach((profile: Profile) => requested.add(profile.id))
    }
    if (tenantId && input?.notify_tenant === true) requested.add(tenantId)
    if (tenantId && input?.notify_guardians === true) {
      const { data, error } = await auth.admin.from('guardian_tenant_links').select('guardian_id').eq('tenant_id', tenantId)
      if (error) throw error
      data?.forEach((link) => requested.add(link.guardian_id))
    }
    requested.delete(actor.id)
    if (!requested.size) return json({ recipients: 0, created: 0, delivered: 0 })

    const { data: recipients, error: recipientError } = await auth.admin.from('profiles').select('id, role').in('id', [...requested])
    if (recipientError) throw recipientError
    const permitted = new Set<string>()
    for (const recipient of recipients ?? []) {
      if (isStaff) {
        if (actor.role === 'owner' || ['tenant', 'guardian'].includes(recipient.role)) permitted.add(recipient.id)
      } else if (['owner', 'caretaker'].includes(recipient.role)) {
        permitted.add(recipient.id)
      } else if (actor.role === 'tenant' && tenantId === actor.id && recipient.role === 'guardian') {
        const { data: link } = await auth.admin.from('guardian_tenant_links')
          .select('id').eq('guardian_id', recipient.id).eq('tenant_id', actor.id).maybeSingle()
        if (link) permitted.add(recipient.id)
      } else if (actor.role === 'tenant' && recipient.id === actor.id) {
        permitted.add(recipient.id)
      } else if (actor.role === 'guardian' && tenantId && recipient.id === tenantId) {
        const { data: link } = await auth.admin.from('guardian_tenant_links')
          .select('id').eq('guardian_id', actor.id).eq('tenant_id', tenantId).maybeSingle()
        if (link) permitted.add(recipient.id)
      }
    }
    if (!permitted.size) return json({ error: 'No permitted recipients' }, 403)

    const clientData = typeof input?.data === 'object' && input.data && !Array.isArray(input.data)
      ? input.data as Record<string, unknown> : {}
    const notificationData = { ...clientData, actor_id: actor.id }
    let fcm: Awaited<ReturnType<typeof fcmAccessToken>> | null = null
    let created = 0, delivered = 0, failed = 0

    for (const recipientId of permitted) {
      const { data: notification, error } = await auth.admin.from('app_notifications').insert({
        recipient_id: recipientId, notification_type: type, title, body,
        route_type: routeType, route_id: routeId, data: notificationData,
      }).select('id').single()
      if (error || !notification) { failed++; continue }
      created++
      const { data: devices, error: deviceError } = await auth.admin.from('push_device_tokens')
        .select('id, fcm_token').eq('user_id', recipientId).is('revoked_at', null)
      if (deviceError) { failed++; continue }
      if ((devices?.length ?? 0) > 0 && !fcm) {
        try {
          fcm = await fcmAccessToken()
        } catch (error) {
          failed += devices?.length ?? 1
          await auth.admin.from('app_notifications').update({
            push_error: error instanceof Error ? error.message : 'FCM credentials unavailable',
          }).eq('id', notification.id)
          continue
        }
      }
      let recipientDelivered = 0
      const errors: string[] = []
      for (const device of devices ?? []) {
        const response = await sendFcm(fcm!, device.fcm_token, title, body, {
          notification_id: notification.id, notification_type: type,
          route_type: routeType ?? '', route_id: routeId ?? '',
        })
        if (response.ok) { delivered++; recipientDelivered++ }
        else {
          failed++
          const detail = await response.text()
          errors.push(`FCM ${response.status}`)
          if (response.status === 404 || detail.includes('UNREGISTERED')) {
            await auth.admin.from('push_device_tokens').update({ revoked_at: new Date().toISOString() }).eq('id', device.id)
          }
        }
      }
      await auth.admin.from('app_notifications').update(recipientDelivered > 0
        ? { push_sent_at: new Date().toISOString(), push_error: errors.length ? errors.join(', ') : null }
        : { push_error: errors.join(', ') || 'Recipient has no active device token' }
      ).eq('id', notification.id)
    }
    return json({ recipients: permitted.size, created, delivered, failed })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unable to send notification' }, 500)
  }
})
