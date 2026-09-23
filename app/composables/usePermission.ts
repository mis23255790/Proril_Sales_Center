/**
 * 字串權限檢查（`module.function.action`，常數在 app/utils/permissionKeys.ts）。
 *
 * 沒有整包放進 JWT，每次用到才即時打後端查（見 MainApiController.CheckPermission）：
 * IsAdmin 帳號直接放行，否則查 M_Permission 是否有
 * (LinkNumber = 帳號 或 000000, PermissionKey = key) 這一列。
 *
 * 取代原本的 checkLinkTypePermission(functionNo, linkType)，
 * 呼叫端不用再各自定義 *_AMOUNT_LINK_TYPE 這種數字。
 */
export const usePermission = () => {
  const { apiFetch } = useApi()

  /** 回傳裸 bool，不是 ApiResponse 信封（跟站上其他 API 不同，這支例外）。 */
  const checkPermission = (permissionKey: string) =>
    apiFetch<boolean>('/MainApi/CheckPermission', { params: { permissionKey } })

  return { checkPermission }
}
