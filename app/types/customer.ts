/**
 * 客戶維護（原 1.0 Mix/CustomQuery）用的型別。
 *
 * 跟 app/types/salesIssue.ts 的 CrmCustomer 是同一張 CRM_Customer 表，
 * 但那邊只挑了下拉選單用得到的幾個欄位；這裡要做客戶新增/編輯，
 * 需要完整欄位，故獨立成自己的型別，不跟業務議題那組互相牽動。
 */

/** CRM_Customer 客戶主檔完整欄位。 */
export interface CustomerRecord {
  id?: number
  customerNo: string
  customerSource?: string | null
  erpcustomerNo?: string | null
  longName?: string | null
  shortName?: string | null
  contactName?: string | null
  contactTel1?: string | null
  contactTel2?: string | null
  contactFax?: string | null
  contactEmail?: string | null
  addr1?: string | null
  addr2?: string | null
  areaCode?: string | null
  countryCode?: string | null
  salesNo?: string | null
  salesName?: string | null
  /** 'Y' = 潛在客戶, 'N' = 既有客戶 */
  potentialCustom?: string | null
  erpheadCustomer?: string | null
  erpsource?: string | null
  aStatus?: string | null
}

/** GetCustom 回傳：CustomerRecord + ERP 端對照名稱。 */
export interface CustomerWithErp extends CustomerRecord {
  erpCustomShortName?: string | null
  erpCustomLongName?: string | null
}

/** GetERPCustom 回傳：V_ERPCustomer 客戶 + 左併到的內網客戶代碼（查無對照客戶時是空字串）。 */
export interface ErpCustomer {
  erpsource: string
  ma001?: string | null
  ma002?: string | null
  ma003?: string | null
  ma005?: string | null
  ma006?: string | null
  ma007?: string | null
  ma008?: string | null
  ma009?: string | null
  ma019?: string | null
  ma023?: string | null
  ma024?: string | null
  erpheadCustomer?: string | null
  customerNo: string
}

export const POTENTIAL_CUSTOM_OPTIONS = [
  { label: '既有客戶', value: 'N' },
  { label: '潛在客戶', value: 'Y' }
]
