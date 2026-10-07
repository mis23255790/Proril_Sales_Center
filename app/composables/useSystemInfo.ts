import type { ApiResponse } from '~/types/api'
import type { MSystem } from '~/types/system'

/**
 * 系統別資料（M_System）。
 *
 * 目前只用來取 topbar 的環境圖示：ImagePath 在正式區/測試區各自的 DB
 * 存了不同圖檔路徑，資料本身就是環境差異，前端不用另外判斷。
 * 沿用 1.0 MainApiController_SystemSetting.GetMSystemWNo。
 *
 * 1.0 讀的是業務議題（WorkProcess = 7），但 2.0 已把 7 設成 aStatus = 'N'（GetMSystemWNo 只回 'Y'），
 * 2026-10-07 起改讀系統設定（0）那筆的 ImagePath。
 */
export const ENV_ICON_SYSTEM_NO = 0

export const useSystemInfo = () => {
  const { apiFetch } = useApi()

  const getSystemByNo = (systemNo: number) =>
    apiFetch<ApiResponse<MSystem[]>>('/MainApi/GetMSystemWNo', { params: { systemNo } })

  return { getSystemByNo }
}
