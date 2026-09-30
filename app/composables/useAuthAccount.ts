/**
 * 目前登入帳號。
 *
 * 後端 JwtHelper 把帳號放在 `sub` claim，token 在 httpOnly cookie 讀不到，
 * 由 server 端登入時把 `sub` 抄進 `proril-session` cookie（見 server/utils/authCookie.ts）。
 * 舊系統是靠 `$.session.get('account')`，2.0 沒有 jQuery session，
 * 讀 cookie 比再打一支 API 便宜。
 */
export const useAuthAccount = () => {
  const account = computed(() => {
    try {
      return (getAuthSession()?.account || '').trim()
    } catch (err) {
      console.log('useAuthAccount account failed -->', err)
      return ''
    }
  })

  return { account }
}
