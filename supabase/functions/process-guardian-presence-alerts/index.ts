import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders, json } from '../_shared/cloudinary.ts'
import { fcmAccessToken, sendFcm } from '../_shared/fcm.ts'

const encoder = new TextEncoder()

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', encoder.encode(value))
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

async function stableUuid(value: string): Promise<string> {
  const hex = await sha256(value)
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-5${hex.slice(13, 16)}-a${hex.slice(17, 20)}-${hex.slice(20, 32)}`
}

// Invoked every minute by pg_cron. The scheduler owns the raw bearer token;
// only its SHA-256 hash is retained in the database.
Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  try {
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    )
    const authorizationHeader = request.headers.get('Authorization') ?? ''
    const bearerToken = authorizationHeader.startsWith('Bearer ')
      ? authorizationHeader.slice('Bearer '.length).trim()
      : ''
    if (!bearerToken) return json({ error: 'Unauthorized' }, 401)

    const tokenHash = await sha256(bearerToken)
    const { data: credential, error: credentialError } = await admin
      .from('guardian_alert_cron_credentials')
      .select('id')
      .eq('token_hash', tokenHash)
      .eq('is_active', true)
      .maybeSingle()
    if (credentialError) throw credentialError
    if (!credential) return json({ error: 'Unauthorized' }, 401)

    const nowParts = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Manila', year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
    }).formatToParts(new Date())
    const part = (type: string) => nowParts.find((item) => item.type === type)?.value ?? ''
    const today = `${part('year')}-${part('month')}-${part('day')}`
    const currentMinutes = Number(part('hour')) * 60 + Number(part('minute'))

    const { data: preferences, error: preferenceError } = await admin
      .from('guardian_alert_preferences')
      .select('guardian_id, alert_cutoff, outside_after_cutoff_enabled, inside_after_cutoff_enabled, updated_at')
      .or('outside_after_cutoff_enabled.eq.true,inside_after_cutoff_enabled.eq.true')
    if (preferenceError) throw preferenceError

    let created = 0, delivered = 0
    let authorization: Awaited<ReturnType<typeof fcmAccessToken>> | null = null
    for (const preference of preferences ?? []) {
      const [hour, minute] = String(preference.alert_cutoff).split(':').map(Number)
      if (currentMinutes < hour * 60 + minute) continue
      const { data: links } = await admin.from('guardian_tenant_links')
        .select('tenant_id').eq('guardian_id', preference.guardian_id)
      for (const link of links ?? []) {
        const { data: tenant } = await admin.from('tenant_details')
          .select('current_gate_status')
          .eq('profile_id', link.tenant_id).maybeSingle()
        if (!tenant) continue

        const isOut = tenant.current_gate_status === 'OUT'
        const isIn = tenant.current_gate_status === 'IN'

        const shouldAlertOutside = preference.outside_after_cutoff_enabled && isOut
        const shouldAlertInside = preference.inside_after_cutoff_enabled && isIn

        if (!shouldAlertOutside && !shouldAlertInside) continue

        const conditionKey = shouldAlertOutside ? 'outside' : 'inside'
        // One alert per condition and saved preference revision. Including the
        // revision lets a guardian change today's cutoff and receive the newly
        // requested alert, while the minute scheduler still cannot spam the
        // same preference repeatedly.
        const preferenceRevision = preference.updated_at ?? preference.alert_cutoff
        const deduplicationKey = `${preference.guardian_id}:${link.tenant_id}:${today}:${conditionKey}:${preferenceRevision}`
        const routeId = await stableUuid(deduplicationKey)
        const { data: existing } = await admin.from('app_notifications').select('id')
          .eq('recipient_id', preference.guardian_id)
          .eq('route_type', 'guardian_presence_alert').eq('route_id', routeId).maybeSingle()
        if (existing) continue
        const { data: profile } = await admin.from('profiles')
          .select('full_name').eq('id', link.tenant_id).maybeSingle()
        const tenantName = profile?.full_name?.trim() || 'Your linked resident'
        const title = shouldAlertOutside
          ? `Resident outside dormitory property: ${tenantName}`
          : `Resident inside dormitory property: ${tenantName}`
        const body = shouldAlertOutside
          ? `${tenantName} is still outside the dormitory property after your preferred alert time.`
          : `${tenantName} is inside the dormitory property after your preferred alert time.`
        const { data: notification, error } = await admin.from('app_notifications').insert({
          recipient_id: preference.guardian_id, notification_type: 'gate', title, body,
          route_type: 'guardian_presence_alert', route_id: routeId,
          data: {
            tenant_id: link.tenant_id,
            local_date: today,
            condition: conditionKey,
            alert_cutoff: preference.alert_cutoff,
            preference_revision: preferenceRevision,
          },
        }).select('id').single()
        if (error || !notification) continue
        created++
        const { data: devices } = await admin.from('push_device_tokens')
          .select('id, fcm_token').eq('user_id', preference.guardian_id).is('revoked_at', null)
        if ((devices?.length ?? 0) && !authorization) authorization = await fcmAccessToken()
        let sent = 0
        for (const device of devices ?? []) {
          const response = await sendFcm(authorization!, device.fcm_token, title, body, {
            notification_id: notification.id, notification_type: 'gate',
            route_type: 'guardian_presence_alert', route_id: routeId,
            tenant_id: link.tenant_id,
          })
          if (response.ok) { delivered++; sent++ }
          else {
            const detail = await response.text()
            if (response.status === 404 || detail.includes('UNREGISTERED')) {
              await admin.from('push_device_tokens').update({ revoked_at: new Date().toISOString() }).eq('id', device.id)
            }
          }
        }
        await admin.from('app_notifications').update(sent > 0
          ? { push_sent_at: new Date().toISOString(), push_error: null }
          : { push_error: 'Guardian has no active device token' }).eq('id', notification.id)
      }
    }
    return json({ created, delivered, local_date: today })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unable to process guardian alerts' }, 500)
  }
})
