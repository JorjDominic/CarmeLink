import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { fcmAccessToken, sendFcm } from '../_shared/fcm.ts'

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  })
}

export async function handleRequest(
  request: Request,
  dependencies: {
    createAdmin?: () => SupabaseClient
    accessToken?: typeof fcmAccessToken
    send?: typeof sendFcm
  } = {},
) {
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405)
  }

  try {
    const bearer = (request.headers.get('Authorization') ?? '')
      .replace(/^Bearer\s+/i, '')
      .trim()
    if (!bearer) return jsonResponse({ error: 'Unauthorized' }, 401)

    const admin = dependencies.createAdmin?.() ?? createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    )

    const digest = await crypto.subtle.digest(
      'SHA-256',
      new TextEncoder().encode(bearer),
    )
    const hash = Array.from(new Uint8Array(digest))
      .map((byte) => byte.toString(16).padStart(2, '0'))
      .join('')

    const { data: credential, error: credentialError } = await admin
      .from('guardian_alert_cron_credentials')
      .select('id')
      .eq('token_hash', hash)
      .eq('is_active', true)
      .maybeSingle()

    if (credentialError || !credential) {
      return jsonResponse({ error: 'Unauthorized' }, 401)
    }

    const { data: jobs, error: claimError } = await admin
      .rpc('claim_report_push_jobs')
    if (claimError) throw claimError

    let authorization: Awaited<ReturnType<typeof fcmAccessToken>> | undefined
    let delivered = 0

    for (const notification of jobs ?? []) {
      try {
        const { data: devices, error: devicesError } = await admin
          .from('push_device_tokens')
          .select('id,fcm_token')
          .eq('user_id', notification.recipient_id)
          .is('revoked_at', null)
        if (devicesError) throw devicesError

        const { data: sent, error: sentError } = await admin
          .from('notification_push_deliveries')
          .select('device_id')
          .eq('notification_id', notification.id)
        if (sentError) throw sentError

        const alreadyDelivered = new Set(
          (sent ?? []).map((entry) => entry.device_id as string),
        )
        let successfulDevices = alreadyDelivered.size

        for (const device of devices ?? []) {
          if (alreadyDelivered.has(device.id)) continue

          authorization ??= await (
            dependencies.accessToken ?? fcmAccessToken
          )()

          const response = await (dependencies.send ?? sendFcm)(
            authorization,
            device.fcm_token,
            notification.title,
            notification.body,
            {
              notification_id: notification.id,
              notification_type: notification.notification_type,
              route_type: notification.route_type ?? '',
              route_id: notification.route_id ?? '',
            },
          )

          if (!response.ok) {
            const detail = await response.text()
            if (response.status === 404 && detail.includes('UNREGISTERED')) {
              const { error: revokeError } = await admin
                .from('push_device_tokens')
                .update({ revoked_at: new Date().toISOString() })
                .eq('id', device.id)
              if (revokeError) throw revokeError
              continue
            }
            throw new Error(`Push delivery failed (${response.status})`)
          }

          const { error: deliveryError } = await admin
            .from('notification_push_deliveries')
            .upsert({
              notification_id: notification.id,
              device_id: device.id,
            })
          if (deliveryError) throw deliveryError

          successfulDevices++
          delivered++
        }

        const now = new Date().toISOString()
        const { error: notificationError } = await admin
          .from('app_notifications')
          .update({
            push_sent_at: successfulDevices > 0 ? now : null,
            push_error: null,
          })
          .eq('id', notification.id)
        if (notificationError) throw notificationError

        const { error: completionError } = await admin
          .from('notification_push_jobs')
          .update({ completed_at: now })
          .eq('notification_id', notification.id)
        if (completionError) throw completionError
      } catch (error) {
        await admin
          .from('app_notifications')
          .update({
            push_error: (
              error instanceof Error ? error.message : 'Push delivery failed'
            ).slice(0, 500),
          })
          .eq('id', notification.id)
      }
    }

    return jsonResponse({ delivered })
  } catch (_) {
    return jsonResponse({ error: 'Unable to process report pushes' }, 500)
  }
}
