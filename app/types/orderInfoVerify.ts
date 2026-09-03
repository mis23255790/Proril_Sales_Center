/**
 * 訂單資料檢核 (舊 PRORIL Mix/OrderInfoVerify) 型別。
 *
 * 跟銷貨檢索/未完成訂單檢索是不同資料表/不同 ViewModel，欄位命名也不同（這裡混著中文
 * 屬性名，跟後端 VPoList/VPoDetailList 的形狀一致），刻意不共用型別或常數。
 */

/** FunctionId.OrderInfoVerify，權限檢查用。1.0 enum 註解「訂單資料查核」，畫面顯示「訂單資料檢核」。 */
export const ORDER_INFO_VERIFY_FUNCTION_NO = 425

/** M_PermissionLinkType.LinkType，金額欄位的權限碼。 */
export const ORDER_INFO_VERIFY_AMOUNT_LINK_TYPE = 100

/** 檢核結果值域：Y=通過、N=不通過、P=特規Pass。 */
export const CHK = { OK: 'Y', NG: 'N', PASS: 'P' } as const
export type ChkValue = typeof CHK[keyof typeof CHK] | null | undefined

/** COP_PoCheck：訂單檢核表頭，prc_COPOrderChk 執行後寫回這張表。 */
export interface CopPoCheck {
  id: number
  orderChkNo?: string | null
  chkTime?: string | null
  copSource?: string | null
  /** "{單別}-{單號}" */
  poNo?: string | null
  sumAmt?: number | null
  sumQty?: number | null
  custAmt?: number | null
  availableAmt?: number | null
  depChk?: ChkValue
  depBlankChk?: ChkValue
  packListBlankChk?: ChkValue
  priceBlankChk?: ChkValue
  preDateChk?: ChkValue
  custSumAmtChk?: ChkValue
  custAmtZeroChk?: ChkValue
  custPochk?: ChkValue
  transChk?: ChkValue
  tradeChk?: ChkValue
  outPortChk?: ChkValue
  inPortChk?: ChkValue
  upFileChk?: ChkValue
  detailChk?: ChkValue
  rateChk?: ChkValue
  paidChk?: ChkValue
  availableChk?: ChkValue
  credit30Wchk?: ChkValue
  processCodeChk?: ChkValue
  finChk?: ChkValue
  memo?: string | null
  // 對應規則說明文字（來自 COP_CheckRule.ChkRule）
  depChkRule?: string | null
  depBlankChkRule?: string | null
  packListChkRule?: string | null
  packListBlankChkRule?: string | null
  priceChkRule?: string | null
  priceBlankChkRule?: string | null
  preDateChkRule?: string | null
  custSumAmtChkRule?: string | null
  custAmtZeroChkRule?: string | null
  custPochkRule?: string | null
  processCodeChkRule?: string | null
  transChkRule?: string | null
  tradeChkRule?: string | null
  outPortChkRule?: string | null
  inPortChkRule?: string | null
  upFileChkRule?: string | null
  rateChkRule?: string | null
  paidChkRule?: string | null
  availableChkRule?: string | null
  credit30WchkRule?: string | null
}

/** COP_PoDetailCheck：訂單檢核明細（逐品號一列）。 */
export interface CopPoDetailCheck {
  id: number
  orderChkNo?: string | null
  copSource?: string | null
  poNo?: string | null
  sno?: string | null
  productNo?: string | null
  productNoChk?: ChkValue
  qtyChk?: ChkValue
  amtChk?: ChkValue
  priceChk?: ChkValue
  packListChk?: ChkValue
  linkTypeChk?: ChkValue
  linkNoChk?: ChkValue
  linkSnoChk?: ChkValue
  linkQtyChk?: ChkValue
  linkPriceChk?: ChkValue
  linkChk?: ChkValue
  moqamtChk?: ChkValue
  linkMoqamtChk?: ChkValue
  finChk?: ChkValue
  memo?: string | null
  productNoChkRule?: string | null
  qtyChkRule?: string | null
  amtChkRule?: string | null
  priceChkRule?: string | null
  packListChkRule?: string | null
  linkTypeChkRule?: string | null
  linkNoChkRule?: string | null
  linkSnoChkRule?: string | null
  linkQtyChkRule?: string | null
  linkPriceChkRule?: string | null
  linkChkRule?: string | null
  moqamtChkRule?: string | null
  linkMoqamtChkRule?: string | null
}

