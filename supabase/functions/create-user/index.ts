import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders, 'Content-Type': 'application/json' },
})

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
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

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { must_change_password: true },
  })
  if (createError || !created.user) {
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

  return json({ id: created.user.id, email, role }, 201)
})
