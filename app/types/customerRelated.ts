/**
 * 客戶相關資訊（原 1.0 Mix/CustomerRelated，FunctionNo 441）用的型別。
 *
 * 這一頁的資料來源橫跨三支 controller，所以型別也散在幾張表／View：
 *   基本資料  CRM_Customer + V_ERPCustomer（沿用 app/types/customer.ts 的型別）
 *   情報      CRM_CustomerMemo
 *   訂單      V_UnfinOrder
 *   銷售      V_SalesTotal
 *   信用額度  prc_COPGetCredit_CRM
 *   議題      D_WorkProcess + D_WorkProcessCustomer
 *
 * **內網客編與 ERP 客編不能混用**：基本資料／情報／議題吃內網客編，
 * 訂單／銷售／信用額度吃 ERP 客編。這是整頁最容易寫錯的地方。
 */

/** CRM_CustomerMemo：客戶情報。後端回傳時多帶一個 creatorName。 */
export interface CustomerMemo {
  id: number
  customerNo?: string | null
  memoType?: string | null
  memoDesc?: string | null
  fileName?: string | null
  aStatus?: string | null
  creator?: string | null
  createTime?: string | null
  modifier?: string | null
  modiTime?: string | null
  /** join M_User 帶出來的作者姓名，查不到是空字串。 */
  creatorName?: string
}

/**
 * V_SalesTotal 的一列。
 *
 * `ym` 長度 4 = 年度總計，長度 6 = 該年某月，**兩種列混在同一份回傳裡**。
 */
export interface SalesTotalRow {
  customerNo?: string | null
  ym?: string | null
  totalQty?: number | null
  totalAmt?: number | null
}

/** V_UnfinOrder 的一列（逐筆品項，未分群）。 */
export interface CustomerUnfinOrderRow {
  copSource?: string | null
  mq002?: string | null
  /** 訂單單別。2700 是詢問單，畫面上要濾掉。 */
  tc001?: string | null
  /** 訂單單號。 */
  tc002?: string | null
  td003?: string | null
  /** 訂單日期。 */
  tc003?: string | null
  /** 客戶代號（ERP）。 */
  tc004?: string | null
  ma002?: string | null
  tc006?: string | null
  mv002?: string | null
  tc010?: string | null
  tc014?: string | null
  tc016?: string | null
  tc019?: string | null
  /** 品號。開頭 5 = 成品、x = 零件。 */
  td004?: string | null
  td005?: string | null
  td006?: string | null
  /** 訂單數量。 */
  td008?: number | null
  td010?: string | null
  td011?: number | null
  /** 原幣金額。乘上匯率 tc009 才是台幣。 */
  td012?: number | null
  tc008?: string | null
  /** 匯率。 */
  tc009?: number | null
  ntd?: number | null
  /** 預交日。 */
  td013?: string | null
  td024?: number | null
  planNumber?: string | null
  serialNosJson?: string | null
  footerFlag?: string | null
}

/**
 * prc_COPGetCredit_CRM 的一列 + 母公司名稱。
 * 欄位名是中文，沿用 1.0 的 COPCreditCRMViewModel，不做語意改名。
 */
export interface CustomerCreditRow {
  應收金額: number
  未結帳銷貨: number
  訂貨出貨通知金額: number
  預收金額: number
  已出貨抵預收金額: number
  應收合計金額: number
  未出貨訂單總金額: number
  未出貨訂單金額比率: number
  信用可超出額: number
  信用餘額: number
  幣別?: string | null
  parentCorpShortName?: string | null
  parentCorpLongName?: string | null
}

/** GetWPOrderForCustom 回傳：D_WorkProcess + 客戶關聯那筆的建立者姓名。 */
export interface CustomerWorkProcessRow {
  wpno?: string | null
  sopTitle?: string | null
  descript?: string | null
  progressStatus?: string | null
  finFlag?: string | null
  userName?: string | null
}

/**
 * 訂單頁籤畫面上的一列：把 V_UnfinOrder 的逐筆品項依「單別+單號」彙總後的結果。
 * 成品(品號開頭 5)與零件(品號開頭 x)的數量金額分開統計，其餘品號不計入。
 */
export interface UnfinOrderSummaryRow {
  copSource?: string | null
  tc001?: string | null
  tc002?: string | null
  tc003?: string | null
  td013?: string | null
  qty05: number
  amt05: number
  qty0x: number
  amt0x: number
  qty0a: number
  amt0a: number
}

/** 銷售頁籤畫面上的一列：某一年度的 12 個月 + 年度合計。 */
export interface SalesYearRow {
  /** 年份；合計列是 'Total'。 */
  year: string
  /** 1~12 月的數量與金額，索引 0 = 1 月。查無資料是 null。 */
  months: { qty: number | null, amt: number | null }[]
  sumQty: number | null
  sumAmt: number | null
  /** 合計列不提供「點進去看銷貨明細」。 */
  isTotal: boolean
}