/** COP_PassCheck：特規 Pass 紀錄。 */
export interface CopPassCheck {
  id: number
  orderChkNo?: string | null
  sno?: string | null
  passTime?: string | null
  passItems?: string | null
  passMemo?: string | null
}

/** V_PODetailList：訂單明細列。 */
export interface VPoDetail {
  copSource: string
  單別: string
  單號: string
  序號: string
  品號?: string | null
  品名?: string | null
  規格?: string | null
  英文品名?: string | null
  英文規格?: string | null
  幣別?: string | null
  匯率?: number | null
  訂單數量?: number | null
  單位?: string | null
  外幣單價?: number | null
  外幣金額?: number | null
  台幣金額?: number | null
  預交日?: string | null
  finFlag?: ChkValue
}

/** V_Product_English_All：英文品名。 */
export interface VProductEnglish {
  productNo?: string | null
  productName?: string | null
  specification?: string | null
  productNameE?: string | null
  specificationE?: string | null
}

/**
 * GetPOCheckView 的查詢結果列：V_POList 表頭欄位（camelCase 化，中文屬性照抄後端）
 * + 該品號的明細/檢核狀態。同一張訂單的多列共用同一份表頭與 copPoCheck。
 */
export interface OrderInfoVerifyRow {
  copSource: string
  單別名稱?: string | null
  單別: string
  單號: string
  訂單日期?: string | null
  價格條件?: string | null
  客戶代號?: string | null
  客戶名稱: string
  部門代號: string
  業務人員?: string | null
  業務名稱: string
  送貨地址一?: string | null
  送貨地址二?: string | null
  付款條件?: string | null
  課稅別?: string | null
  運輸方式?: string | null
  幣別?: string | null
  匯率?: number | null
  訂單金額?: number | null
  總數量?: number | null
  packinglist備註?: string | null
  客戶單號?: string | null
  交易條件?: string | null
  交易條件名稱: string
  起始港口?: string | null
  目的港口?: string | null
  連絡人?: string | null
  telNo?: string | null
  faxNo?: string | null
  附件檔案: string
  流程代號?: string | null
  finFlag?: ChkValue
  confirmFlag: string
  vPoDetail: VPoDetail
  copPoCheck?: CopPoCheck | null
  copPoDetailCheck?: CopPoDetailCheck | null
  copPassChecks: CopPassCheck[]
  vProductEnglish?: VProductEnglish | null
  depName?: string | null
}

/** COP_CheckRule：「檢核條件」說明清單。 */
export interface CopCheckRule {
  id: number
  recType?: string | null
  chkField?: string | null
  erpfield?: string | null
  chkRule?: string | null
  chkLevel?: string | null
  passFlag?: string | null
}

/** prc_COPGetCredit 查詢結果，中文欄位直接對應後端，不做語意翻譯。 */
export interface CreditInfo {
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
}

/** 依訂單分組後的一列，主表格顯示用。 */
export interface OrderInfoVerifyGroup {
  key: string
  copSource: string
  單別名稱?: string | null
  單別: string
  單號: string
  訂單日期?: string | null
  客戶代號?: string | null
  客戶名稱: string
  部門代號: string
  packinglist備註?: string | null
  客戶單號?: string | null
  訂單金額?: number | null
  交易條件?: string | null
  交易條件名稱: string
  起始港口?: string | null
  目的港口?: string | null
  運輸方式?: string | null
  流程代號?: string | null
  業務名稱: string
  業務人員?: string | null
  confirmFlag: string
  copPoCheck?: CopPoCheck | null
  /** 這張訂單底下所有品號明細列，開檢核 modal 用。 */
  rows: OrderInfoVerifyRow[]
}
