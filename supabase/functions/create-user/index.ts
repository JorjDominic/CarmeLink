import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders, 'Content-Type': 'application/json' },
})

const escapeHtml = (value: string) => value
  .replaceAll('&', '&amp;')
  .replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;')
  .replaceAll('"', '&quot;')
  .replaceAll("'", '&#039;')

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  const authorization = request.headers.get('Authorization')
  if (!authorization?.startsWith('Bearer ')) return json({ error: 'Unauthorized' }, 401)

  const url = Deno.env.get('SUPABASE_URL')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const resendKey = Deno.env.get('RESEND_API_KEY')
  const resendFrom = Deno.env.get('RESEND_FROM_EMAIL')
  const inviteRedirect = Deno.env.get('APP_INVITE_REDIRECT_URL')
  if (!resendKey || !resendFrom) {
    return json({ error: 'Email invitations are not configured' }, 503)
  }
  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  })
  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const { data: authData, error: authError } = await caller.auth.getUser()
  if (authError || !authData.user) return json({ error: 'Unauthorized' }, 401)

  const { data: actor, error: actorError } = await admin
    .from('profiles')
    .select('role')
    .eq('id', authData.user.id)
    .single()
  if (actorError || !actor) return json({ error: 'Profile not found' }, 403)

  const body = await request.json().catch(() => null)
  const email = body?.email?.trim()?.toLowerCase()
  const fullName = body?.full_name?.trim()
  const phone = body?.phone?.trim() ?? ''
  const role = body?.role
  const password = body?.password
  const validRoles = ['tenant', 'guardian', 'caretaker', 'owner']

  if (!email || !email.includes('@') || !fullName || !validRoles.includes(role)) {
    return json({ error: 'Invalid account details' }, 400)
  }
  if (typeof password !== 'string' || password.length < 12) {
    return json({ error: 'Password must be at least 12 characters' }, 400)
  }

  const allowed = actor.role === 'owner' ||
    (actor.role === 'caretaker' && ['tenant', 'guardian'].includes(role))
  if (!allowed) return json({ error: 'You cannot create this account role' }, 403)

  const { data: created, error: createError } = await admin.auth.admin.generateLink({
    type: 'signup',
    email,
    password,
    options: {
      data: { must_change_password: true, full_name: fullName },
      ...(inviteRedirect ? { redirectTo: inviteRedirect } : {}),
    },
  })
  if (createError || !created.user || !created.properties?.action_link) {
    return json({ error: createError?.message ?? 'Unable to create account' }, 400)
  }

  const { error: profileError } = await admin.from('profiles').insert({
    id: created.user.id,
    full_name: fullName,
    phone,
    role,
  })
  if (profileError) {
    await admin.auth.admin.deleteUser(created.user.id)
    return json({ error: profileError.message }, 400)
  }

  const detailResult = role === 'tenant'
    ? await admin.from('tenant_details').insert({ profile_id: created.user.id })
    : ['owner', 'caretaker'].includes(role)
      ? await admin.from('staff_details').insert({
          profile_id: created.user.id,
          position: role === 'owner' ? 'Owner' : 'Caretaker',
        })
      : { error: null }

  if (detailResult.error) {
    await admin.auth.admin.deleteUser(created.user.id)
    return json({ error: detailResult.error.message }, 400)
  }

  const emailResponse = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${resendKey}`,
      'Content-Type': 'application/json',
      'Idempotency-Key': `account-invite/${created.user.id}`,
    },
    body: JSON.stringify({
      from: resendFrom,
      to: [email],
      subject: 'Verify your CarmeLink account',
      html: `
        <div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;color:#202124">
          <h1 style="font-size:24px">Welcome to CarmeLink</h1>
          <p>Hello ${escapeHtml(fullName)},</p>
          <p>Your ${escapeHtml(role)} account has been created. Verify that this email address belongs to you before protected access is enabled.</p>
          <p style="margin:28px 0">
            <a href="${escapeHtml(created.properties.action_link)}" style="background:#6d3b25;color:white;padding:12px 20px;border-radius:8px;text-decoration:none">Verify email address</a>
          </p>
          <p>This link is time-limited. If you did not expect this account, do not open the link and contact the dormitory office.</p>
        </div>`,
      text: `Hello ${fullName},\n\nVerify your CarmeLink email address: ${created.properties.action_link}\n\nIf you did not expect this account, contact the dormitory office.`,
      tags: [{ name: 'category', value: 'account-invitation' }],
    }),
  })
  const emailResult = await emailResponse.json().catch(() => ({}))
  if (!emailResponse.ok || typeof emailResult.id !== 'string') {
    await admin.auth.admin.deleteUser(created.user.id)
    return json({ error: emailResult.message ?? 'Unable to send verification email' }, 502)
  }

  const { error: trackingError } = await admin.from('profiles').update({
    email_verification_sent_at: new Date().toISOString(),
    email_verification_window_started_at: new Date().toISOString(),
    email_verification_attempts: 1,
    invitation_email_id: emailResult.id,
  }).eq('id', created.user.id)
  if (trackingError) {
    await admin.auth.admin.deleteUser(created.user.id)
    return json({ error: trackingError.message }, 400)
  }

  return json({
    id: created.user.id,
    email,
    role,
    email_verification: 'pending',
    sms_verification: 'on_hold',
  }, 201)
})
