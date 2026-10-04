import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders, json } from '../_shared/cloudinary.ts'
import { fcmAccessToken, sendFcm } from '../_shared/fcm.ts'

const encoder = new TextEncoder()
async function sha256(value: string) {
  const digest = await crypto.subtle.digest('SHA-256', encoder.encode(value))
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('')
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  try {
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { autoRefreshToken: false, persistSession: false } })
    const bearer = (request.headers.get('Authorization') ?? '').replace(/^Bearer\s+/, '')
    if (!bearer) return json({ error: 'Unauthorized' }, 401)
    const { data: credential } = await admin.from('guardian_alert_cron_credentials').select('id')
      .eq('token_hash', await sha256(bearer)).eq('is_active', true).maybeSingle()
    if (!credential) return json({ error: 'Unauthorized' }, 401)

    const cutoff = new Date(Date.now() - 30 * 60 * 1000).toISOString()
    const { data: incidents, error } = await admin.from('location_monitoring_incidents')
      .select('id, tenant_id, reason, started_at, guardian_notified_at, escalated_at').is('recovered_at', null)
      .or(`guardian_notified_at.is.null,and(escalated_at.is.null,started_at.lte.${cutoff})`)
    if (error) throw error
    let created = 0, delivered = 0
    let authorization: Awaited<ReturnType<typeof fcmAccessToken>> | null = null
    for (const incident of incidents ?? []) {
      const { data: profile } = await admin.from('profiles').select('full_name')
        .eq('id', incident.tenant_id).maybeSingle()
      const tenantName = profile?.full_name?.trim() || 'A tenant'
      const escalating = !incident.escalated_at && incident.started_at <= cutoff
      const notifyingGuardians = !incident.guardian_notified_at
      const recipients = new Set<string>()
      if (escalating) {
        const { data: staff, error: staffError } = await admin.from('profiles').select('id').in('role', ['owner', 'caretaker'])
        if (staffError) throw staffError
        staff?.forEach((p) => recipients.add(p.id))
      }
      const { data: links, error: linksError } = await admin.from('guardian_tenant_links').select('guardian_id')
        .eq('tenant_id', incident.tenant_id)
      if (linksError) throw linksError
      links?.forEach((l) => recipients.add(l.guardian_id))
      const title = escalating
        ? `Location monitoring unavailable: ${tenantName}`
        : `Location monitoring is off: ${tenantName}`
      const body = escalating
        ? `${tenantName}'s dormitory boundary monitoring has been unavailable for at least 30 minutes.`
        : `${tenantName}'s location monitoring is off. Entry and exit alerts are unavailable until location services and permissions are restored.`
      for (const recipientId of recipients) {
        const { data: notification, error: insertError } = await admin.from('app_notifications').insert({
          recipient_id: recipientId, notification_type: 'gate', title, body,
          route_type: 'location_monitoring_incident', route_id: incident.id,
          data: { tenant_id: incident.tenant_id, reason: incident.reason },
        }).select('id').single()
        if (insertError) throw insertError
        if (!notification) throw new Error('Notification was not created')
        created++
        const { data: devices } = await admin.from('push_device_tokens').select('fcm_token')
          .eq('user_id', recipientId).is('revoked_at', null)
        if ((devices?.length ?? 0) && !authorization) authorization = await fcmAccessToken()
        for (const device of devices ?? []) {
          const response = await sendFcm(authorization!, device.fcm_token, title, body, {
            notification_id: notification.id, notification_type: 'gate',
            route_type: 'location_monitoring_incident', route_id: incident.id,
            tenant_id: incident.tenant_id,
          })
          if (response.ok) delivered++
        }
      }
      const notifiedAt = new Date().toISOString()
      const { error: updateError } = await admin.from('location_monitoring_incidents').update({
        ...(notifyingGuardians ? { guardian_notified_at: notifiedAt } : {}),
        ...(escalating ? { escalated_at: notifiedAt } : {}),
      })
        .eq('id', incident.id).is('recovered_at', null)
      if (updateError) throw updateError
    }
    return json({ created, delivered })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unable to process monitoring alerts' }, 500)
  }
})
