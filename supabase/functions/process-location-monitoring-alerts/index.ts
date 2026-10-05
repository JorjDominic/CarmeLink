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
      .select('id, tenant_id, reason, started_at').is('recovered_at', null)
      .is('escalated_at', null).lte('started_at', cutoff)
    if (error) throw error
    let created = 0, delivered = 0
    let authorization: Awaited<ReturnType<typeof fcmAccessToken>> | null = null
    for (const incident of incidents ?? []) {
      const { data: profile } = await admin.from('profiles').select('full_name')
        .eq('id', incident.tenant_id).maybeSingle()
      const tenantName = profile?.full_name?.trim() || 'A tenant'
      const recipients = new Set<string>()
      const { data: staff } = await admin.from('profiles').select('id').in('role', ['owner', 'caretaker'])
      staff?.forEach((p) => recipients.add(p.id))
      const { data: links } = await admin.from('guardian_tenant_links').select('guardian_id')
        .eq('tenant_id', incident.tenant_id)
      links?.forEach((l) => recipients.add(l.guardian_id))
      const title = `Location monitoring unavailable: ${tenantName}`
      const body = `${tenantName}'s dormitory boundary monitoring has been unavailable for at least 30 minutes.`
      for (const recipientId of recipients) {
        const { data: notification, error: insertError } = await admin.from('app_notifications').insert({
          recipient_id: recipientId, notification_type: 'gate', title, body,
          route_type: 'location_monitoring_incident', route_id: incident.id,
          data: { tenant_id: incident.tenant_id, reason: incident.reason },
        }).select('id').single()
        if (insertError || !notification) continue
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
      await admin.from('location_monitoring_incidents').update({ escalated_at: new Date().toISOString() })
        .eq('id', incident.id).is('recovered_at', null)
    }
    return json({ created, delivered })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unable to process monitoring alerts' }, 500)
  }
})
