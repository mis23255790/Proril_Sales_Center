export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig()
  const pathParam = getRouterParam(event, 'path') || ''
  const base = config.public.apiBase.replace(/\/$/, '')
  const query = getQuery(event)
  const qs = new URLSearchParams(query as Record<string, string>).toString()
  const target = `${base}/${pathParam}${qs ? `?${qs}` : ''}`

  return proxyRequest(event, target)
})
