import type { ApiResponse } from '~/types/api'
import type { CopSalesOrder, SalesOrderPageSummary, SalesOrderTab, SalesShippingCustomer } from '~/types/salesShipping'

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
 * 端點是 MixSalesShipApi / CustomerApi（經由 /api/proxy 轉發）。MixSalesShipApi 已經搬進
 * api/Controllers/SalesSearch/，端點名稱與參數大小寫跟 1.0 一字不差，所以
 * NUXT_PUBLIC_API_BASE 指 api/ 或 1.0 站台都能跑，這支 composable 不用改。
 *
 * 查詢邏輯仍在預存程序 prc_QuerySalesOrder / prc_QuerySalesOrder_1 裡（目前還在 PRORIL_WEB，
 * 搬移腳本見 database/SalesShippingObjectsMigration.sql）。
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

  /**
   * 四個頁籤共用的後端分頁（2.0 新增）。兩支 SP 的結果在後端快取 10 分鐘，
   * refresh=true（按查詢）才重跑 SP，翻頁／切頁籤送 false 直接從快取切。
   * 翻頁時 query 必須是「上次按查詢時」的條件，否則對不到快取、會重跑 SP。
   * 四個頁籤筆數與總金額在 body2（SalesOrderPageSummary）。pageSize <= 0 代表不分頁。
   */
  const getSalesOrderPage = (
    query: Omit<SalesOrderQuery, 'groupName' | 'groupDesc' | 'orderType' | 'orderNo'>,
    page: { tab: SalesOrderTab, pageIndex: number, pageSize: number, refresh: boolean }
  ) => {
    const { groupName: _g, groupDesc: _d, ...params } = toParams({ ...query, groupName: '' })
    return apiFetch<ApiResponse<CopSalesOrder[], SalesOrderPageSummary>>('/MixSalesShipApi/GetSalesOrderPage', {
      params: { ...params, ...page }
    })
  }

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
    getSalesOrderPage,
    exportXls,
    getCustomers
  }
}
