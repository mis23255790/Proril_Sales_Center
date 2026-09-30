/**
 * 前端例外回報：送到 server/api/log/exception.post.ts，由 Nitro 寫進 exceptionLog 目錄。
 *
 * - 同一個 error 物件只報一次（useApi 報過、再冒泡成 unhandledrejection 就不重複）；
 *   報過的物件會掛 `__exceptionLogged`，server/plugins/exceptionLog.ts 看到就不再寫一次（SSR）。
 * - 同樣訊息 5 秒內只報一次，每次載入頁面最多報 50 筆，避免迴圈錯誤灌爆 log。
 * - 回報本身失敗一律吞掉，不能再丟例外（否則會無限遞迴）。
 */
const MAX_REPORTS_PER_PAGE = 50
const DEDUPE_MS = 5000

let reportCount = 0
const recent = new Map<string, number>()

const toText = (err: unknown) => {
  if (err instanceof Error) return { message: `${err.name}: ${err.message}`, stack: err.stack || '' }
  if (typeof err === 'string') return { message: err, stack: '' }
  try {
    return { message: JSON.stringify(err), stack: '' }
  } catch {
    return { message: String(err), stack: '' }
  }
}

export const reportException = (source: string, err: unknown, info?: string) => {
  try {
    if (err && typeof err === 'object') {
      if ((err as any).__exceptionLogged) return
      Object.defineProperty(err, '__exceptionLogged', { value: true, enumerable: false })
    }

    const { message, stack } = toText(err)
    const key = `${source}|${message}`
    const now = Date.now()
    if (now - (recent.get(key) ?? 0) < DEDUPE_MS) return
    recent.set(key, now)
    if (++reportCount > MAX_REPORTS_PER_PAGE) return

    let url = ''
    try {
      url = import.meta.client ? window.location.href : useRequestURL().href
    } catch {
      // SSR 時不在 nuxtApp context 內取不到，留空
    }
    $fetch('/api/log/exception', {
      method: 'POST',
      body: { source, message, stack, info, url }
    }).catch(() => {})
  } catch {
    // 回報失敗不處理
  }
}
