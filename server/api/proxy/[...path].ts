/**
 * 轉發 /api/proxy/** 到 NUXT_PUBLIC_API_BASE。
 *
 * token 在 httpOnly cookie（見 server/utils/authCookie.ts），前端不帶 Authorization，
 * 由這裡把 cookie 轉成 `Authorization: Bearer` 給後端。
 * NUXT_PUBLIC_DEV_TOKEN 有值時（本機開發）沒有 cookie 就用它。
 */
export default defineEventHandler(async (event) => {
  assertSameSiteRequest(event)

  const config = useRuntimeConfig()
  const pathParam = getRouterParam(event, 'path') || ''
  const base = config.public.apiBase.replace(/\/$/, '')
  const query = getQuery(event)
  const qs = new URLSearchParams(query as Record<string, string>).toString()
  const target = `${base}/${pathParam}${qs ? `?${qs}` : ''}`

  const token = getAuthCookieToken(event) || config.public.devToken
  const headers: Record<string, string> = {}
  if (token) headers.Authorization = `Bearer ${token}`

  return proxyRequest(event, target, { headers })
})
