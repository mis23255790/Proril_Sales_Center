/**
 * 全站登入守門：沒有有效（存在且未過期）token 一律導去 /login，
 * 並帶上 `redirect`（原本要去的頁面），登入完成後導回去（見 utils/ssoAuth.ts）。
 *
 * 看的是 `proril-session` cookie（見 useApi.ts 的 getAuthSession；token 本身在 httpOnly cookie），
 * server 端跟 client 端都擋得到，未登入者不會先拿到受保護頁面的完整 SSR HTML 再等 client 導頁。
 *
 * NUXT_PUBLIC_DEV_TOKEN 有值時視同已登入（見 useApi.ts 的 getAuthSession），
 * 本機開發/測試設好這個環境變數就能整個跳過 SSO 流程直接進主畫面。
 */
const PUBLIC_PATHS = ['/login']

export default defineNuxtRouteMiddleware((to) => {
  if (PUBLIC_PATHS.includes(to.path) || to.path.startsWith('/auth/')) return

  if (!isAuthSessionValid()) {
    return navigateTo({ path: '/login', query: to.fullPath === '/' ? {} : { redirect: to.fullPath } })
  }
})
