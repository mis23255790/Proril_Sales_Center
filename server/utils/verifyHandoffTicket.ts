/**
 * 驗證 Manufacturing Center 轉來的身分交接票證（handoff ticket）。
 *
 * Manufacturing Center 是全 Proril2 家族唯一直接對「統一入口網」做 OAuth 的入口，
 * 使用者在那邊登入完成後，導頁到 Sales Center 時帶上這張票證證明「這個帳號剛通過驗證」。
 *
 * 格式：base64url(payload JSON) + '.' + base64url(HMAC-SHA256(payload, 共用密鑰))
 * 共用密鑰放 NUXT_MFG_HANDOFF_SECRET，必須跟 Manufacturing Center 那邊簽發票證用的密鑰一致，
 * 只有兩邊的 server 端知道，不會進瀏覽器。
 *
 * 沒有做 jti 防重放，靠極短 TTL（見 handoff.post.ts 呼叫端）縮小重放視窗；
 * 之後如果要更嚴謹，再加一份已使用 jti 的共用儲存（例如 Redis）。
 */
import { createHmac, timingSafeEqual } from 'node:crypto'

interface HandoffPayload {
  account: string
  iss: string
  aud: string
  iat: number
  exp: number
}

const HANDOFF_AUDIENCE = 'sales-center'
const HANDOFF_ISSUER = 'manufacturing-center'

const base64urlToBuffer = (input: string) => Buffer.from(input.replace(/-/g, '+').replace(/_/g, '/'), 'base64')

export const verifyHandoffTicket = (ticket: string, secret: string): string => {
  const parts = ticket.split('.')
  if (parts.length !== 2 || !parts[0] || !parts[1]) {
    throw new Error('票證格式錯誤')
  }
  const [payloadB64, signatureB64] = parts as [string, string]

  const expectedSignature = createHmac('sha256', secret).update(payloadB64).digest()
  const actualSignature = base64urlToBuffer(signatureB64)
  if (expectedSignature.length !== actualSignature.length || !timingSafeEqual(expectedSignature, actualSignature)) {
    throw new Error('票證簽章驗證失敗')
  }

  const payload = JSON.parse(base64urlToBuffer(payloadB64).toString('utf-8')) as HandoffPayload

  if (payload.aud !== HANDOFF_AUDIENCE) {
    throw new Error('票證的 aud 不是 sales-center，可能拿錯票證')
  }
  if (payload.iss !== HANDOFF_ISSUER) {
    throw new Error('票證的 iss 不是 manufacturing-center')
  }
  if (!payload.exp || Math.floor(Date.now() / 1000) > payload.exp) {
    throw new Error('票證已過期，請重新從製造中心進入')
  }

  const account = (payload.account || '').trim()
  if (!account) {
    throw new Error('票證內沒有帳號')
  }

  return account
}
