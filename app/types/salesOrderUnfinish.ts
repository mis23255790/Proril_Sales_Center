/**
 * 未完成訂單檢索 (舊 PRORIL SalesOrderUnFinish) 型別。
 *
 * 欄位名稱刻意保留後端 SalesOrderViewModel 的原名（Tc0xx/Td0xx 等 ERP 直接對應的
 * 泛用命名，camelCase 化），不做語意改名 —— 對照舊碼／SQL 時不需要再翻譯一層。
 *
 * 跟銷貨檢索 (salesShipping.ts) 是不同資料表/不同 ViewModel（訂單 vs 銷貨單），
 * 刻意不共用型別或常數，避免兩個模組互相牽動。
 */

/** FunctionId.QueryUnFinish，權限檢查用。1.0 enum 註解是「尚未出貨訂單」，畫面標題是「未完成訂單檢索」。 */
export const UNFINISH_FUNCTION_NO = 420

/**
 * M_PermissionLinkType.LinkType，未完成訂單金額欄位的權限碼。
 *
 * 數字跟銷貨檢索的 100 相同，但兩個功能各自獨立判斷（M_Permission 是
 * FunctionNo+LinkType 組合鍵），互不影響。
 */
export const UNFINISH_AMOUNT_LINK_TYPE = 100

/** getProductType()：都不勾 = A（含 9 開頭），都勾 = a，5 = 成品，x = 零件。跟銷貨檢索共通的畫面慣例。 */
export const UNFINISH_PRODUCT_TYPE = {
  ALL_UNCHECKED: 'A',
  ALL_CHECKED: 'a',
  FINISHED: '5',
  PART: 'x'
} as const

/**
 * prc_QueryUnfinOrder(_1) 的 FooterFlag，語意與銷貨檢索的 prc_QuerySalesOrder(_1) 相同：
 * N = 逐筆明細列；Y = 群組小計；S = 群組筆數剛好 1 筆時明細升格成小計；T = 總計列。
 * 細項 tab 顯示非 Y（N+S+T），統計 tab 顯示非 N（S+Y+T）。
 */
export const UNFINISH_FOOTER_FLAG = {
  LINE: 'N',
  SINGLE: 'S',
  GROUP: 'Y',
  TOTAL: 'T'
} as const

export const isUnfinishDetailRow = (flag?: string | null) => flag !== UNFINISH_FOOTER_FLAG.GROUP
export const isUnfinishSummaryRow = (flag?: string | null) => flag !== UNFINISH_FOOTER_FLAG.LINE

/** SalesOrderViewModel：prc_QueryUnfinOrder / prc_QueryUnfinOrder_1 的查詢結果列。 */
export interface UnfinOrder {
  id: number
  copSource?: string | null
  /** 單別名稱 */
  mq002?: string | null
  /** 訂單單別 */
  tc001?: string | null
  /** 訂單單號 */
  tc002?: string | null
  /** 訂單序號 */
  td003: string
  /** 訂單日期 */
  tc003: string
  /** 客戶代號 */
  tc004?: string | null
  /** 客戶名稱 */
  ma002?: string | null
  /** 業務人員代號 */
  tc006?: string | null
  /** 業務人員名稱 */
  mv002?: string | null
  /** 送貨地址 */
  tc010?: string | null
  /** 付款條件 */
  tc014?: string | null
  /** 課稅別 */
  tc016?: string | null
  /** 運輸方式 */
  tc019?: string | null
  /** 品號 */
  td004?: string | null
  /** 品名 */
  td005?: string | null
  /** 規格 */
  td006?: string | null
  /** 訂單數量 */
  td008?: number | null
  /** 單位 */
  td010?: string | null
  /** 原幣單價 */
  td011?: number | null
  /** 原幣金額 */
  td012?: number | null
  /** 幣別 */
  tc008?: string | null
  /** 匯率 */
  tc009?: number | null
  /** 台幣金額 */
  ntd?: number | null
  /** 預交日 */
  td013?: string | null
  /** 贈品量 */
  td024?: number | null
  /** 計畫批號 */
  planNumber?: string | null
  /** 銘版序號，JSON 字串 */
  serialNosJson?: string | null
  /** N / S / Y / T，見 UNFINISH_FOOTER_FLAG。 */
  footerFlag?: string | null
}

/** 前端補上的顯示序號：同群組相鄰列共用同一個 index，斑馬紋交錯用。 */
export interface UnfinOrderRow extends UnfinOrder {
  showIndex: number
}
