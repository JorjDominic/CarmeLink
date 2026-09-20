import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...cors, 'Content-Type': 'application/json' },
})

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  const authorization = request.headers.get('Authorization')
  if (!authorization?.startsWith('Bearer ')) return json({ error: 'Unauthorized' }, 401)

  const url = Deno.env.get('SUPABASE_URL')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  })
  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const { data: authData, error: authError } = await caller.auth.getUser()
  if (authError || !authData.user) return json({ error: 'Unauthorized' }, 401)

  const { data: actor } = await admin
    .from('profiles')
    .select('role')
    .eq('id', authData.user.id)
    .single()
  if (!actor || !['owner', 'caretaker'].includes(actor.role)) {
    return json({ error: 'Forbidden' }, 403)
  }

  const body = await request.json().catch(() => ({}))
  const action = body.action

  if (action === 'list') {
    const { data: profiles, error } = await admin
      .from('profiles')
      .select('id, full_name, role, phone, created_at, email_verification_sent_at, email_verified_at, email_verification_attempts, email_verification_window_started_at, phone_verified_at')
      .order('created_at')
    if (error) return json({ error: error.message }, 400)

    const visible = actor.role === 'owner'
      ? profiles
      : profiles.filter((profile) => ['tenant', 'guardian'].includes(profile.role))
    const accounts = await Promise.all(visible.map(async (profile) => {
      const { data } = await admin.auth.admin.getUserById(profile.id)
      const confirmedAt = data.user?.email_confirmed_at ?? null
      if (confirmedAt && !profile.email_verified_at) {
        await admin.from('profiles').update({ email_verified_at: confirmedAt }).eq('id', profile.id)
      }
      return {
        ...profile,
        email: data.user?.email ?? '',
        email_verified_at: profile.email_verified_at ?? confirmedAt,
        email_verification_status: (profile.email_verified_at ?? confirmedAt) ? 'verified' : 'pending',
        phone_verification_status: profile.phone_verified_at ? 'verified' : 'on_hold',
      }
    }))
    return json({ accounts })
  }

  const targetId = body.id
  if (typeof targetId !== 'string' || !targetId) {
    return json({ error: 'Account ID is required' }, 400)
  }
  const { data: target } = await admin
    .from('profiles')
    .select('id, full_name, role, phone')
    .eq('id', targetId)
    .single()
  if (!target) return json({ error: 'Account not found' }, 404)

  if (actor.role === 'caretaker' && !['tenant', 'guardian'].includes(target.role)) {
    return json({ error: 'Caretakers can manage only tenant and guardian accounts' }, 403)
  }

  if (action === 'resend_verification') {
    const { data: profile } = await admin.from('profiles')
      .select('email_verified_at, email_verification_sent_at, email_verification_attempts, email_verification_window_started_at')
      .eq('id', targetId).single()
    if (profile?.email_verified_at) return json({ error: 'Email is already verified' }, 400)

    const now = Date.now()
    const lastSent = profile?.email_verification_sent_at
      ? new Date(profile.email_verification_sent_at).getTime() : 0
    if (now - lastSent < 60_000) {
      return json({ error: 'Wait 60 seconds before resending verification' }, 429)
    }
    const windowStart = profile?.email_verification_window_started_at
      ? new Date(profile.email_verification_window_started_at).getTime() : 0
    const inWindow = now - windowStart < 86_400_000
    const attempts = inWindow ? (profile?.email_verification_attempts ?? 0) : 0
    if (attempts >= 5) {
      return json({ error: 'Daily verification email limit reached' }, 429)
    }

    const { data: authUser } = await admin.auth.admin.getUserById(targetId)
    const targetEmail = authUser.user?.email
    if (!targetEmail) return json({ error: 'Account email not found' }, 404)
    const resendClient = createClient(url, anonKey, { auth: { persistSession: false } })
    const { error: resendError } = await resendClient.auth.resend({
      type: 'signup',
      email: targetEmail,
    })
    if (resendError) {
      return json({ error: resendError.message ?? 'Unable to send verification code' }, 400)
    }

    const sentAt = new Date(now).toISOString()
    await admin.from('profiles').update({
      email_verification_sent_at: sentAt,
      email_verification_window_started_at: new Date(inWindow ? windowStart : now).toISOString(),
      email_verification_attempts: attempts + 1,
      invitation_email_id: null,
    }).eq('id', targetId)
    return json({ sent: true, sent_at: sentAt, attempts: attempts + 1 })
  }

  if (action === 'update') {
    const fullName = body.full_name?.trim()
    const phone = body.phone?.trim() ?? ''
    const email = body.email?.trim()?.toLowerCase()
    if (!fullName || !email || !email.includes('@')) {
      return json({ error: 'A full name and valid email are required' }, 400)
    }

    const { data: oldAuth, error: oldAuthError } = await admin.auth.admin.getUserById(targetId)
    if (oldAuthError || !oldAuth.user) return json({ error: 'Auth user not found' }, 404)

    const { error: profileError } = await admin.from('profiles').update({
      full_name: fullName,
      phone,
    }).eq('id', targetId)
    if (profileError) return json({ error: profileError.message }, 400)

    const { error: authUpdateError } = await admin.auth.admin.updateUserById(targetId, {
      email,
      email_confirm: email === oldAuth.user.email,
    })
    if (authUpdateError) {
      await admin.from('profiles').update({
        full_name: target.full_name,
        phone: target.phone,
      }).eq('id', targetId)
      return json({ error: authUpdateError.message }, 400)
    }
    if (email !== oldAuth.user.email) {
      await admin.from('profiles').update({
        email_verified_at: null,
        email_verification_sent_at: null,
        email_verification_attempts: 0,
        email_verification_window_started_at: null,
        invitation_email_id: null,
      }).eq('id', targetId)
    }
    return json({ id: targetId, email, full_name: fullName, phone, role: target.role })
  }

  if (action === 'reset_password') {
    const { data: authUser } = await admin.auth.admin.getUserById(targetId)
    if (!authUser.user?.email) return json({ error: 'Account email not found' }, 404)
    const resetClient = createClient(url, anonKey, { auth: { persistSession: false } })
    const { error } = await resetClient.auth.resetPasswordForEmail(authUser.user.email)
    if (error) return json({ error: error.message }, 400)
    return json({ sent: true })
  }

  if (action === 'delete') {
    if (targetId === authData.user.id) {
      return json({ error: 'You cannot delete your own signed-in account' }, 400)
    }
    const { error } = await admin.auth.admin.deleteUser(targetId)
    if (error) return json({ error: error.message }, 400)
    return json({ deleted: true })
  }

  return json({ error: 'Unknown action' }, 400)
})
