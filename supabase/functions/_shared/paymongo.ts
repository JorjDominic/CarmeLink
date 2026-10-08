// Pure gateway logic is shared by authenticated requests, webhooks and tests.
export type GatewayEnvironment = 'test' | 'live'
export type GatewayConfig = {
  environment: GatewayEnvironment; publicKey: string; secretKey: string;
  webhookSecret: string; ready: boolean;
}
export class GatewayError extends Error {
  constructor(message: string, public status = 400) { super(message) }
}
export function gatewayConfig(env: (name: string) => string | undefined): GatewayConfig {
  const environment = env('PAYMONGO_ENVIRONMENT') === 'live' ? 'live' : 'test'
  const publicKey = env('PAYMONGO_PUBLIC_KEY') ?? ''
  const secretKey = env('PAYMONGO_SECRET_KEY') ?? ''
  const webhookSecret = env('PAYMONGO_WEBHOOK_SECRET') ?? ''
  const prefix = environment === 'live' ? 'live' : 'test'
  const ready = publicKey.startsWith(`pk_${prefix}_`) && secretKey.startsWith(`sk_${prefix}_`)
    && webhookSecret.length > 0 && (environment === 'test' || env('PAYMONGO_ALLOW_LIVE') === 'true')
  return { environment, publicKey, secretKey, webhookSecret, ready }
}
export type Session = {
  id: string; charge_id: string; tenant_id: string; enabled_by: string;
  environment: GatewayEnvironment; amount_centavos: number; status: string;
  provider_intent_id: string | null; provider_method_id: string | null;
  created_at: string; expires_at?: string | null; [key: string]: unknown;
}
export class PayMongoClient {
  constructor(readonly config: GatewayConfig, readonly fetcher: typeof fetch = fetch) {}
  async request(path: string, method = 'GET', attributes?: unknown, key?: string, publicAuth = false): Promise<any> {
    const response = await this.fetcher(`https://api.paymongo.com/v1/${path}`, {
      method,
      headers: {
        Authorization: `Basic ${btoa(`${publicAuth ? this.config.publicKey : this.config.secretKey}:`)}`,
        'Content-Type': 'application/json', ...(key ? { 'Idempotency-Key': key } : {}),
      },
      body: attributes === undefined ? undefined : JSON.stringify({ data: { attributes } }),
      signal: AbortSignal.timeout(20000),
    })
    if (!response.ok) {
      // Never forward provider responses that might contain private account data.
      throw new GatewayError(response.status === 401 || response.status === 403
        ? 'PayMongo credentials or payment permissions need attention.'
        : 'PayMongo could not complete this request. Please check the payment status before retrying.', 502)
    }
    return await response.json()
  }
  retrieve(intentId: string) {
    if (!/^pi_[A-Za-z0-9]+$/.test(intentId)) throw new GatewayError('Invalid payment identifier')
    return this.request(`payment_intents/${intentId}`)
  }
}
export function validateIntent(payload: any, session: Session) {
  const intent = payload?.data
  const a = intent?.attributes
  if (intent?.id !== session.provider_intent_id || intent?.type !== 'payment_intent'
    || a?.amount !== Number(session.amount_centavos) || a?.currency !== 'PHP'
    || a?.livemode !== (session.environment === 'live')
    || a?.metadata?.gateway_session_id !== session.id
    || a?.metadata?.charge_id !== session.charge_id) {
    throw new GatewayError('Provider payment does not match this bill', 409)
  }
  return a
}
export function confirmedPayment(payload: any, session: Session) {
  const a = validateIntent(payload, session)
  if (a.status !== 'succeeded') return null
  const payments = Array.isArray(a.payments) ? a.payments : []
  const paid = payments.filter((p: any) => p?.attributes?.status === 'paid')
  if (paid.length !== 1) throw new GatewayError('Payment confirmation needs reconciliation', 409)
  const payment = paid[0]
  const p = payment.attributes
  if (!/^pay_[A-Za-z0-9]+$/.test(payment.id) || p.amount !== Number(session.amount_centavos)
    || p.currency !== 'PHP' || p.livemode !== (session.environment === 'live')
    || p.payment_intent_id !== session.provider_intent_id || p.source?.type !== 'qrph'
    || !Number.isSafeInteger(p.paid_at) || p.paid_at <= 0) {
    throw new GatewayError('Payment confirmation needs reconciliation', 409)
  }
  return { id: payment.id as string, paidAt: new Date(p.paid_at * 1000).toISOString() }
}
export function safeTestUrl(value: unknown): string | null {
  if (typeof value !== 'string') return null
  try {
    const url = new URL(value)
    return url.protocol === 'https:' && !url.username && !url.password
      && (url.hostname === 'paymongo.com' || url.hostname.endsWith('.paymongo.com')) ? value : null
  } catch { return null }
}
export function qrDetails(payload: any) {
  const action = payload?.data?.attributes?.next_action
  const image = action?.code?.image_url
  if (typeof image !== 'string' || image.length > 3_000_000
    || !/^data:image\/(png|jpeg);base64,[A-Za-z0-9+/=]+$/.test(image)) {
    throw new GatewayError('The QR image is not available yet. Refresh payment status.', 502)
  }
  return { qr_image: image, test_url: safeTestUrl(action?.code?.test_url ?? action?.test_url) }
}
export async function verifyWebhookSignature(
  raw: string, header: string | null, secret: string, environment: GatewayEnvironment,
  nowSeconds = Math.floor(Date.now() / 1000),
) {
  if (!header || !secret) return false
  const fields = new Map(header.split(',').map(part => {
    const index = part.indexOf('='); return [part.slice(0, index).trim(), part.slice(index + 1).trim()]
  }))
  const timestamp = fields.get('t') ?? ''
  const signature = fields.get(environment === 'live' ? 'li' : 'te') ?? ''
  if (!/^\d+$/.test(timestamp) || Math.abs(nowSeconds - Number(timestamp)) > 300
    || !/^[a-fA-F0-9]{64}$/.test(signature)) return false
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const digest = new Uint8Array(await crypto.subtle.sign('HMAC', key,
    new TextEncoder().encode(`${timestamp}.${raw}`)))
  const expected = Array.from(digest, value => value.toString(16).padStart(2, '0')).join('')
  let difference = 0
  for (let i = 0; i < 64; i++) difference |= expected.charCodeAt(i) ^ signature.toLowerCase().charCodeAt(i)
  return difference === 0
}
