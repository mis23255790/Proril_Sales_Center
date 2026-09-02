import type { ApiResponse } from '~/types/api'
import type { CopSalesOrder, SalesShippingCustomer } from '~/types/salesShipping'

/**
 * 銷貨檢索共用的查詢條件。
 *
 * groupName 決定 SP 用哪個鍵分群（TH004=品號 / TH001=銷貨單別+單號），
 * orderType/orderNo 只有「單一銷貨單明細」才會帶（篩到單一 TH001+TH002）。
 */
export type SalesOrderQuery = {
  customerNo?: string
  productType: string
  productNo?: string
  productName?: string
  productSpec?: string
  /** YYYYMMDD，見 toCompactDate() */
  startDate?: string
  endDate?: string
  serialNo?: string
  poNo?: string
  orderType?: string
  orderNo?: string
  inPlanNumber?: string
  groupName: string
  groupDesc?: string
}

/**
 * 銷貨檢索後端 API。
 *
 * 全部打舊 PRORIL 的 MixSalesShipApi / CustomerApi（經由 /api/proxy 轉發），
 * 不新增後端、不動資料庫（含預存程序 prc_QuerySalesOrder / prc_QuerySalesOrder_1）。
 */
export const useSalesShippingApi = () => {
  const { apiFetch } = useApi()

  const get = <T>(path: string, params?: Record<string, any>) =>
    apiFetch<ApiResponse<T>>(path, { params })

  const toParams = (q: SalesOrderQuery) => ({
    customerNo: q.customerNo ?? '',
    productType: q.productType,
    productNo: q.productNo ?? '',
    productName: q.productName ?? '',
    productSpec: q.productSpec ?? '',
    startDate: q.startDate ?? '',
    endDate: q.endDate ?? '',
    serialNo: q.serialNo ?? '',
    poNo: q.poNo ?? '',
    inPlanNumber: q.inPlanNumber ?? '',
    groupName: q.groupName,
    groupDesc: q.groupDesc ?? ''
  })

  /** 依品號分群（EXEC prc_QuerySalesOrder），品號細項/統計兩個 tab 的資料來源。 */
  const getSalesOrder = (query: SalesOrderQuery) =>
    get<CopSalesOrder[]>('/MixSalesShipApi/GetSalesOrder', toParams(query))

  /**
   * 依銷貨單分群（EXEC prc_QuerySalesOrder_1），銷貨單細項/統計兩個 tab、
   * 以及品號/銷貨單明細 modal 都是打這支（modal 用 orderType/orderNo 篩單一銷貨單）。
   */
  const getSalesOrder1 = (query: SalesOrderQuery) =>
    get<CopSalesOrder[]>('/MixSalesShipApi/GetSalesOrder_1', {
      ...toParams(query),
      orderType: query.orderType ?? '',
      orderNo: query.orderNo ?? ''
    })

  /** 匯出 Excel，body 回相對於 .NET 站台根目錄的路徑（要接 /ShareRoot/ 前綴）。 */
  const exportXls = (query: SalesOrderQuery) =>
    get<string>('/MixSalesShipApi/ExportXls', {
      ...toParams(query),
      orderType: query.orderType ?? '',
      orderNo: query.orderNo ?? ''
    })

  const getCustomers = (customerNo = '') =>
    get<SalesShippingCustomer[]>('/CustomerApi/GetCustomerList_2', { customerNo })

  return {
    getSalesOrder,
    getSalesOrder1,
    exportXls,
    getCustomers
  }
}
