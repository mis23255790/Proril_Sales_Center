/** 可以設定版型的匯出功能（XlsFormatApi/GetXlsFormatTargets 的 body）。 */
export interface XlsFormatTarget {
  permissionKey: string
  label: string
  /** 範本裡要用的分頁名稱 */
  sheetNames: string[]
  note: string | null
}

/** 版型別（GetXlsFormatTargets 的 body2）：0 = 有金額權限、1 = 無金額權限。 */
export interface XlsFormatSubNo {
  value: string
  label: string
}

/** 目前的版型（GetXlsFormatList 的 body，一列 = 功能 + 版型別）。 */
export interface XlsFormatListItem {
  permissionKey: string
  label: string
  functionSubNo: string
  subNoLabel: string
  /** 版型的 key 不在後端 XlsFormatTargets 清單內（只能刪除） */
  isKnownTarget: boolean
  sheets: { wsName: string, count: number }[]
  createTime: string | null
  creator: string | null
}

/** 匯入結果的分頁摘要（ImportXlsFormat 的 body）。 */
export interface XlsFormatSheetSummary {
  wsName: string
  rows: number
  columns: number
  /** 分頁名稱對得上、有寫進版型 */
  recognized: boolean
}
