import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

export const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders, 'Content-Type': 'application/json' },
})

export type CloudinaryRef = { publicId: string; format: string }

export function cloudinaryConfig() {
  const cloudName = Deno.env.get('CLOUDINARY_CLOUD_NAME')
  const apiKey = Deno.env.get('CLOUDINARY_API_KEY')
  const apiSecret = Deno.env.get('CLOUDINARY_API_SECRET')
  if (!cloudName || !apiKey || !apiSecret) throw new Error('Cloudinary is not configured')
  return { cloudName, apiKey, apiSecret }
}

export async function authenticatedClients(request: Request) {
  const authorization = request.headers.get('Authorization')
  if (!authorization?.startsWith('Bearer ')) return null
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
  const { data, error } = await caller.auth.getUser()
  return error || !data.user ? null : { caller, admin, user: data.user }
}

export function parseReference(value: unknown): CloudinaryRef | null {
  if (typeof value !== 'string' || !value.startsWith('cloudinary://authenticated/')) return null
  const asset = value.substring('cloudinary://authenticated/'.length)
  const dot = asset.lastIndexOf('.')
  if (dot < 1) return null
  const publicId = asset.substring(0, dot)
  const format = asset.substring(dot + 1)
  if (!/^[a-zA-Z0-9_\-/]+$/.test(publicId) || !/^[a-z0-9]+$/.test(format)) return null
  return { publicId, format }
}

export function referenceFor(ref: CloudinaryRef) {
  return `cloudinary://authenticated/${ref.publicId}.${ref.format}`
}

export async function sha1Hex(value: string) {
  const bytes = new TextEncoder().encode(value)
  const digest = await crypto.subtle.digest('SHA-1', bytes)
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('')
}

export async function canReadReference(caller: SupabaseClient, reference: string) {
  const maintenance = await caller
    .from('maintenance_reports').select('id').eq('photo_path', reference).limit(1)
  if (!maintenance.error && (maintenance.data?.length ?? 0) > 0) return true
  const payments = await caller
    .from('payments').select('id').eq('receipt_path', reference).limit(1)
  return !payments.error && (payments.data?.length ?? 0) > 0
}

export async function canAttachRecord(
  caller: SupabaseClient, kind: string, recordId: string, userId: string,
) {
  const table = kind === 'maintenance' ? 'maintenance_reports' : kind === 'payment' ? 'payments' : null
  if (!table) return false
  // Uploads are tenant-originated evidence. Staff/guardian read permission must
  // never imply permission to attach a new asset to somebody else's record.
  const result = await caller.from(table).select('id').eq('id', recordId)
    .eq('tenant_id', userId).limit(1)
  return !result.error && (result.data?.length ?? 0) > 0
}
