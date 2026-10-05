import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders, json } from '../_shared/cloudinary.ts'
import { fcmAccessToken, sendFcm } from '../_shared/fcm.ts'

const encoder = new TextEncoder()
async function sha256(value: string) {
  const digest = await crypto.subtle.digest('SHA-256', encoder.encode(value))
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('')
}

// Stable notification identity makes cron retries safe for recipients already sent.
async function notificationId(
  incidentId: string,
  recipientId: string,
  stage: string,
) {
  const hash = await sha256(
    `location-health:${incidentId}:${recipientId}:${stage}`,
  )
  return `${hash.slice(0, 8)}-${hash.slice(8, 12)}-5${hash.slice(13, 16)}-a${hash.slice(17, 20)}-${
    hash.slice(20, 32)
  }`
}

export async function handleRequest(request: Request, dependencies: {
  createAdmin?: () => SupabaseClient
  accessToken?: typeof fcmAccessToken
  send?: typeof sendFcm
} = {}) {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (request.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405)
  }
  try {
    const admin = dependencies.createAdmin?.() ??
      createClient(
        Deno.env.get('SUPABASE_URL')!,
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
        { auth: { autoRefreshToken: false, persistSession: false } },
      )
    const bearer = (request.headers.get('Authorization') ?? '').replace(
      /^Bearer\s+/,
      '',
    )
    if (!bearer) return json({ error: 'Unauthorized' }, 401)
    const { data: credential } = await admin.from(
      'guardian_alert_cron_credentials',
    ).select('id')
      .eq('token_hash', await sha256(bearer)).eq('is_active', true)
      .maybeSingle()
    if (!credential) return json({ error: 'Unauthorized' }, 401)

    const rawBody = await request.text()
    let body: { incident_id?: unknown }
    try {
      body = rawBody ? JSON.parse(rawBody) : {}
    } catch {
      return json({ error: 'Invalid JSON' }, 400)
    }
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      return json({ error: 'Invalid request' }, 400)
    }
    if (
      body.incident_id !== undefined && (typeof body.incident_id !== 'string' ||
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.incident_id))
    ) {
      return json({ error: 'Invalid incident_id' }, 400)
    }
    const cutoff = new Date(Date.now() - 30 * 60 * 1000).toISOString()
    const { data: incidents, error } = await admin.rpc('claim_location_monitoring_alerts', {
      p_incident_id: body.incident_id ?? null,
    })
    if (error) throw error
    let created = 0, delivered = 0
    let authorization: Awaited<ReturnType<typeof fcmAccessToken>> | null = null
    for (const incident of incidents ?? []) {
      const { data: profile } = await admin.from('profiles').select('full_name')
        .eq('id', incident.tenant_id).maybeSingle()
      const tenantName = profile?.full_name?.trim() || 'A tenant'
      const escalating = !incident.escalated_at &&
        incident.started_at <= cutoff
      const notifyingGuardians = !incident.guardian_notified_at
      const recipients = new Set<string>()
      if (escalating) {
        const { data: staff, error: staffError } = await admin.from('profiles')
          .select('id').in('role', ['owner', 'caretaker'])
        if (staffError) throw staffError
        staff?.forEach((p) => recipients.add(p.id))
      }
      const { data: links, error: linksError } = await admin.from(
        'guardian_tenant_links',
      ).select('guardian_id')
        .eq('tenant_id', incident.tenant_id)
      if (linksError) throw linksError
      links?.forEach((l) => recipients.add(l.guardian_id))
      const title = escalating
        ? `Location monitoring unavailable: ${tenantName}`
        : `Location monitoring is off: ${tenantName}`
      const body = escalating
        ? `${tenantName}'s dormitory boundary monitoring has been unavailable for at least 30 minutes.`
        : `${tenantName}'s location monitoring is off. Entry and exit alerts are unavailable until location services and permissions are restored.`
      let allDelivered = recipients.size > 0
      for (const recipientId of recipients) {
        const id = await notificationId(
          incident.id,
          recipientId,
          escalating ? 'escalation' : 'initial',
        )
        const { error: insertError } = await admin.from('app_notifications')
          .upsert({
            id,
            recipient_id: recipientId,
            notification_type: 'gate',
            title,
            body,
            route_type: 'location_monitoring_incident',
            route_id: incident.id,
            data: { tenant_id: incident.tenant_id, reason: incident.reason },
          }, { onConflict: 'id', ignoreDuplicates: true })
        if (insertError) throw insertError
        const { data: notification, error: notificationError } = await admin
          .from('app_notifications')
          .select('id, push_sent_at').eq('id', id).single()
        if (notificationError) throw notificationError
        if (!notification) throw new Error('Notification was not created')
        if (notification.push_sent_at) continue
        created++
        const { data: devices, error: devicesError } = await admin.from(
          'push_device_tokens',
        ).select('id, fcm_token')
          .eq('user_id', recipientId).is('revoked_at', null)
        if (devicesError) throw devicesError
        let sent = false
        const failures: string[] = []
        if ((devices?.length ?? 0) && !authorization) {
          try {
            authorization = await (dependencies.accessToken ?? fcmAccessToken)()
          } catch (error) {
            failures.push(
              error instanceof Error ? error.message : 'FCM credentials unavailable',
            )
          }
        }
        for (const device of devices ?? []) {
          if (!authorization) break
          try {
            const response = await (dependencies.send ?? sendFcm)(
              authorization,
              device.fcm_token,
              title,
              body,
              {
                notification_id: notification.id,
                notification_type: 'gate',
                route_type: 'location_monitoring_incident',
                route_id: incident.id,
                tenant_id: incident.tenant_id,
              },
            )
            if (response.ok) {
              sent = true
              delivered++
            } else {
              const detail = await response.text()
              failures.push(`FCM ${response.status}: ${detail}`)
              if (response.status === 404 && detail.includes('UNREGISTERED')) {
                const { error: revokeError } = await admin.from(
                  'push_device_tokens',
                )
                  .update({ revoked_at: new Date().toISOString() }).eq(
                    'id',
                    device.id,
                  )
                if (revokeError) throw revokeError
              }
            }
          } catch (error) {
            failures.push(
              error instanceof Error ? error.message : 'Push delivery failed',
            )
          }
        }
        const { error: deliveryError } = await admin.from('app_notifications')
          .update({
            push_sent_at: sent ? new Date().toISOString() : null,
            push_error: failures.length
              ? failures.join(', ').slice(0, 500)
              : sent
              ? null
              : 'Recipient has no active device token',
          }).eq('id', notification.id)
        if (deliveryError) throw deliveryError
        if (!sent) allDelivered = false
      }
      // Leave unsuccessful incidents pending for the next scheduled attempt.
      if (!allDelivered) {
        const { error: releaseError } = await admin.from('location_monitoring_incidents')
          .update({ dispatch_claimed_until: null }).eq('id', incident.id)
        if (releaseError) throw releaseError
        continue
      }
      const notifiedAt = new Date().toISOString()
      const { error: updateError } = await admin.from(
        'location_monitoring_incidents',
      ).update({
        dispatch_claimed_until: null,
        ...(notifyingGuardians ? { guardian_notified_at: notifiedAt } : {}),
        ...(escalating ? { escalated_at: notifiedAt } : {}),
      })
        .eq('id', incident.id).is('recovered_at', null)
      if (updateError) throw updateError
    }
    return json({ created, delivered })
  } catch (error) {
    return json({
      error: error instanceof Error ? error.message : 'Unable to process monitoring alerts',
    }, 500)
  }
}
