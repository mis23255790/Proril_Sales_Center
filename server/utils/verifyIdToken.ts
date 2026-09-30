/**
 * 驗證 PRORIL 通行證發的 id_token（OIDC Core 3.1.3.7）。
 *
 * 驗的項目：RS256 簽章（公鑰取自 JWKS）、iss、aud（= 本站 client_id）、exp / iat、nonce。
 * nonce 是發起授權時產生、存在瀏覽器 sessionStorage 的那一個，由 callback 頁跟 code 一起送上來，
 * 用來確認這張 id_token 是「這個瀏覽器這一次」發起的登入換來的，不是別處截來重放的。
 *
 * JWKS 由 jose 快取在記憶體，遇到沒看過的 kid 會自動重抓，通行證輪替金鑰不用重啟。
 */
import { createRemoteJWKSet, jwtVerify, type JWTPayload } from 'jose'

let jwks: ReturnType<typeof createRemoteJWKSet> | null = null
let jwksUrlInUse = ''

const getJwks = (jwksUrl: string) => {
  if (!jwks || jwksUrlInUse !== jwksUrl) {
    jwks = createRemoteJWKSet(new URL(jwksUrl))
    jwksUrlInUse = jwksUrl
  }
  return jwks
}

interface VerifyIdTokenOptions {
  issuer: string
  jwksUrl: string
  clientId: string
  nonce: string
}

export const verifyIdToken = async (idToken: string, options: VerifyIdTokenOptions): Promise<JWTPayload> => {
  if (!options.nonce) {
    throw new Error('缺少 nonce，請重新登入')
  }

  const { payload } = await jwtVerify(idToken, getJwks(options.jwksUrl), {
    issuer: options.issuer,
    audience: options.clientId,
    algorithms: ['RS256'],
    requiredClaims: ['sub', 'exp', 'iat', 'nonce'],
    // 容許兩台機器之間的時鐘誤差
    clockTolerance: 60
  })

  if (payload.nonce !== options.nonce) {
    throw new Error('id_token 的 nonce 不符，可能是被重放的登入結果，請重新登入')
  }

  return payload
}
