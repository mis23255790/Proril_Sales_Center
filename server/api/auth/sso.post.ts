/**
 * PRORIL 通行證 SSO 的 code -> token 交換。
 *
 * 一定要在 server 端做：交換需要帶 client secret，不能讓瀏覽器看到。
 * 換到 id_token 後解出帳號，呼叫後端 MainApi/LoginSso 換成本站的內部 JWT
 * （沿用 1.0 的 JwtSettings，跟密碼登入拿到的 token 完全通用）。
 *
 * 沒有驗 id_token 簽章：token 是直接跟通行證的 token endpoint 用 HTTPS
 * 交換來的（不是從瀏覽器導回的網址上解出來），通道本身已經可信任。
 * 若之後改成瀏覽器端能拿到 id_token 的流程，記得補上簽章驗證。
 *
 * 現況：Manufacturing Center 已定案為唯一入口，正式流程走 handoff.post.ts，
 * 這支只留給本機開發／備用，見 app/pages/login.vue 的說明。
 */
interface TokenResponse {
  id_token?: string
  access_token?: string
  error?: string
  error_description?: string
}

interface LoginModel {
  status: boolean
  username?: string | null
  message?: string | null
  token?: string | null
}

const decodeIdTokenAccount = (idToken: string): string => {
  const payload = idToken.split('.')[1]
  if (!payload) return ''
  const json = Buffer.from(payload.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf-8')
  const claims = JSON.parse(json)
  // 通行證實際用哪個 claim 放帳號，要等 Client ID 核准、拿到真實 id_token 後才能確認
  return claims.sub || claims.account || claims.preferred_username || claims.email || ''
}

export default defineEventHandler(async (event) => {
  const { code } = await readBody<{ code: string }>(event)
  if (!code) {
    throw createError({ statusCode: 400, statusMessage: '缺少授權碼 code' })
  }

  const config = useRuntimeConfig()

  let tokenRes: TokenResponse
  try {
    tokenRes = await $fetch<TokenResponse>(config.oauthTokenUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        redirect_uri: config.public.oauthRedirectUri,
        client_id: config.public.oauthClientId,
        client_secret: config.oauthClientSecret
      }).toString()
    })
  } catch (err: any) {
    console.log('sso.post token exchange failed -->', err)
    throw createError({ statusCode: 502, statusMessage: '向 PRORIL 通行證換 token 失敗' })
  }

  if (!tokenRes.id_token) {
    throw createError({
      statusCode: 502,
      statusMessage: tokenRes.error_description || tokenRes.error || 'PRORIL 通行證未回傳 id_token'
    })
  }

  const account = decodeIdTokenAccount(tokenRes.id_token)
  if (!account) {
    throw createError({ statusCode: 502, statusMessage: 'id_token 內無法辨識帳號' })
  }

  try {
    return await $fetch<LoginModel>(`${config.public.apiBase}/MainApi/LoginSso`, {
      method: 'POST',
      headers: { 'X-Internal-Secret': config.ssoInternalSecret },
      body: { account }
    })
  } catch (err: any) {
    console.log('sso.post LoginSso failed -->', err)
    throw createError({ statusCode: 502, statusMessage: '後端 SSO 登入失敗' })
  }
})
