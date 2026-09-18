import {
  authenticatedClients, canAttachRecord, cloudinaryConfig, corsHeaders, json,
  referenceFor, sha1Hex,
} from '../_shared/cloudinary.ts'

const allowedMime = new Set(['image/jpeg', 'image/png', 'image/webp'])
const maximumBytes = 5 * 1024 * 1024

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  try {
    const auth = await authenticatedClients(request)
    if (!auth) return json({ error: 'Unauthorized' }, 401)
    const body = await request.json().catch(() => null)
    const kind = body?.kind
    const recordId = body?.record_id
    const mimeType = body?.mime_type
    const encoded = body?.file_base64
    if (!['maintenance', 'payment'].includes(kind) || typeof recordId !== 'string' ||
        !allowedMime.has(mimeType) || typeof encoded !== 'string') {
      return json({ error: 'Invalid upload request' }, 400)
    }
    if (!(await canAttachRecord(auth.caller, kind, recordId, auth.user.id))) {
      return json({ error: 'Forbidden' }, 403)
    }
    const estimatedBytes = Math.floor(encoded.length * 3 / 4)
    if (estimatedBytes < 1 || estimatedBytes > maximumBytes) return json({ error: 'Image must be 5 MB or smaller' }, 413)

    const { cloudName, apiKey, apiSecret } = cloudinaryConfig()
    const timestamp = Math.floor(Date.now() / 1000)
    const publicId = `${auth.user.id}/${kind}/${recordId}/${crypto.randomUUID()}`
    // The incoming limit/quality transformation reduces oversized mobile images.
    // Eager thumbnails avoid exposing unrestricted on-the-fly transformations.
    const transformation = 'c_limit,w_2400,h_2400,q_auto:good'
    const eager = 'c_limit,w_1200,h_1200,q_auto:good|c_fill,w_320,h_320,q_auto:eco'
    const signatureSource = `eager=${eager}&public_id=${publicId}&timestamp=${timestamp}&transformation=${transformation}&type=authenticated${apiSecret}`
    const signature = await sha1Hex(signatureSource)
    const form = new FormData()
    form.set('file', `data:${mimeType};base64,${encoded}`)
    form.set('api_key', apiKey)
    form.set('timestamp', String(timestamp))
    form.set('public_id', publicId)
    form.set('type', 'authenticated')
    form.set('transformation', transformation)
    form.set('eager', eager)
    form.set('signature', signature)
    const upload = await fetch(`https://api.cloudinary.com/v1_1/${cloudName}/image/upload`, {
      method: 'POST', body: form,
    })
    const result = await upload.json()
    if (!upload.ok) return json({ error: result?.error?.message ?? 'Cloudinary upload failed' }, 502)
    const reference = referenceFor({ publicId: result.public_id, format: result.format })
    return json({ reference }, 201)
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Upload failed' }, 500)
  }
})
