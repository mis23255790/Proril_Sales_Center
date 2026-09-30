/**
 * 登入 token 的 cookie（BFF 模式）。
 *
 * 內部 JWT 只放在 httpOnly cookie `proril-token`，瀏覽器的 JS 讀不到，
 * XSS 偷不走 token；打後端一律經 /api/proxy，由這裡的 server 端把 cookie 轉成
 * `Authorization: Bearer` 帶給後端（見 server/api/proxy/[...path].ts）。
 *
 * 另外寫一個**不是** httpOnly 的 `proril-session`（只有 `{ account, exp }`，不含 token），
 * 給前端的登入守門（auth.global.ts）判斷過期、右上角顯示帳號用。
 * 它被竄改也拿不到任何權限——真正的驗證是後端驗 `proril-token` 的簽章。
 */
import type { H3Event } from 'h3'

export const AUTH_TOKEN_COOKIE = 'proril-token'
export const AUTH_SESSION_COOKIE = 'proril-session'

const DEFAULT_MAX_AGE = 60 * 60 * 24

const decodeJwtClaims = (token: string): { sub?: string, exp?: number } => {
  try {
    const payload = token.split('.')[1]
    if (!payload) return {}
    return JSON.parse(Buffer.from(payload.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf-8'))
  } catch (err) {
    console.log('authCookie decodeJwtClaims failed -->', err)
    return {}
  }
}

/**
 * 經 nginx 反向代理時看 X-Forwarded-Proto；本機 http 開發不加 Secure，否則 cookie 寫不進去。
 * 不用 h3 的 getRequestProtocol：它要求 header 值剛好等於 'https'，
 * nginx 的 proxy_set_header 在 snippet 與 location 重複設定時會送成 'https, https'，判斷就會失準。
 */
const isHttps = (event: H3Event) => {
  const forwarded = (getRequestHeader(event, 'x-forwarded-proto') || '').split(',')[0]?.trim().toLowerCase()
  if (forwarded) return forwarded === 'https'
  return getRequestProtocol(event) === 'https'
}

export const setAuthCookies = (event: H3Event, token: string) => {
  const { sub, exp } = decodeJwtClaims(token)
  const maxAge = exp ? Math.max(exp - Math.floor(Date.now() / 1000), 0) : DEFAULT_MAX_AGE
  const base = { path: '/', sameSite: 'lax' as const, secure: isHttps(event), maxAge }

  setCookie(event, AUTH_TOKEN_COOKIE, token, { ...base, httpOnly: true })
  setCookie(event, AUTH_SESSION_COOKIE, JSON.stringify({ account: (sub || '').trim(), exp: exp || 0 }), base)
}

interface LoginResult {
  status: boolean
  username?: string | null
  message?: string | null
  token?: string | null
}

/** 後端 LoginSso 成功就寫 cookie；回給瀏覽器的結果拿掉 token。 */
export const finishLogin = (event: H3Event, result: LoginResult) => {
  const ok = !!(result?.status && result.token)
  if (ok) setAuthCookies(event, result.token as string)
  return { status: ok, username: result?.username ?? null, message: result?.message ?? null }
}

export const clearAuthCookies = (event: H3Event) => {
  deleteCookie(event, AUTH_TOKEN_COOKIE, { path: '/' })
  deleteCookie(event, AUTH_SESSION_COOKIE, { path: '/' })
}

export const getAuthCookieToken = (event: H3Event) => getCookie(event, AUTH_TOKEN_COOKIE) || ''

/**
 * cookie 會被瀏覽器自動帶上，所以要擋跨站請求（CSRF）：
 * - Sec-Fetch-Site = cross-site 一律擋（現代瀏覽器都會送這個 header）；
 * - 會改資料的方法再比 Origin 與本站 host，給不送 Sec-Fetch-Site 的舊瀏覽器。
 * SameSite=Lax 已經擋掉跨站 POST 帶 cookie，這裡是第二道。
 */
export const assertSameSiteRequest = (event: H3Event) => {
  if (getRequestHeader(event, 'sec-fetch-site') === 'cross-site') {
    throw createError({ statusCode: 403, statusMessage: '不接受跨站請求' })
  }

  if (['GET', 'HEAD', 'OPTIONS'].includes(event.method)) return

  const origin = getRequestHeader(event, 'origin')
  if (!origin) return
  const originHost = URL.canParse(origin) ? new URL(origin).host : null
  if (!originHost) {
    throw createError({ statusCode: 403, statusMessage: '不合法的 Origin' })
  }
  if (originHost !== getRequestHost(event, { xForwardedHost: true })) {
    throw createError({ statusCode: 403, statusMessage: '不接受跨站請求' })
  }
}
