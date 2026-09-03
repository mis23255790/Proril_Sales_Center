import type { ApiResponse } from '~/types/api'
import type { CustomerRecord, CustomerWithErp, ErpCustomer } from '~/types/customer'

/**
 * 客戶維護 API，對應 1.0 的 Mix/CustomQuery。
 *
 * 後端已搬到 api/ 的 CustomQueryApiController：GetCustom 是既有端點
 * （議題編輯頁的客戶別下拉也在用），GetERPCustom / SaveCustom 是這次新增的。
 * 路由用 [controller]/[action] 慣例產生，class 名稱不能改，否則 URL 跟著變。
 */
export const useCustomerApi = () => {
  const { apiFetch } = useApi()

  const get = <T>(path: string, params?: Record<string, any>) =>
    apiFetch<ApiResponse<T>>(path, { params })

  /** 內網客戶清單（含 ERP 對照名稱）。includeErpCustom 固定送 true，跟舊畫面一致。 */
  const getCustomers = (customNo = '', erpCustomNo = '') =>
    get<CustomerWithErp[]>('/CustomQueryApi/GetCustom', {
      customNo,
      erpCustomNo,
      includeErpCustom: true
    })

  /** ERP 客戶清單，左併對照到的內網客戶代碼。 */
  const getErpCustomers = (erpCustomNo = '') =>
    get<ErpCustomer[]>('/CustomQueryApi/GetERPCustom', { customNo: '', erpCustomNo })

  /** 新增或更新客戶。customerNo 空字串 = 新增，後端自動產生代碼。 */
  const saveCustomer = (customer: CustomerRecord) =>
    get<string>('/CustomQueryApi/SaveCustom', {
      customerNo: customer.customerNo ?? '',
      erpCustomerNo: customer.erpcustomerNo ?? '',
      shortName: customer.shortName ?? '',
      longName: customer.longName ?? '',
      contactName: customer.contactName ?? '',
      contactTel1: customer.contactTel1 ?? '',
      contactTel2: customer.contactTel2 ?? '',
      contactFax: customer.contactFax ?? '',
      contactEmail: customer.contactEmail ?? '',
      addr1: customer.addr1 ?? '',
      addr2: customer.addr2 ?? '',
      salesNo: customer.salesNo ?? '',
      salesName: customer.salesName ?? '',
      potentialCustom: customer.potentialCustom ?? ''
    })

  /** 啟用中的使用者清單，指派業務負責人用（MainApiController.GetUserList）。 */
  const getUserList = () =>
    get<{ account: string, userName: string }[]>('/MainApi/GetUserList')

  return {
    getCustomers,
    getErpCustomers,
    saveCustomer,
    getUserList
  }
}
