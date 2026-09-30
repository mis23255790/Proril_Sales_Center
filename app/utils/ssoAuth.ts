/**
 * PRORIL 通行證 SSO（OAuth2 Authorization Code / OIDC），見 https://oauth.proril.com/docs
 *
 * **正式登入流程**：未登入 -> /login -> 導去通行證授權 -> /auth/callback -> 導回原本要去的頁面。
 * 使用者在任何一個 Proril2 系統登入過，通行證那邊就有 session，導過去會直接帶 code 回來，
 * 不用再輸入帳密，SSO 體驗靠的是這個，不需要系統之間互傳身分。
 * （Manufacturing Center 的 /auth/handoff 票證只是過渡，見 pages/auth/handoff.vue。）
 *
 * state / nonce / 登入後要回去的路徑存 sessionStorage 而非 localStorage：
 * 分頁關掉就該失效，跨分頁也不該共用同一個值。
 */
const STATE_KEY = 'proril-sso-state'
const NONCE_KEY = 'proril-sso-nonce'
const RETURN_TO_KEY = 'proril-sso-return-to'

const DEFAULT_RETURN_TO = '/sales-center'

const randomString = () => {
  const bytes = new Uint8Array(16)
  crypto.getRandomValues(bytes)
  return Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('')
}

/** 只接受站內相對路徑，擋掉 `//evil.com`、`https://...` 這類開放轉址。 */
export const safeReturnPath = (path: unknown): string => {
  if (typeof path !== 'string') return DEFAULT_RETURN_TO
  if (!path.startsWith('/') || path.startsWith('//') || path.startsWith('/\\')) return DEFAULT_RETURN_TO
  if (path === '/login' || path.startsWith('/login?') || path.startsWith('/auth/')) return DEFAULT_RETURN_TO
  return path
}

export const buildAuthorizeUrl = (returnTo?: unknown) => {
  const config = useRuntimeConfig()
  const state = randomString()
  const nonce = randomString()
  sessionStorage.setItem(STATE_KEY, state)
  sessionStorage.setItem(NONCE_KEY, nonce)
  sessionStorage.setItem(RETURN_TO_KEY, safeReturnPath(returnTo))

  const params = new URLSearchParams({
    response_type: 'code',
    client_id: config.public.oauthClientId,
    redirect_uri: config.public.oauthRedirectUri,
    scope: config.public.oauthScope,
    state,
    nonce
  })

  return `${config.public.oauthAuthorizeUrl}?${params.toString()}`
}

/**
 * 比對 callback 帶回的 state 是否跟發送時一致，避免 CSRF；比對完就清掉，一次性使用。
 * 比對成功回傳發送時的 nonce（要送給 server 端比對 id_token 的 nonce claim）
 * 與登入後要回去的路徑，失敗回 null。
 */
export const consumeSsoState = (returnedState: string): { nonce: string, returnTo: string } | null => {
  const savedState = sessionStorage.getItem(STATE_KEY)
  const savedNonce = sessionStorage.getItem(NONCE_KEY)
  const savedReturnTo = sessionStorage.getItem(RETURN_TO_KEY)
  sessionStorage.removeItem(STATE_KEY)
  sessionStorage.removeItem(NONCE_KEY)
  sessionStorage.removeItem(RETURN_TO_KEY)
  if (!savedState || savedState !== returnedState || !savedNonce) return null
  return { nonce: savedNonce, returnTo: safeReturnPath(savedReturnTo) }
}
