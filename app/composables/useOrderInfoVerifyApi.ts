import type { ApiResponse } from '~/types/api'
import type { SalesShippingCustomer } from '~/types/salesShipping'
import type { CopCheckRule, CreditInfo, OrderInfoVerifyRow } from '~/types/orderInfoVerify'

export type OrderInfoVerifyQuery = {
  copSource?: string
  orderType?: string
  orderNo?: string
  customerNo?: string
  /** YYYYMMDD，見 toCompactDate() */
  startDate?: string
  endDate?: string
}

/**
 * 訂單資料檢核後端 API。
 *
 * 跟銷貨檢索/未完成訂單檢索不同，這個模組後端已經搬進 `api/`（含寫入操作），
 * 不是純轉發打 1.0。端點名稱、參數大小寫仍與 1.0 一字不差，方便日後對照。
 */
export const useOrderInfoVerifyApi = () => {
  const { apiFetch } = useApi()

  const get = <T>(path: string, params?: Record<string, any>) =>
    apiFetch<ApiResponse<T>>(path, { params })

  const toParams = (q: OrderInfoVerifyQuery) => ({
    copSource: q.copSource ?? '',
    orderType: q.orderType ?? '',
    orderNo: q.orderNo ?? '',
    customerNo: q.customerNo ?? '',
    startDate: q.startDate ?? '',
    endDate: q.endDate ?? ''
  })

  /** 主查詢：訂單 + 明細 + 檢核狀態的攤平清單。 */
  const getPOCheckView = (query: OrderInfoVerifyQuery) =>
    get<OrderInfoVerifyRow[]>('/OrderInfoVerifyApi/GetPOCheckView', toParams(query))

  /** 「檢核條件」說明清單。 */
  const getConditionList = () =>
    get<CopCheckRule[]>('/OrderInfoVerifyApi/GetConditionList')

  /** 執行一次訂單檢核（寫入操作，呼叫 prc_COPOrderChk）。 */
  const checkCOPOrderInfo = (params: { copSource: string, poNo: string, custAmt: number, paidCheck: 'Y' | 'N', creditAvalAmt: number }) =>
    get<string>('/OrderInfoVerifyApi/CheckCOPOrderInfo', params)

  /** 對單一檢核項目下特規 Pass（寫入操作，呼叫 prc_COPPassCheck）。 */
  const copOrderInfoPassCheck = (params: { checkNo: string, passItem: string, passMemo: string }) =>
    get<string>('/OrderInfoVerifyApi/COPOrderInfoPassCheck', params)

  /** 客戶信用額度。 */
  const getCredit = (customNo: string) =>
    get<CreditInfo[]>('/OrderInfoVerifyApi/SP_GetCredit', { customNo })

  /** 匯出 Excel，body 回相對於 ShareRoot 的路徑。 */
  const exportXls = (query: OrderInfoVerifyQuery & { confirmFlag: string }) =>
    get<string>('/OrderInfoVerifyApi/ExportXls', { ...toParams(query), confirmFlag: query.confirmFlag })

  /** 客戶下拉，沿用銷貨檢索/未完成訂單檢索已經在用的端點。 */
  const getCustomers = (customerNo = '') =>
    get<SalesShippingCustomer[]>('/CustomerApi/GetCustomerList_2', { customerNo })

  return {
    getPOCheckView,
    getConditionList,
    checkCOPOrderInfo,
    copOrderInfoPassCheck,
    getCredit,
    exportXls,
    getCustomers
  }
}
