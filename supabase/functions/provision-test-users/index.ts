import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const users = [
  { email: 'caretaker@carmelita.test', name: 'Carmelita Caretaker', role: 'caretaker', phone: '+63 917 000 0004' },
] as const

Deno.serve(async (request) => {
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 })
  if (request.headers.get('x-bootstrap-secret') !== Deno.env.get('BOOTSTRAP_SECRET')) {
    return new Response('Unauthorized', { status: 401 })
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  )

  const created: string[] = []
  for (const account of users) {
    const { data, error } = await admin.auth.admin.createUser({
      email: account.email,
      password: 'CarmeLinkTest123!',
      email_confirm: true,
    })
    if (error) return Response.json({ created, error: error.message }, { status: 400 })

    const { error: profileError } = await admin.from('profiles').insert({
      id: data.user.id,
      full_name: account.name,
      role: account.role,
      phone: account.phone,
    })
    if (profileError) {
      await admin.auth.admin.deleteUser(data.user.id)
      return Response.json({ created, error: profileError.message }, { status: 400 })
    }
    created.push(account.email)
  }

  return Response.json({ created })
})
