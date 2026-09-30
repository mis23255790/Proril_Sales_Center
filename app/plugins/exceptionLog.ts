/**
 * 攔 Vue／Nuxt／瀏覽器未捕捉的錯誤，寫進 exceptionLog（見 app/utils/exceptionLog.ts）。
 * 只做記錄，不吞錯誤——Nuxt 原本的錯誤頁、console 輸出照舊。
 */
export default defineNuxtPlugin((nuxtApp) => {
  nuxtApp.hook('vue:error', (err, _instance, info) => {
    reportException('vue:error', err, String(info ?? ''))
  })

  nuxtApp.hook('app:error', (err) => {
    reportException('app:error', err)
  })

  if (import.meta.client) {
    window.addEventListener('error', (e) => {
      reportException('window.error', e.error ?? e.message, e.filename ? `${e.filename}:${e.lineno}:${e.colno}` : undefined)
    })
    window.addEventListener('unhandledrejection', (e) => {
      reportException('unhandledrejection', e.reason)
    })
  }
})
