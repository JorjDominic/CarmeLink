import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { handleWebhook } from './handler.ts'

Deno.serve(request => handleWebhook(request, {
  env: name => Deno.env.get(name),
  createAdmin: () => createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } }),
}))
