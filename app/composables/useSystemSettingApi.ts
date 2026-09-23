import type { ApiResponse } from '~/types/api'
import type {
  DepFunction,
  DepartmentListItem,
  MFunction,
  MPermission,
  MPermissionDef,
  MSystem,
  UserFunction,
  UserListItem,
  UserSetting
} from '~/types/system'

/**
 * 系統管理（人員管理 / 權限管理 / 群組權限）的 API。
 *
 * 讀取端點沿用 1.0（MainApi/* 與 CommonApi/GetDepFunction）；兩個「存檔」端點是 2.0 改成
 * 字串權限後新開的（SetPermissionKeys / SaveDepPermissionKeys），但參數照 1.0 的習慣送
 * **JSON 字串**不是陣列，後端是用 JsonConvert.DeserializeObject 解的。
 *
 * 回傳型別與 1.0 的差異：人員管理那幾支 1.0 回裸 bool，2.0 改回 ApiResponse 信封，
 * 失敗時才有訊息可顯示（見 api/Controllers/Shared/MainApiController.User.cs 的註解）。
 */
export const useSystemSettingApi = () => {
  const { apiFetch } = useApi()

  // ---------------------------------------------------------------- 人員管理

  /** 查帳號設定。查無帳號時 isSuccess = true 但 body = null，代表可以新增。 */
  const getUserSetting = (account: string) =>
    apiFetch<ApiResponse<UserSetting | null>>('/MainApi/GetUserSetting', { params: { account } })

  const addUser = (account: string, name: string, isEnable: boolean, isAdmin: boolean) =>
    apiFetch<ApiResponse>('/MainApi/AddUser', { params: { account, name, isEnable, isAdmin } })

  const updateUser = (account: string, name: string, isEnable: boolean, isAdmin: boolean) =>
    apiFetch<ApiResponse>('/MainApi/UpdateUser', { params: { account, name, isEnable, isAdmin } })

  const deleteUser = (account: string) =>
    apiFetch<ApiResponse>('/MainApi/DeleteUser', { params: { account } })

  /** 密碼重置成「密碼 = 帳號」，並強制下次登入改密碼。 */
  const resetPassword = (account: string) =>
    apiFetch<ApiResponse>('/MainApi/ResetPassword', { params: { Account: account } })

  /** 解除鎖定（1.0 沒有這支，見後端註解）。 */
  const unlockUser = (account: string) =>
    apiFetch<ApiResponse>('/MainApi/UnlockUser', { params: { account } })

  /** 全部帳號（含停用），工號下拉用。 */
  const getAllUserList = () =>
    apiFetch<ApiResponse<UserListItem[]>>('/MainApi/GetAllUserList')

  // ---------------------------------------------------------------- 權限樹

  const getSystems = () => apiFetch<ApiResponse<MSystem[]>>('/MainApi/GetMSystem')

  const getFunctions = () => apiFetch<ApiResponse<MFunction[]>>('/MainApi/GetMFunction')

  /** 字串權限主檔（M_PermissionDef），樹的功能節點與細項節點都從這裡長。 */
  const getPermissionDefs = () =>
    apiFetch<ApiResponse<MPermissionDef[]>>('/MainApi/GetMPermissionDef')

  /** 某帳號目前已有的權限列（含全體帳號 000000 的）。 */
  const getUserPermissions = (account: string) =>
    apiFetch<ApiResponse<MPermission[]>>('/MainApi/GetPermissionLinkType', { params: { account } })

  /** 個人權限存檔，送勾到的 PermissionKey 陣列（後端會自己補隱含的 `.view`）。 */
  const savePermissionKeys = (account: string, permissionKeys: string[]) =>
    apiFetch<ApiResponse>('/MainApi/SetPermissionKeys', {
      params: { account, str_permission_keys: JSON.stringify(permissionKeys) }
    })

  // ---------------------------------------------------------------- 群組預設功能

  const getDepartments = () =>
    apiFetch<ApiResponse<DepartmentListItem[]>>('/MainApi/GetDepartmentList')

  const getDepFunctions = (depCode: string) =>
    apiFetch<ApiResponse<DepFunction[]>>('/CommonApi/GetDepFunction', { params: { depCode } })

  /** 群組範本存檔（群組權限頁），要 system.groupPermission.view 權限。 */
  const saveDepPermissionKeys = (depCode: string, permissionKeys: string[]) =>
    apiFetch<ApiResponse>('/MainApi/SaveDepPermissionKeys', {
      params: { depCode, str_permission_keys: JSON.stringify(permissionKeys) }
    })

  // ---------------------------------------------------------------- 側欄

  /** 目前登入者可以進入的功能，側欄用它過濾。 */
  const getUserFunctions = () =>
    apiFetch<ApiResponse<UserFunction[]>>('/MainApi/GetUserFunctions')

  return {
    getUserSetting,
    addUser,
    updateUser,
    deleteUser,
    resetPassword,
    unlockUser,
    getAllUserList,
    getSystems,
    getFunctions,
    getPermissionDefs,
    getUserPermissions,
    savePermissionKeys,
    getDepartments,
    getDepFunctions,
    saveDepPermissionKeys,
    getUserFunctions
  }
}
