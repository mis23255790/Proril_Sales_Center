/**
 * 從 JWT 取出登入帳號。
 *
 * 後端 JwtHelper 把帳號放在 `sub` claim（JwtRegisteredClaimNames.Sub）。
 * 舊系統是靠 `$.session.get('account')`，2.0 沒有 jQuery session，
 * 直接解 token 比再打一支 API 便宜。
 */
export const useAuthAccount = () => {
  const decodePayload = (token: string): Record<string, any> | null => {
    try {
      const payload = token.split('.')[1]
      if (!payload) return null
      const json = atob(payload.replace(/-/g, '+').replace(/_/g, '/'))
      return JSON.parse(decodeURIComponent(escape(json)))
    } catch (err) {
      console.log('useAuthAccount decodePayload failed -->', err)
      return null
    }
  }

  const account = computed(() => {
    try {
      const config = useRuntimeConfig()
      const token = getAuthToken() || config.public.devToken
      if (!token) return ''
      const payload = decodePayload(token)
      return (payload?.sub as string) || ''
    } catch (err) {
      console.log('useAuthAccount account failed -->', err)
      return ''
    }
  })

  return { account }
}
