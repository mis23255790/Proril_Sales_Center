import type { ApiResponse } from '~/types/api'
import type { CustomerWithErp, ErpCustomer } from '~/types/customer'
import type {
  CustomerCreditRow,
  CustomerMemo,
  CustomerUnfinOrderRow,
  CustomerWorkProcessRow,
  SalesTotalRow
} from '~/types/customerRelated'

/**
 * 客戶相關資訊 API，對應 1.0 的 Mix/CustomerRelated。
 *
 * 端點散在三支 controller，沿用 1.0 的 URL（路由是從 class 名稱產生的，不能改）：
 *   CustomQueryApi/{GetCustom,GetERPCustom,GetCustomMemo,SetCustomMemo,DeleteCustomMemo}
 *   MixSalesShipApi/{GetSalesTotal,GetCustomerUnfinOrder,GetCustomerCreditCRM}
 *   WorkProcessApi/GetWPOrderForCustom
 *
 * 基本資料的兩支（GetCustom / GetERPCustom）跟客戶檢索共用，這裡不重複包，
 * 直接用 useCustomerApi()。
 *
 * **customerNo 是內網客編、erpCustomerNo 是 ERP 客編，不可互換**：
 * 情報與議題吃內網客編，銷售／訂單／信用額度吃 ERP 客編。
 * 1.0 有幾支的簽章同時收兩個但只用其中一個，這裡照樣兩個都送，維持 URL 相容。
 */
export const useCustomerRelatedApi = () => {
  const { apiFetch } = useApi()

  const get = <T>(path: string, params?: Record<string, any>) =>
    apiFetch<ApiResponse<T>>(path, { params })

  /** 情報清單。只有 customerNo 有效，單純帶 erpCustomerNo 後端一律回空。 */
  const getMemos = (customerNo: string, erpCustomerNo = '') =>
    get<CustomerMemo[]>('/CustomQueryApi/GetCustomMemo', { wpNo: '', customerNo, erpCustomerNo })

  /** 新增（id 傳 0）或更新一筆情報。 */
  const saveMemo = (memo: { id: number, customerNo: string, memoType: string, memoDesc: string }) =>
    get<null>('/CustomQueryApi/SetCustomMemo', {
      id: memo.id,
      customerNo: memo.customerNo,
      memoType: memo.memoType,
      memoDesc: memo.memoDesc
    })

  /** 軟刪除一筆情報（1.0 沒有這支，2.0 補的）。 */
  const deleteMemo = (id: number) =>
    get<null>('/CustomQueryApi/DeleteCustomMemo', { id })

  /** 年／月銷售統計。ym 長度 4 是年度總計、6 是單月，兩種混在一起。 */
  const getSalesTotal = (customerNo: string, erpCustomerNo: string) =>
    get<SalesTotalRow[]>('/MixSalesShipApi/GetSalesTotal', { customerNo, erpCustomerNo })

  /** 未完成訂單的逐筆品項，分群由頁面自己做。 */
  const getUnfinOrders = (customerNo: string, erpCustomerNo: string) =>
    get<CustomerUnfinOrderRow[]>('/MixSalesShipApi/GetCustomerUnfinOrder', { customerNo, erpCustomerNo })

  /** 信用額度（prc_COPGetCredit_CRM 版本，1.0 畫面實際用的是這支，不是 GetCustomerCredit）。 */
  const getCredits = (customerNo: string, erpCustomerNo: string) =>
    get<CustomerCreditRow[]>('/MixSalesShipApi/GetCustomerCreditCRM', { customerNo, erpCustomerNo })

  /** 這個客戶掛了哪些議題。只吃內網客編。 */
  const getWorkProcesses = (customerNo: string) =>
    get<CustomerWorkProcessRow[]>('/WorkProcessApi/GetWPOrderForCustom', { customerNo })

  /** 基本資料頁籤的內網客戶資料。跟客戶檢索共用同一支端點。 */
  const getCustomer = (customerNo: string, erpCustomerNo: string) =>
    get<CustomerWithErp[]>('/CustomQueryApi/GetCustom', {
      customNo: customerNo,
      erpCustomNo: erpCustomerNo,
      includeErpCustom: true
    })

  /** 基本資料頁籤的 ERP 客戶資料。 */
  const getErpCustomer = (erpCustomerNo: string) =>
    get<ErpCustomer[]>('/CustomQueryApi/GetERPCustom', { customNo: '', erpCustomNo: erpCustomerNo })

  return {
    getCustomer,
    getErpCustomer,
    getMemos,
    saveMemo,
    deleteMemo,
    getSalesTotal,
    getUnfinOrders,
    getCredits,
    getWorkProcesses
  }
}
