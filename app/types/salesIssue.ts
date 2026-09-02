/**
 * 業務議題 (舊 PRORIL WorkProcess / SOP) 型別。
 *
 * 欄位名稱刻意保留後端 DWorkProcess / DWorkProcessDetail 的原名（camelCase 化），
 * 不做語意改名 —— 這樣對照舊碼與 SQL 時不需要再翻譯一層。
 */

/** M_WorkProcessType.TypeCode：關鍵字的分類。 */
export const PHRASE_TYPE = {
  /** 01 搜尋片語 */
  PHRASE: '01',
  /** 02 流程類別 → 畫面上的「類別」 */
  CATEGORY: '02',
  /** 03 職能主題 → 舊畫面的「客戶別」，現已由 CRM 客戶取代 */
  JOB: '03'
} as const

/** 議題預設版本。舊系統的進版功能已停用，一律 1.0。 */
export const DEFAULT_VER_NO = '1.0'

/** 新建議題時 wpno 的哨兵值，存檔時才向後端要號。 */
export const NEW_ISSUE_WPNO = '-1'

/** D_WorkProcess + 後端 join 出來的顯示欄位 (DWorkProcessesEx)。 */
export interface SalesIssue {
  id: number
  /** 議題編號，6 碼左補零字串，例如 "000123" */
  wpno: string
  /** 議題主題 */
  sopTitle?: string | null
  /** 最新進度（自由文字，非狀態碼） */
  descript?: string | null
  phraseList?: string | null
  verNo?: string | null
  pubDate?: string | null
  /** 公開 */
  pubFlag?: boolean | null
  /** 結案 */
  finFlag?: boolean | null
  progressStatus?: number | null
  aStatus?: string | null
  creator?: string | null
  leader?: string | null
  authorize?: string | null
  modifier?: string | null
  createTime?: string | null
  modiTime?: string | null

  // ---- 以下是後端 join 出來的顯示欄位，DB 沒有 ----
  processCaption?: string | null
  processCaption2?: string | null
  processContent?: string | null
  account?: string | null
  /** 建立者姓名 */
  userName?: string | null
  lastModifierName?: string | null
  lastModiTime?: string | null
  enableType?: number | null
  potentialCustom?: string | null
  customerNo?: string | null
  customerName?: string | null
  /** 分號分隔，與 phraseTypeList / phraseNameList 同索引對齊 */
  phraseCodeList?: string | null
  phraseTypeList?: string | null
  phraseNameList?: string | null
}

/** 前端補上的衍生欄位。 */
export interface SalesIssueRow extends SalesIssue {
  /** createTime 取 YYYY-MM-DD */
  createDate: string
  /** phraseType == '02' 的關鍵字 */
  categories: string[]
  /** 客戶別（phraseType == '03' + CRM 客戶名） */
  customers: string[]
}

/** D_WorkProcessDetail：議題底下的一則進度。 */
export interface SalesIssueDetail {
  id: number
  wpno: string
  /** 4 碼左補零字串 */
  sno: string
  /** 標題，慣例上放日期 */
  processCaption?: string | null
  /** 執行說明（目前畫面隱藏） */
  processCaption2?: string | null
  /** 內文 HTML */
  processContent?: string | null
  worker?: string | null
  aStatus?: string | null
  /** 原始檔名，分號分隔 */
  uploadFile?: string | null
  /** 改名後檔名，與 uploadFile 同索引對齊 */
  renameFile?: string | null
  zipFile?: string | null
  creator?: string | null
  modifier?: string | null
  createTime?: string | null
  modiTime?: string | null
  creatorName?: string | null
  modifierName?: string | null
}

/** M_WorkProcessPhrase：關鍵字 / 類別主檔。 */
export interface WorkPhrase {
  id: number
  phraseType: string
  phraseCode: string
  phraseName: string
  directions?: string | null
  pubFlag?: boolean | null
  principal?: string | null
  potentialCustom?: string | null
  aStatus?: string | null
  creator?: string | null
  createTime?: string | null
}

/** M_WorkProcessType：關鍵字的分類主檔。 */
export interface WorkPhraseType {
  id: number
  typeCode: string
  typeName: string
  descript?: string | null
  aStatus?: string | null
}

/** D_WorkProcessSearch + PhraseName：某張議題掛了哪些關鍵字。 */
export interface IssuePhraseLink {
  wpno: string
  phraseType: string
  phraseCode: string
  phraseName?: string | null
  aStatus?: string | null
}

/** CRM 客戶（含 ERP 對照）。 */
export interface CrmCustomer {
  id?: number
  customerNo: string
  shortName?: string | null
  longName?: string | null
  erpcustomerNo?: string | null
  erpCustomShortName?: string | null
  erpCustomLongName?: string | null
}

/** 一筆附件在畫面上的樣子。 */
export interface IssueAttachment {
  /** 原始檔名 */
  uploadFile: string
  /** 後端改名後的檔名，新加入的檔案還沒有 */
  renameFile?: string
  /** true = 這次新選、尚未 zip 落地 */
  pending?: boolean
}
