/**
 * 全站登入守門：沒有有效（存在且未過期）token 一律導去 /login。
 *
 * token 存在 cookie（見 useApi.ts 的 getAuthToken），server 端跟 client 端都擋得到，
 * 未登入者不會先拿到受保護頁面的完整 SSR HTML 再等 client 導頁。
 *
 * NUXT_PUBLIC_DEV_TOKEN 有值時視同已登入（見 useApi.ts 的 getAuthToken），
 * 本機開發/測試設好這個環境變數就能整個跳過 SSO 流程直接進主畫面。
 */
const PUBLIC_PATHS = ['/login']

export default defineNuxtRouteMiddleware((to) => {
  if (PUBLIC_PATHS.includes(to.path) || to.path.startsWith('/auth/')) return

  const config = useRuntimeConfig()
  const token = getAuthToken() || config.public.devToken

  if (!token || isTokenExpired(token)) {
    return navigateTo('/login')
  }
})
