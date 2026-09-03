/**
 * 全站登入守門：沒有有效（存在且未過期）token 一律導去 /login。
 *
 * 只在 client 端擋——token 存在 localStorage，SSR 階段本來就讀不到，交給這次
 * client 導頁自己判斷即可，不用另外接 cookie-based session。
 *
 * NUXT_PUBLIC_DEV_TOKEN 有值時視同已登入（見 useApi.ts 的 getAuthToken），
 * 本機開發/測試設好這個環境變數就能整個跳過 SSO 流程直接進主畫面。
 */
const PUBLIC_PATHS = ['/login', '/callback']

export default defineNuxtRouteMiddleware((to) => {
  if (import.meta.server) return
  if (PUBLIC_PATHS.includes(to.path) || to.path.startsWith('/auth/')) return

  const config = useRuntimeConfig()
  const token = getAuthToken() || config.public.devToken

  if (!token || isTokenExpired(token)) {
    return navigateTo('/login')
  }
})
