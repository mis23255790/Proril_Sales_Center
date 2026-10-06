const pad = (n: number) => String(n).padStart(2, '0')

/** 瀏覽器本地時間的 `yyyyMMdd_HHmm`。 */
const localStamp = (d = new Date()) =>
  `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}_${pad(d.getHours())}${pad(d.getMinutes())}`

/**
 * 下載檔名的時間改成使用者電腦的本地時間。
 *
 * 後端在 Docker 裡跑（容器是 UTC），存檔時檔名帶的是 UTC 的 `_yyyyMMdd_HHmm`，
 * 會比台灣慢 8 小時。後端寫入一律維持 UTC，只在下載時把檔名尾端那段換掉；
 * 檔名沒有這段時間格式就原樣不動。
 */
export const toLocalExportName = (fileName: string) =>
  fileName.replace(/_\d{8}_\d{4}(?=\.[^.]+$)/, `_${localStamp()}`)

/**
 * 開新分頁下載匯出檔。`relPath` 是後端回傳、相對於 ShareRoot 的路徑（`Temp/{account}/Export/xxx.xlsx`），
 * 一律經 server/api/download.get.ts 同源下載。
 */
export const openExportDownload = (relPath: string, fallbackName = 'export.xlsx') => {
  const path = `/ShareRoot/${relPath}`
  const name = toLocalExportName(relPath.split('/').pop() || fallbackName)
  window.open(`/api/download?path=${encodeURIComponent(path)}&name=${encodeURIComponent(name)}`, '_blank')
}
