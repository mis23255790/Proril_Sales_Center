/**
 * 解析 JWT payload、判斷是否過期。
 * 只做本地判斷，不驗簽章——簽章由後端每次請求驗，這裡只是省一次
 * 「明知過期還送出請求，等後端回 401 才發現」的往返。
 */
export const decodeJwtPayload = (token: string): Record<string, any> | null => {
  try {
    const payload = token.split('.')[1]
    if (!payload) return null
    const json = atob(payload.replace(/-/g, '+').replace(/_/g, '/'))
    return JSON.parse(decodeURIComponent(escape(json)))
  } catch (err) {
    console.log('decodeJwtPayload failed -->', err)
    return null
  }
}

export const isTokenExpired = (token: string): boolean => {
  const payload = decodeJwtPayload(token)
  if (!payload?.exp) return true
  return Date.now() >= payload.exp * 1000
}
