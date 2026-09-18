import {
  authenticatedClients, cloudinaryConfig, corsHeaders, json, parseReference, sha1Hex,
} from '../_shared/cloudinary.ts'

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  try {
    const auth = await authenticatedClients(request)
    if (!auth) return json({ error: 'Unauthorized' }, 401)
    const body = await request.json().catch(() => null)
    const ref = parseReference(body?.reference)
    if (!ref) return json({ error: 'Invalid media reference' }, 400)
    // Users can clean up only objects created inside their own private folder.
    if (!ref.publicId.startsWith(`${auth.user.id}/`)) return json({ error: 'Forbidden' }, 403)
    const { cloudName, apiKey, apiSecret } = cloudinaryConfig()
    const timestamp = Math.floor(Date.now() / 1000)
    const signature = await sha1Hex(`public_id=${ref.publicId}&timestamp=${timestamp}&type=authenticated${apiSecret}`)
    const form = new FormData()
    form.set('public_id', ref.publicId)
    form.set('timestamp', String(timestamp))
    form.set('type', 'authenticated')
    form.set('api_key', apiKey)
    form.set('signature', signature)
    const response = await fetch(`https://api.cloudinary.com/v1_1/${cloudName}/image/destroy`, {
      method: 'POST', body: form,
    })
    const result = await response.json()
    if (!response.ok) return json({ error: result?.error?.message ?? 'Cloudinary deletion failed' }, 502)
    return json({ deleted: result.result === 'ok' || result.result === 'not found' })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Deletion failed' }, 500)
  }
})
