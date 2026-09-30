/**
 * Nitro 端未處理例外（server/api/**、SSR）寫進 exceptionLog，並每天清一次舊檔。
 * 4xx（createError 主動丟的 401/403/400）是正常的拒絕，不算例外，不寫。
 */
export default defineNitroPlugin((nitroApp) => {
  nitroApp.hooks.hook('error', (error, { event }) => {
    const statusCode = (error as any)?.statusCode ?? 500
    if (statusCode < 500) return
    const cause = (error as any)?.cause ?? error
    // SSR 的 Vue 錯誤已由 app/plugins/exceptionLog.ts 回報過
    if ((error as any)?.__exceptionLogged || cause?.__exceptionLogged) return
    writeExceptionLog(`[server] ${statusCode} ${describeRequest(event)}\n${formatError(cause)}`)
  })

  cleanupExceptionLogs()
  setInterval(cleanupExceptionLogs, 24 * 60 * 60 * 1000).unref()
})
