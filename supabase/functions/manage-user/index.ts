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
      .select('id, full_name, role, phone, created_at')
      .order('created_at')
    if (error) return json({ error: error.message }, 400)

    const visible = actor.role === 'owner'
      ? profiles
      : profiles.filter((profile) => ['tenant', 'guardian'].includes(profile.role))
    const accounts = await Promise.all(visible.map(async (profile) => {
      const { data } = await admin.auth.admin.getUserById(profile.id)
      return { ...profile, email: data.user?.email ?? '' }
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
      email_confirm: true,
    })
    if (authUpdateError) {
      await admin.from('profiles').update({
        full_name: target.full_name,
        phone: target.phone,
      }).eq('id', targetId)
      return json({ error: authUpdateError.message }, 400)
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
