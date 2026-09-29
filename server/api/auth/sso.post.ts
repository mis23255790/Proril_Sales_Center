/**
 * PRORIL 通行證 SSO 的 code -> token 交換。
 *
 * 一定要在 server 端做：交換需要帶 client secret，不能讓瀏覽器看到。
 * 換到 id_token 後解出帳號，呼叫後端 MainApi/LoginSso 換成本站的內部 JWT
 * （沿用 1.0 的 JwtSettings，跟密碼登入拿到的 token 完全通用）。
 *
 * id_token 一律驗簽章、iss、aud、exp、nonce（見 server/utils/verifyIdToken.ts）才採信裡面的帳號。
 *
 * 這是正式登入流程；handoff.post.ts（Manufacturing Center 票證）只是過渡。
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

const pickAccount = (claims: Record<string, any>): string => {
  // 通行證實際用哪個 claim 放帳號，要等 Client ID 核准、拿到真實 id_token 後才能確認
  // （discovery 的 claims_supported 只列了 sub / name）
  const value = claims.sub || claims.account || claims.preferred_username || claims.email || ''
  return String(value).trim()
}

export default defineEventHandler(async (event) => {
  const { code, nonce } = await readBody<{ code: string, nonce: string }>(event)
  if (!code) {
    throw createError({ statusCode: 400, statusMessage: '缺少授權碼 code' })
  }
  if (!nonce) {
    throw createError({ statusCode: 400, statusMessage: '缺少 nonce，請重新登入' })
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

  let claims: Record<string, any>
  try {
    claims = await verifyIdToken(tokenRes.id_token, {
      issuer: config.oauthIssuer,
      jwksUrl: config.oauthJwksUrl,
      clientId: config.public.oauthClientId,
      nonce
    })
  } catch (err: any) {
    console.log('sso.post id_token verify failed -->', err)
    throw createError({ statusCode: 401, statusMessage: `id_token 驗證失敗：${err?.message || err}` })
  }

  const account = pickAccount(claims)
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
