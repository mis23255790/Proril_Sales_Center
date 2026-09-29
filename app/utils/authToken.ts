/**
 * 解析 JWT payload（只剩 NUXT_PUBLIC_DEV_TOKEN 在用，見 useApi.ts 的 getAuthSession）。
 * 只做本地判斷，不驗簽章——簽章由後端每次請求驗。
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
