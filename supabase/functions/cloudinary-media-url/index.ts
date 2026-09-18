import {
  authenticatedClients, canReadReference, cloudinaryConfig, corsHeaders, json,
  parseReference, sha1Hex,
} from '../_shared/cloudinary.ts'

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  try {
    const auth = await authenticatedClients(request)
    if (!auth) return json({ error: 'Unauthorized' }, 401)
    const body = await request.json().catch(() => null)
    const reference = body?.reference
    const ref = parseReference(reference)
    if (!ref) return json({ error: 'Invalid media reference' }, 400)
    // Queries use the caller JWT, so existing database RLS decides access.
    if (!(await canReadReference(auth.caller, reference))) return json({ error: 'Forbidden' }, 403)

    const { cloudName, apiKey, apiSecret } = cloudinaryConfig()
    const expiresAt = Math.floor(Date.now() / 1000) + 300
    const params = `expires_at=${expiresAt}&format=${ref.format}&public_id=${ref.publicId}&type=authenticated`
    const signature = await sha1Hex(`${params}${apiSecret}`)
    const query = new URLSearchParams({
      public_id: ref.publicId, format: ref.format, type: 'authenticated',
      expires_at: String(expiresAt), api_key: apiKey, signature,
    })
    return json({
      url: `https://api.cloudinary.com/v1_1/${cloudName}/image/download?${query}`,
      expires_at: expiresAt,
    })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unable to authorize media' }, 500)
  }
})
