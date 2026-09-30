/**
 * 接前端（app/plugins/exceptionLog.ts、useApi）回報的例外，寫進 exceptionLog。
 * 不要求登入（登入頁出錯也要記得到），但擋跨站，欄位一律截斷避免被灌爆。
 */
const MAX_FIELD = 8000

const clip = (v: unknown) => {
  const s = typeof v === 'string' ? v : v == null ? '' : String(v)
  return s.length > MAX_FIELD ? `${s.slice(0, MAX_FIELD)}...(截斷)` : s
}

export default defineEventHandler(async (event) => {
  assertSameSiteRequest(event)

  const body = await readBody<Record<string, unknown>>(event).catch(() => null) || {}
  const lines = [
    `[client] ${clip(body.source)} ${describeRequest(event)}`,
    `page=${clip(body.url)}`,
    `ua=${clip(getRequestHeader(event, 'user-agent'))}`,
    body.info ? `info=${clip(body.info)}` : '',
    clip(body.message),
    clip(body.stack)
  ].filter(Boolean)

  await writeExceptionLog(lines.join('\n'))
  return { ok: true }
})
