/**
 * PRORIL 通行證 SSO（OAuth2 Authorization Code），見 https://oauth.proril.com/docs
 *
 * state 存 sessionStorage 而非 localStorage：分頁關掉就該失效，跨分頁也不該共用同一個值。
 *
 * 現況：Manufacturing Center 已定案為唯一入口，正式流程走 /auth/handoff，
 * 這支只留給本機開發／備用，見 app/pages/login.vue 的說明。
 */
const STATE_KEY = 'proril-sso-state'
const NONCE_KEY = 'proril-sso-nonce'

const randomString = () => {
  const bytes = new Uint8Array(16)
  crypto.getRandomValues(bytes)
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('')
}

export const buildAuthorizeUrl = () => {
  const config = useRuntimeConfig()
  const state = randomString()
  const nonce = randomString()
  sessionStorage.setItem(STATE_KEY, state)
  sessionStorage.setItem(NONCE_KEY, nonce)

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

/** 比對 callback 帶回的 state 是否跟發送時一致，避免 CSRF；比對完就清掉，一次性使用。 */
export const consumeSsoState = (returnedState: string): boolean => {
  const savedState = sessionStorage.getItem(STATE_KEY)
  sessionStorage.removeItem(STATE_KEY)
  sessionStorage.removeItem(NONCE_KEY)
  return !!savedState && savedState === returnedState
}
