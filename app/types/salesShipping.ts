/**
 * 銷貨檢索 (舊 PRORIL MixSalesShip) 型別。
 *
 * 欄位名稱刻意保留後端 CopSalesOrder 的原名（Th0xx 等 ERP 直接對應的泛用命名，
 * camelCase 化），不做語意改名 —— 對照舊碼／SQL 時不需要再翻譯一層。
 */

/** FunctionId.MixSalesShipping，權限檢查用。 */
export const SALES_SHIPPING_FUNCTION_NO = 410

/**
 * M_PermissionLinkType.LinkType，銷貨檢索金額欄位的權限碼。
 *
 * 這個值只在 FunctionId=410 底下有意義 —— 系統沒有跨功能通用的 LinkType 常數表，
 * 每個功能的 LinkType 各自定義，不能拿去給其他頁面用。
 */
export const SALES_SHIPPING_AMOUNT_LINK_TYPE = 100

/** getProductType()：都不勾 = A（含 9 開頭），都勾 = a，5 = 成品，x = 零件。 */
export const PRODUCT_TYPE = {
  ALL_UNCHECKED: 'A',
  ALL_CHECKED: 'a',
  FINISHED: '5',
  PART: 'x'
} as const

/**
 * prc_QuerySalesOrder(_1) 的 FooterFlag。
 *
 * N = 逐筆明細列；Y = 群組小計（同 TH001+TH002 / TH004 群組筆數 > 1 時才產生）；
 * S = 群組筆數剛好 1 筆時，把那一筆明細直接升格成小計；T = 全部的總計列。
 *
 * 細項 tab 顯示「非 Y」（N + S + T），統計 tab 顯示「非 N」（S + Y + T） ——
 * 兩者都吃得到 T（總計列），這是舊系統的既有行為，照搬。
 */
export const FOOTER_FLAG = {
  LINE: 'N',
  SINGLE: 'S',
  GROUP: 'Y',
  TOTAL: 'T'
} as const

export const isDetailRow = (flag?: string | null) => flag !== FOOTER_FLAG.GROUP
export const isSummaryRow = (flag?: string | null) => flag !== FOOTER_FLAG.LINE

/** CopSalesOrder：prc_QuerySalesOrder / prc_QuerySalesOrder_1 的查詢結果列。 */
export interface CopSalesOrder {
  id: number
  copSource?: string | null
  tg003?: string | null
  /** 銷貨單別 */
  th001: string
  /** 銷貨單號 */
  th002: string
  /** 銷貨序號 */
  th003: string
  /** 品號 */
  th004?: string | null
  /** 品名 */
  th005?: string | null
  /** 規格 */
  th006?: string | null
  /** 單位 */
  th009?: string | null
  th007?: string | null
  /** 數量（細項列） */
  th008?: number | null
  /** 數量（統計列彙總） */
  sumQty?: number | null
  /** 單價 */
  th012?: number | null
  /** 數量*單價 */
  th013?: number | null
  /** 幣別 */
  tg011?: string | null
  /** 匯率 */
  tg012?: number | null
  /** 台幣未稅 */
  th037?: number | null
  /** 台幣稅額 */
  th038?: number | null
  /** 台幣總額（細項/統計皆有） */
  sumAmt?: number | null
  th024?: number | null
  /** 訂單單別 */
  th014?: string | null
  /** 訂單單號 */
  th015?: string | null
  /** 訂單序號 */
  th016?: string | null
  /** 客戶單號 */
  th018?: string | null
  tc012?: string | null
  /** 銘版序號，JSON 字串 */
  serialNosJson?: string | null
  /** 製令單別 */
  ta001?: string | null
  /** 製令單號 */
  ta002?: string | null
  /** 計劃批號 */
  planNumber?: string | null
  ta026?: string | null
  ta027?: string | null
  ta028?: string | null
  serialNosJson1?: string | null
  ta0011?: string | null
  ta0021?: string | null
  planNumber1?: string | null
  customerNo?: string | null
  customerName?: string | null
  memo?: string | null
  /** N / S / Y / T，見 FOOTER_FLAG。 */
  footerFlag?: string | null
  aStatus?: string | null
  creator?: string | null
  createTime?: string | null
  modifier?: string | null
  modiTime?: string | null
}

/** 前端補上的顯示序號：同群組（品號 / 銷貨單別+單號）相鄰列共用同一個 index，斑馬紋交錯用。 */
export interface CopSalesOrderRow extends CopSalesOrder {
  showIndex: number
}

/** CustomerApi/GetCustomerList_2 的客戶下拉選項。 */
export interface SalesShippingCustomer {
  customerNo: string
  shortName?: string | null
  longName?: string | null
}
