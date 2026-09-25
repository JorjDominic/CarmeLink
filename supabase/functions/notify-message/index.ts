import { authenticatedClients, corsHeaders, json } from '../_shared/cloudinary.ts'
import { fcmAccessToken, sendFcm } from '../_shared/fcm.ts'

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  try {
    const auth = await authenticatedClients(request)
    if (!auth) return json({ error: 'Unauthorized' }, 401)
    const body = await request.json().catch(() => null)
    const messageId = typeof body?.message_id === 'string' ? body.message_id : ''
    if (!messageId) return json({ error: 'Message ID is required' }, 400)

    const { data: message, error: messageError } = await auth.admin.from('messages')
      .select('id, conversation_id, sender_id, conversations!inner(type, tenant_id, guardian_id), profiles!sender_id(full_name)')
      .eq('id', messageId).single()
    if (messageError) throw new Error(`Unable to load message: ${messageError.message}`)
    if (!message || message.sender_id !== auth.user.id) return json({ error: 'Message not found' }, 404)

    const conversation = Array.isArray(message.conversations)
      ? message.conversations[0]
      : message.conversations
    const senderProfile = Array.isArray(message.profiles) ? message.profiles[0] : message.profiles
    const recipients = new Set<string>()
    if (conversation.type === 'tenant_management') {
      if (message.sender_id === conversation.tenant_id) {
        const { data: staff } = await auth.admin.from('profiles').select('id').eq('role', 'owner_caretaker')
        staff?.forEach((profile) => recipients.add(profile.id))
      } else if (conversation.tenant_id) recipients.add(conversation.tenant_id)
    } else if (conversation.type === 'guardian_management') {
      if (message.sender_id === conversation.guardian_id) {
        const { data: staff } = await auth.admin.from('profiles').select('id').eq('role', 'owner_caretaker')
        staff?.forEach((profile) => recipients.add(profile.id))
      } else if (conversation.guardian_id) recipients.add(conversation.guardian_id)
    } else if (conversation.type === 'internal_staff') {
      const { data: staff } = await auth.admin.from('profiles').select('id').eq('role', 'owner_caretaker').neq('id', message.sender_id)
      staff?.forEach((profile) => recipients.add(profile.id))
    }
    recipients.delete(message.sender_id)
    if (!recipients.size) return json({ delivered: 0, recipients: 0 })

    const senderName = senderProfile?.full_name?.trim() || 'CarmeLink user'
    const title = 'New message'
    const notificationBody = `You have a new message from ${senderName}.`
    const fcm = await fcmAccessToken()
    let delivered = 0

    for (const recipientId of recipients) {
      const { data: notification, error } = await auth.admin.from('app_notifications').insert({
        recipient_id: recipientId,
        notification_type: 'message',
        title,
        body: notificationBody,
        route_type: 'conversation',
        route_id: message.conversation_id,
        data: { message_id: message.id },
      }).select('id').single()
      if (error || !notification) continue

      const { data: devices } = await auth.admin.from('push_device_tokens')
        .select('id, fcm_token').eq('user_id', recipientId).is('revoked_at', null)
      let recipientDelivered = 0
      const failures: string[] = []
      for (const device of devices ?? []) {
        const response = await sendFcm(fcm, device.fcm_token, title, notificationBody, {
          notification_id: notification.id,
          notification_type: 'message',
          route_type: 'conversation',
          route_id: message.conversation_id,
        })
        if (response.ok) {
          recipientDelivered++
          delivered++
        } else {
          const detail = await response.text()
          failures.push(`FCM ${response.status}`)
          if (response.status === 404 || detail.includes('UNREGISTERED')) {
            await auth.admin.from('push_device_tokens').update({ revoked_at: new Date().toISOString() }).eq('id', device.id)
          }
        }
      }
      await auth.admin.from('app_notifications').update(
        recipientDelivered > 0
          ? { push_sent_at: new Date().toISOString(), push_error: failures.length ? failures.join(', ') : null }
          : { push_error: failures.join(', ') || 'Recipient has no active device token' },
      ).eq('id', notification.id)
    }
    return json({ delivered, recipients: recipients.size })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unable to notify message recipients' }, 500)
  }
})
