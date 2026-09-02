/**
 * 舊系統的欄位級權限檢查（M_Permission / M_PermissionLinkType）。
 *
 * 沒有整包放進 JWT，每次用到才即時打後端查（後端邏輯本身沒動，
 * 見 MainApiController_SystemSetting.CheckUserPermissionLinkType）：
 * IsAdmin 帳號直接放行，否則查 M_Permission 是否存在
 * (LinkNumber=帳號, FunctionNo=functionNo, LinkType=linkType) 這一列。
 *
 * LinkType 沒有跨功能通用的常數表，每個 FunctionNo 底下的值各自定義，
 * 呼叫端要帶自己模組定義好的 functionNo/linkType（例如
 * SALES_SHIPPING_FUNCTION_NO / SALES_SHIPPING_AMOUNT_LINK_TYPE）。
 */
export const usePermission = () => {
  const { apiFetch } = useApi()

  /** 回傳裸 bool，不是 ApiResponse 信封（跟站上其他 API 不同，這支例外）。 */
  const checkLinkTypePermission = (functionNo: number, linkType: number) =>
    apiFetch<boolean>('/MainApi/CheckUserPermissionLinkType', { params: { functionNo, linkType } })

  return { checkLinkTypePermission }
}
