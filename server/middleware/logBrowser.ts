/**
 * /log、/log/** 轉發到後端 api/ 的 /log（Program.cs 的 UseFileServer，目錄瀏覽 + 看 log 文字檔）。
 *
 * 對外網址 https://sales-center(-dev).proril.com 經 nginx 進的是 Nuxt 容器，
 * api/ 容器沒有對外，所以要由這裡轉過去。跟 /ShareRoot 一樣不需要登入。
 * 目錄清單的連結是 ./xxx 相對路徑，所以 /log 一定要先導到 /log/：後端雖然也會 301，
 * 但 proxyRequest 會在伺服器端自己跟隨轉址，瀏覽器網址停在 /log，相對連結就會解析成 /xxx。
 * 子目錄（/log/exceptionLog）同理，交給下面的 301 檢查一起處理。
 *
 * 用 middleware 不用 server/routes/log/[...path].ts：catch-all 不吃零段，/log 與 /log/
 * 會掉進 Vue router 被導去登入頁。前綴比對要排除 /login 這類只是開頭相同的頁面路徑。
 */
const isLogPath = (path: string) => path === '/log' || /^\/log[/?]/.test(path)

export default defineEventHandler((event) => {
  if (!isLogPath(event.path)) return

  const config = useRuntimeConfig()

  // apiBase 可能是 https://host/api（1.0 站台）或 http://container:8080（api/），檔案掛在站台根目錄
  const origin = config.public.apiBase.replace(/\/api\/?$/, '').replace(/\/$/, '')

  const target = `${origin}${event.path}`

  return proxyRequest(event, target, {
    // 目錄沒帶結尾斜線時，把後端的 301 交給瀏覽器（不在伺服器端跟隨），見檔頭說明
    fetchOptions: { redirect: 'manual' },
    onResponse: (ev, res) => {
      const location = res.headers.get('location')
      if (!location) return
      // 後端給的可能是內部網址（http://container:8080/log/），只留路徑，讓瀏覽器留在對外網域
      const url = new URL(location, target)
      setResponseHeader(ev, 'location', `${url.pathname}${url.search}`)
    }
  })
})
