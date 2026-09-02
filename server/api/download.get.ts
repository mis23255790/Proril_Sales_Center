/**
 * 附件下載中繼。
 *
 * WorkProcessApi/GetDownloadUrl 回的是「.NET 站台根目錄」下的相對路徑
 * （例如 /ShareRoot/Temp/xxx/Doc_SOP/00000/報價單.pdf），不在 /api 底下，
 * 瀏覽器直接開會跨網域。這支把它拉回同源，並強制以附件形式存檔。
 *
 * 只接受 /ShareRoot/ 開頭的路徑，避免變成任意網址的開放轉址。
 */
export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig()
  const { path, name } = getQuery(event) as { path?: string, name?: string }

  if (!path || !path.startsWith('/ShareRoot/')) {
    throw createError({ statusCode: 400, statusMessage: '不合法的下載路徑' })
  }

  // apiBase 是 https://host/api，檔案掛在站台根目錄，所以要把 /api 拿掉。
  const origin = config.public.apiBase.replace(/\/api\/?$/, '').replace(/\/$/, '')
  const target = `${origin}${path}`

  const file = await $fetch<Blob>(target, { responseType: 'blob' })
  const fileName = name || path.split('/').pop() || 'download'

  setHeader(event, 'Content-Type', 'application/octet-stream')
  setHeader(
    event,
    'Content-Disposition',
    `attachment; filename*=UTF-8''${encodeURIComponent(fileName)}`
  )

  return Buffer.from(await file.arrayBuffer())
})
