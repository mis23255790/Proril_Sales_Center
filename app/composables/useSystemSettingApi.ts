import type { ApiResponse } from '~/types/api'
import type {
  MyPermissions,
  RBACPermission,
  RoleDetail,
  RoleListItem,
  UserListItem,
  UserSetting
} from '~/types/system'

/**
 * 系統管理（人員管理 / 權限管理）的 API。
 *
 * 權限是角色制（RBAC）：角色綁一組 PermissionKey，帳號掛多個角色，
 * 見 api/Controllers/Shared/MainApiController.SystemSetting.cs。
 * 陣列參數照 1.0 的習慣送 **JSON 字串**不是陣列，後端是用 JsonConvert.DeserializeObject 解的。
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

  const addUser = (account: string, name: string, isEnable: boolean) =>
    apiFetch<ApiResponse>('/MainApi/AddUser', { params: { account, name, isEnable } })

  const updateUser = (account: string, name: string, isEnable: boolean) =>
    apiFetch<ApiResponse>('/MainApi/UpdateUser', { params: { account, name, isEnable } })

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

  /** 設定某帳號的角色（整批取代）。everyone 自動擁有，不用傳。 */
  const setUserRoles = (account: string, roleIds: number[]) =>
    apiFetch<ApiResponse>('/MainApi/SetUserRoles', {
      params: { account, str_role_ids: JSON.stringify(roleIds) }
    })

  // ---------------------------------------------------------------- 權限樹

  /**
   * 權限樹節點（RBAC_Permission，單一樹自我參照），依 sort 排序，只要登入就能讀。
   * 預設只回有效節點（側欄、模組首頁、麵包屑用）；權限管理的樹傳 includeDisabled = true，
   * 連停用節點一起拿（isActive = false，顯示成 disabled）。
   */
  const getPermissions = (includeDisabled = false) =>
    apiFetch<ApiResponse<RBACPermission[]>>('/MainApi/GetRBACPermission', {
      params: includeDisabled ? { includeDisabled } : undefined
    })

  // ---------------------------------------------------------------- 角色

  const getRoleList = () => apiFetch<ApiResponse<RoleListItem[]>>('/MainApi/GetRoleList')

  const getRole = (roleId: number) =>
    apiFetch<ApiResponse<RoleDetail>>('/MainApi/GetRole', { params: { roleId } })

  /** 新增（roleId = 0）或修改角色，回傳 body = 角色 ID。後端會自己補隱含的 `.view`。 */
  const saveRole = (role: {
    roleId: number
    roleCode: string
    roleName: string
    description: string
    permissionKeys: string[]
  }) =>
    apiFetch<ApiResponse<number>>('/MainApi/SaveRole', {
      params: {
        roleId: role.roleId,
        roleCode: role.roleCode,
        roleName: role.roleName,
        description: role.description,
        str_permission_keys: JSON.stringify(role.permissionKeys)
      }
    })

  const deleteRole = (roleId: number) =>
    apiFetch<ApiResponse>('/MainApi/DeleteRole', { params: { roleId } })

  /** 設定角色成員（整批取代）。 */
  const setRoleMembers = (roleId: number, accounts: string[]) =>
    apiFetch<ApiResponse>('/MainApi/SetRoleMembers', {
      params: { roleId, str_accounts: JSON.stringify(accounts) }
    })

  // ---------------------------------------------------------------- 目前登入者

  /** 目前登入者的有效權限，usePermission 載一次後快取。 */
  const getMyPermissions = () =>
    apiFetch<ApiResponse<MyPermissions>>('/MainApi/GetMyPermissions')

  return {
    getUserSetting,
    addUser,
    updateUser,
    deleteUser,
    resetPassword,
    unlockUser,
    getAllUserList,
    setUserRoles,
    getPermissions,
    getRoleList,
    getRole,
    saveRole,
    deleteRole,
    setRoleMembers,
    getMyPermissions
  }
}
