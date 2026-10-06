import type { ApiResponse } from '~/types/api'
import type { AuditLogQuery, AuditLogRow, AuditLogSummary, AuditLogTarget } from '~/types/auditLog'

/** 稽核紀錄查詢（系統管理 / 系統設定 / 稽核紀錄），見 api/Controllers/SystemSetting/AuditLogApiController.cs。 */
export const useAuditLogApi = () => {
  const { apiFetch } = useApi()

  /** 新到舊、後端分頁；body2.totalCount 是符合條件的總筆數。 */
  const getAuditLogs = (q: AuditLogQuery) =>
    apiFetch<ApiResponse<AuditLogRow[], AuditLogSummary>>('/AuditLogApi/GetAuditLogs', {
      params: {
        startDate: q.startDate ?? '',
        endDate: q.endDate ?? '',
        account: q.account ?? '',
        action: q.action ?? '',
        target: q.target ?? '',
        keyword: q.keyword ?? '',
        pageIndex: q.pageIndex ?? 0,
        pageSize: q.pageSize ?? 50
      }
    })

  /** 「功能」下拉：稽核表裡出現過的功能。 */
  const getTargets = () => apiFetch<ApiResponse<AuditLogTarget[]>>('/AuditLogApi/GetAuditLogTargets')

  return { getAuditLogs, getTargets }
}
