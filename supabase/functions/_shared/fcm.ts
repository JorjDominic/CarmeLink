const encoder = new TextEncoder()

function base64Url(value: Uint8Array | string) {
  const bytes = typeof value === 'string' ? encoder.encode(value) : value
  let binary = ''
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '')
}

export async function fcmAccessToken() {
  const projectId = Deno.env.get('FCM_PROJECT_ID')
  const clientEmail = Deno.env.get('FCM_CLIENT_EMAIL')
  const privateKey = Deno.env.get('FCM_PRIVATE_KEY')?.replaceAll('\\n', '\n')
  if (!projectId || !clientEmail || !privateKey) throw new Error('FCM server credentials are not configured')

  const now = Math.floor(Date.now() / 1000)
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const claims = base64Url(JSON.stringify({
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }))
  const unsigned = `${header}.${claims}`
  const der = Uint8Array.from(
    atob(privateKey.replace(/-----[^-]+-----/g, '').replace(/\s/g, '')),
    (character) => character.charCodeAt(0),
  )
  const key = await crypto.subtle.importKey(
    'pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  )
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, encoder.encode(unsigned))
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion,
    }),
  })
  const result = await response.json()
  if (!response.ok || !result.access_token) throw new Error('Unable to authorize FCM delivery')
  return { projectId, token: result.access_token as string }
}

export async function sendFcm(
  authorization: { projectId: string; token: string },
  registrationToken: string,
  title: string,
  body: string,
  data: Record<string, string>,
) {
  return fetch(`https://fcm.googleapis.com/v1/projects/${authorization.projectId}/messages:send`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${authorization.token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ message: {
      token: registrationToken,
      notification: { title, body },
      data,
      android: { priority: 'high', notification: { channel_id: 'carmelink_updates' } },
      apns: { payload: { aps: { sound: 'default', content_available: true } } },
    } }),
  })
}
