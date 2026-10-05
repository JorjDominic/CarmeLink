import { authenticatedClients, corsHeaders, json } from '../_shared/cloudinary.ts'
import { fcmAccessToken, sendFcm } from '../_shared/fcm.ts'

export async function handleRequest(request: Request, dependencies: {
  authenticate?: typeof authenticatedClients
  accessToken?: typeof fcmAccessToken
  send?: typeof sendFcm
} = {}) {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  try {
    const auth = await (dependencies.authenticate ?? authenticatedClients)(request)
    if (!auth) return json({ error: 'Unauthorized' }, 401)
    const body = await request.json().catch(() => null)
    const eventId = typeof body?.event_id === 'string' ? body.event_id : ''
    if (!eventId) return json({ error: 'Event ID is required' }, 400)

    const { data: event, error: eventError } = await auth.admin.from('gate_events')
      .select('id, tenant_id, direction, status, verification_method, checked_at, created_by')
      .eq('id', eventId).single()
    if (eventError) throw new Error(`Unable to load gate event: ${eventError.message}`)
    if (!event) return json({ error: 'Event not found' }, 404)

    const { data: actor } = await auth.admin.from('profiles').select('id, role').eq('id', auth.user.id)
      .single()
    const isStaff = actor?.role === 'owner' || actor?.role === 'caretaker'
    if (!isStaff && event.created_by !== auth.user.id && event.tenant_id !== auth.user.id) {
      return json({ error: 'Unauthorized to notify for this event' }, 403)
    }

    if (event.direction !== 'IN' && event.direction !== 'OUT') {
      return json({ delivered: 0, recipients: 0, reason: 'no_presence_transition' })
    }

    const { data: previous } = await auth.admin.from('gate_events')
      .select('direction, status')
      .eq('tenant_id', event.tenant_id)
      .neq('id', event.id)
      .not('direction', 'is', null)
      .lt('checked_at', event.checked_at)
      .order('checked_at', { ascending: false })
      .limit(1)
      .maybeSingle()
    if (previous?.direction === event.direction && previous?.status === event.status) {
      return json({ delivered: 0, recipients: 0, reason: 'unchanged_presence' })
    }

    // Load tenant name so notifications are clear and personalized for guardians and staff
    const { data: tenantProfile } = await auth.admin.from('profiles')
      .select('full_name').eq('id', event.tenant_id).maybeSingle()
    const tenantName = tenantProfile?.full_name?.trim() || 'A tenant'

    const recipients = new Set<string>()
    const guardianIds = new Set<string>()

    const { data: staff, error: staffError } = await auth.admin.from('profiles')
      .select('id').in('role', ['owner', 'caretaker'])
    if (staffError) throw new Error(`Unable to load staff recipients: ${staffError.message}`)
    staff?.forEach((profile) => recipients.add(profile.id))

    const { data: guardianLinks, error: guardianError } = await auth.admin
      .from('guardian_tenant_links').select('guardian_id').eq('tenant_id', event.tenant_id)
    if (guardianError) throw new Error(`Unable to load guardian recipients: ${guardianError.message}`)
    guardianLinks?.forEach((link) => {
      recipients.add(link.guardian_id)
      guardianIds.add(link.guardian_id)
    })

    // Guardian gate notifications honor durable per-account preferences.
    if (guardianIds.size) {
      const { data: preferences, error: preferenceError } = await auth.admin
        .from('guardian_alert_preferences')
        .select('guardian_id, gate_entry_enabled, gate_exit_enabled')
        .in('guardian_id', [...guardianIds])
      if (preferenceError) {
        throw new Error(`Unable to load guardian alert preferences: ${preferenceError.message}`)
      }
      const byGuardian = new Map((preferences ?? []).map((item) => [item.guardian_id, item]))
      for (const guardianId of guardianIds) {
        const preference = byGuardian.get(guardianId)
        const enabled = event.direction === 'IN'
          ? preference?.gate_entry_enabled !== false
          : preference?.gate_exit_enabled !== false
        if (!enabled) recipients.delete(guardianId)
      }
    }

    if (event.verification_method === 'Staff Manual Log') recipients.add(event.tenant_id)
    recipients.delete(auth.user.id)
    if (!recipients.size) return json({ delivered: 0, recipients: 0 })

    const flagged = event.status === 'Flagged'
    const authorization = await (dependencies.accessToken ?? fcmAccessToken)()
    let delivered = 0
    let pending = 0

    for (const recipientId of recipients) {
      const isGuardian = guardianIds.has(recipientId)
      let title: string
      let notificationBody: string

      if (isGuardian) {
        if (flagged) {
          title = `⚠️ Curfew Alert: ${tenantName}`
          notificationBody = `${tenantName} was detected outside during curfew hours.`
        } else if (event.direction === 'IN') {
          title = `🏠 Dorm Arrival: ${tenantName}`
          notificationBody = `${tenantName} entered the dormitory property.`
        } else {
          title = `🚪 Dorm Departure: ${tenantName}`
          notificationBody = `${tenantName} exited the dormitory property.`
        }
      } else {
        if (flagged) {
          title = `⚠️ Curfew Alert: ${tenantName}`
          notificationBody = `${tenantName} was recorded outside during curfew hours.`
        } else if (event.direction === 'IN') {
          title = `🏠 Gate Entry: ${tenantName}`
          notificationBody = `${tenantName} entered the dormitory property.`
        } else {
          title = `🚪 Gate Exit: ${tenantName}`
          notificationBody = `${tenantName} exited the dormitory property.`
        }
      }

      const { data: existing, error: existingError } = await auth.admin.from('app_notifications')
        .select('id, push_sent_at').eq('recipient_id', recipientId).eq('notification_type', 'gate')
        .eq('route_type', 'gate_event').eq('route_id', event.id).maybeSingle()
      if (existingError) throw existingError
      if (existing?.push_sent_at) continue

      let notification = existing
      if (!notification) {
        const { data: inserted, error: insertError } = await auth.admin
          .from('app_notifications').insert({
            recipient_id: recipientId,
            notification_type: 'gate',
            title,
            body: notificationBody,
            route_type: 'gate_event',
            route_id: event.id,
            data: {
              direction: event.direction,
              status: event.status,
              tenant_id: event.tenant_id,
              tenant_name: tenantName,
            },
          }).select('id, push_sent_at').single()
        if (insertError || !inserted) {
          pending++
          continue
        }
        notification = inserted
      }
      if (!notification) {
        pending++
        continue
      }

      const { data: devices, error: devicesError } = await auth.admin.from('push_device_tokens')
        .select('id, fcm_token').eq('user_id', recipientId).is('revoked_at', null)
      if (devicesError) throw devicesError
      let recipientDelivered = 0
      const failures: string[] = []
      for (const device of devices ?? []) {
        const response = await (dependencies.send ?? sendFcm)(
          authorization,
          device.fcm_token,
          title,
          notificationBody,
          {
            notification_id: notification.id,
            notification_type: 'gate',
            route_type: 'gate_event',
            route_id: event.id,
            tenant_id: event.tenant_id,
            direction: event.direction,
          },
        )
        if (response.ok) {
          recipientDelivered++
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
      if (!recipientDelivered) pending++
      const { error: updateError } = await auth.admin.from('app_notifications').update(
        recipientDelivered > 0
          ? {
            push_sent_at: new Date().toISOString(),
            push_error: failures.length ? failures.join(', ') : null,
          }
          : { push_error: failures.join(', ') || 'Recipient has no active device token' },
      ).eq('id', notification.id)
      if (updateError) throw updateError
    }

    // A retry must reuse unsent rows, rather than treating their existence as delivery.
    return json({ delivered, recipients: recipients.size, pending }, pending ? 503 : 200)
  } catch (error) {
    return json(
      { error: error instanceof Error ? error.message : 'Unable to notify geofence recipients' },
      500,
    )
  }
}
