import type { ApiResponse } from '~/types/api'
import type { SalesShippingCustomer } from '~/types/salesShipping'
import type { UnfinOrder } from '~/types/salesOrderUnfinish'

/**
 * 未完成訂單檢索共用的查詢條件。
 *
 * groupName 決定 SP 用哪個鍵分群（TD004=品號 / TC001=訂單單別+單號）。
 * SP 本身不支援 orderType/orderNo 篩選單一訂單，後端收到 orderType 非空時
 * 會用 LINQ 對已查出的結果再過濾一次（保留 FooterFlag=Y 的小計列）——
 * 篩單一訂單要靠 poNo 帶 `"{訂單單別}-{訂單單號}"` 組合字串，細節見 logic.md。
 */
export type UnfinOrderQuery = {
  /** 1.0 畫面上沒有這個輸入框，一律送空字串。 */
  inCopSource?: string
  customerNo?: string
  productType: string
  productNo?: string
  productName?: string
  productSpec?: string
  /** YYYYMMDD，見 toCompactDate() */
  startDate?: string
  endDate?: string
  /** 預交日，YYYYMMDD，可不設 */
  deliveryStartDate?: string
  deliveryEndDate?: string
  serialNo?: string
  /** 訂單單號（一般查詢），或單一訂單 modal 用的 "{單別}-{單號}" 組合字串 */
  poNo?: string
  /** 訂單單別，只做後端 LINQ 後過濾，SP 本身不吃這個參數 */
  orderType?: string
  inPlanNumber?: string
  groupName: string
  groupDesc?: string
}

/**
 * 未完成訂單檢索後端 API。
 *
 * 全部打舊 PRORIL 的 SalesOrderUnFinishApi / CustomerApi（經由 /api/proxy 轉發），
 * 不新增後端、不動資料庫（含預存程序 prc_QueryUnfinOrder / prc_QueryUnfinOrder_1）。
 */
export const useSalesOrderUnfinishApi = () => {
  const { apiFetch } = useApi()

  const get = <T>(path: string, params?: Record<string, any>) =>
    apiFetch<ApiResponse<T>>(path, { params })

  const toParams = (q: UnfinOrderQuery) => ({
    inCopSource: q.inCopSource ?? '',
    inCustomerNo: q.customerNo ?? '',
    productType: q.productType,
    productNo: q.productNo ?? '',
    productName: q.productName ?? '',
    productSpec: q.productSpec ?? '',
    startDate: q.startDate ?? '',
    endDate: q.endDate ?? '',
    deliveryStartDate: q.deliveryStartDate ?? '',
    deliveryEndDate: q.deliveryEndDate ?? '',
    serialNo: q.serialNo ?? '',
    poNo: q.poNo ?? '',
    orderType: q.orderType ?? '',
    // 舊畫面一律送空字串，SP 跟後端過濾都用不到這個參數。
    orderNo: '',
    inPlanNumber: q.inPlanNumber ?? '',
    groupName: q.groupName,
    groupDesc: q.groupDesc ?? ''
  })

  /** 依品號分群（EXEC prc_QueryUnfinOrder），品號細項/統計兩個 tab 的資料來源。 */
  const getUnfinOrder = (query: UnfinOrderQuery) =>
    get<UnfinOrder[]>('/SalesOrderUnFinishApi/GetUnfinOrder', toParams(query))

  /** 依訂單分群（EXEC prc_QueryUnfinOrder_1），訂單細項/統計兩個 tab 的資料來源。 */
  const queryUnfinOrder1 = (query: UnfinOrderQuery) =>
    get<UnfinOrder[]>('/SalesOrderUnFinishApi/QueryUnfinOrder_1', toParams(query))

  /** 匯出 Excel，body 回相對於 .NET 站台根目錄的路徑（要接 /ShareRoot/ 前綴）。 */
  const exportXls = (query: UnfinOrderQuery) =>
    get<string>('/SalesOrderUnFinishApi/ExportXls', toParams(query))

  const getCustomers = (customerNo = '') =>
    get<SalesShippingCustomer[]>('/CustomerApi/GetCustomerList_2', { customerNo })

  return {
    getUnfinOrder,
    queryUnfinOrder1,
    exportXls,
    getCustomers
  }
}
