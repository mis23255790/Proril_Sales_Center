/** 稽核紀錄（SYS_AuditLog，api/Controllers/SystemSetting/AuditLogApiController.cs）。 */
export interface AuditLogRow {
  id: number
  /** 台灣時間 yyyy-MM-dd HH:mm:ss（後端已從 UTC 轉好）。 */
  logTime: string
  account?: string | null
  userName?: string | null
  /** LOGIN / LOGIN_FAIL / CREATE / UPDATE / DELETE / RESET_PASSWORD / UNLOCK */
  action: string
  /** 頁面權限 key，登入是 auth。 */
  target: string
  targetLabel: string
  targetId?: string | null
  /** JSON 字串：改前／改後、增減清單、登入失敗原因。 */
  detail?: string | null
  clientIp?: string | null
}

export interface AuditLogSummary {
  totalCount: number
}

export interface AuditLogTarget {
  value: string
  label: string
}

export interface AuditLogQuery {
  /** 台灣日期 yyyyMMdd */
  startDate?: string
  endDate?: string
  account?: string
  action?: string
  target?: string
  keyword?: string
  pageIndex?: number
  /** <= 0 代表不分頁 */
  pageSize?: number
}
