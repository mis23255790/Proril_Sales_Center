/**
 * Nuxt 端（app/ + server/）的例外 log，文字檔一天一個。
 *
 * 路徑規則比照後端 api/Helpers/LogHelper.cs：Linux(Docker) 是 /app/Logs，
 * 其他是 C:\Logs\proril_log，底下的 exceptionLog/ 目錄；可用 NUXT_LOG_ROOT 覆寫根目錄。
 * 檔名加 `web_` 前綴（web_yyyyMMdd.txt）：本機開發時 api/ 與 Nuxt 寫同一個目錄，
 * .NET 的 File.AppendText 寫檔時會鎖檔，同名檔會互搶；而且 api/ 的
 * LogTimedHostedService 只清 yyyyMMdd.txt，web_ 開頭的由這裡的 cleanupExceptionLogs 清。
 *
 * 寫失敗一律吞掉（只 console），不能因為寫 log 讓原本的請求掛掉。
 */
import { appendFile, mkdir, readdir, unlink } from 'node:fs/promises'
import { join } from 'node:path'
import type { H3Event } from 'h3'

const LOG_ROOT = process.env.NUXT_LOG_ROOT
  || (process.platform === 'linux' ? '/app/Logs' : 'C:\\Logs\\proril_log')

export const EXCEPTION_LOG_DIR = join(LOG_ROOT, 'exceptionLog')

const FILE_PREFIX = 'web_'
const KEEP_DAYS = 30

const pad = (n: number, len = 2) => String(n).padStart(len, '0')

/**
 * 容器是 UTC，log 一律用台灣時間（UTC+8，沒有日光節約）：把時間平移 8 小時後用 getUTC* 取值，
 * 本機與容器結果一致。比照後端 api/Helpers/TaiwanTime.cs。
 */
const TAIWAN_OFFSET_MS = 8 * 60 * 60 * 1000
const toTaiwan = (d: Date) => new Date(d.getTime() + TAIWAN_OFFSET_MS)

const formatDate = (d: Date) => {
  const t = toTaiwan(d)
  return `${t.getUTCFullYear()}${pad(t.getUTCMonth() + 1)}${pad(t.getUTCDate())}`
}

const formatTime = (d: Date) => {
  const t = toTaiwan(d)
  return `${pad(t.getUTCHours())}:${pad(t.getUTCMinutes())}:${pad(t.getUTCSeconds())}.${pad(t.getUTCMilliseconds(), 3)}`
}

// 依序寫入，避免同時多筆 append 交錯
let queue: Promise<void> = Promise.resolve()

export const writeExceptionLog = (message: string): Promise<void> => {
  const now = new Date()
  const text = `--執行時間 ${formatTime(now)}--\n${message}\n\n`
  const file = join(EXCEPTION_LOG_DIR, `${FILE_PREFIX}${formatDate(now)}.txt`)

  queue = queue.then(async () => {
    try {
      await mkdir(EXCEPTION_LOG_DIR, { recursive: true })
      await appendFile(file, text, 'utf-8')
    } catch (err) {
      console.log('writeExceptionLog failed -->', err)
    }
  })
  return queue
}

/** 請求的共通資訊：方法、路徑、登入帳號（取自 proril-session，沒有就留空）。 */
export const describeRequest = (event?: H3Event) => {
  if (!event) return ''
  let account = ''
  try {
    const session = getCookie(event, AUTH_SESSION_COOKIE)
    account = session ? (JSON.parse(session)?.account || '') : ''
  } catch {
    // session cookie 壞掉就當匿名
  }
  return `${event.method} ${event.path} account=${account || '-'}`
}

export const formatError = (err: unknown) => {
  if (err instanceof Error) return err.stack || `${err.name}: ${err.message}`
  if (typeof err === 'string') return err
  try {
    return JSON.stringify(err)
  } catch {
    return String(err)
  }
}

/** 刪掉超過 KEEP_DAYS 的 web_yyyyMMdd.txt。 */
export const cleanupExceptionLogs = async () => {
  try {
    const files = await readdir(EXCEPTION_LOG_DIR).catch(() => [] as string[])
    // 檔名是台灣日期，today 也用台灣日期；兩邊都用 Date.UTC 表示純日期，只比天數
    const tw = toTaiwan(new Date())
    const today = new Date(Date.UTC(tw.getUTCFullYear(), tw.getUTCMonth(), tw.getUTCDate()))

    for (const name of files) {
      const m = /^web_(\d{4})(\d{2})(\d{2})\.txt$/.exec(name)
      if (!m) continue
      const fileDate = new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])))
      const days = (today.getTime() - fileDate.getTime()) / 86_400_000
      if (days <= KEEP_DAYS) continue
      await unlink(join(EXCEPTION_LOG_DIR, name)).catch(err => console.log('cleanupExceptionLogs unlink failed -->', err))
    }
  } catch (err) {
    console.log('cleanupExceptionLogs failed -->', err)
  }
}
