import type { ApiResponse } from '~/types/api'
import type { XlsFormatListItem, XlsFormatSheetSummary, XlsFormatSubNo, XlsFormatTarget } from '~/types/xlsFormat'

/**
 * 格式匯入（系統管理 / 格式匯入）的 API，見 api/Controllers/SystemSetting/XlsFormatApiController.cs。
 *
 * 與 1.0 不同：1.0 是先走 UploadApi 存檔、再用 GET 帶路徑呼叫 CommonApi/ImportXlsFormat；
 * 2.0 直接把檔案 multipart POST 給 ImportXlsFormat，後端只解析不落地。
 */
export const useXlsFormatApi = () => {
  const { apiFetch } = useApi()

  const getTargets = () =>
    apiFetch<ApiResponse<XlsFormatTarget[], XlsFormatSubNo[]>>('/XlsFormatApi/GetXlsFormatTargets')

  const getList = () =>
    apiFetch<ApiResponse<XlsFormatListItem[]>>('/XlsFormatApi/GetXlsFormatList')

  /** 同一個功能 + 版型別的舊版型會整份換掉。message 可能帶「略過的分頁」提示（isSuccess 仍是 true）。 */
  const importFormat = (file: File, permissionKey: string, functionSubNo: string) => {
    const form = new FormData()
    form.append('file', file)
    form.append('permissionKey', permissionKey)
    form.append('functionSubNo', functionSubNo)
    return apiFetch<ApiResponse<XlsFormatSheetSummary[]>>('/XlsFormatApi/ImportXlsFormat', {
      method: 'POST',
      body: form
    })
  }

  const deleteFormat = (permissionKey: string, functionSubNo: string) =>
    apiFetch<ApiResponse>('/XlsFormatApi/DeleteXlsFormat', {
      method: 'POST',
      params: { permissionKey, functionSubNo }
    })

  /** 產生目前版型的 .xlsx，body 是相對於 ShareRoot 的路徑（與各匯出相同）。 */
  const exportFormat = (permissionKey: string, functionSubNo: string) =>
    apiFetch<ApiResponse<string>>('/XlsFormatApi/ExportXlsFormat', { params: { permissionKey, functionSubNo } })

  return { getTargets, getList, importFormat, deleteFormat, exportFormat }
}
