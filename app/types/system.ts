// M_System：系統別主檔，topbar 用 imagePath 顯示正式區/測試區環境圖示。
export interface MSystem {
  id: number
  systemNo: number
  systemName: string
  systemType: number
  typeName?: string | null
  sort: number
  imagePath?: string | null
  href: string
  redirectHref?: string | null
}

// ---------------------------------------------------------------- 權限控管

/** RBAC_Permission.NodeType：模組 → 分組 → 頁面 → 細項。 */
export type PermissionNodeType = 'MODULE' | 'GROUP' | 'PAGE' | 'ACTION'

/**
 * RBAC_Permission：權限樹的一個節點（單一表自我參照，parentKey 指父節點）。
 * 側欄、模組首頁、麵包屑與權限管理的樹都由它長出來（MainApi/GetRBACPermission，只回有效節點）。
 * 頁面 key = `module.function`，細項 = `module.function.action`，見 app/utils/permissionKeys.ts。
 */
export interface RBACPermission {
  permissionKey: string
  nodeType: PermissionNodeType
  parentKey?: string | null
  label: string
  labelEn?: string | null
  /** 前端路由（不含 /sales-center），MODULE / PAGE 才有。 */
  path?: string | null
  icon?: string | null
  description?: string | null
  sort: number
  /**
   * 自己與所有祖先都是 aStatus = 'Y'。預設的 GetRBACPermission 只回 true 的節點；
   * 權限管理用 includeDisabled 才會拿到 false 的（顯示成 disabled）。
   */
  isActive: boolean
}

/** RBAC_Role：角色清單的一列。 */
export interface RoleListItem {
  id: number
  roleCode: string
  roleName: string
  description?: string | null
  /** 系統角色（superAdmin / everyone）：不可刪、不可改代碼。 */
  isSystem: boolean
  /** 全放行，不需要勾權限。 */
  isSuperAdmin: boolean
  /** 所有啟用帳號自動擁有，不需要設成員。 */
  isDefault: boolean
  sort: number
  permissionCount: number
  memberCount: number
}

/** 單一角色：基本資料 + 權限 + 成員帳號。 */
export interface RoleDetail extends RoleListItem {
  permissionKeys: string[]
  members: string[]
}

/** 目前登入者的有效權限（MainApi/GetMyPermissions）。 */
export interface MyPermissions {
  isSuperAdmin: boolean
  keys: string[]
}

/** 人員管理畫面的帳號設定。isAdmin = 有沒有掛 superAdmin 角色。 */
export interface UserSetting {
  account: string
  userName: string
  isEnable: boolean
  isAdmin: boolean
  isLocked: boolean
  isFirstLogin: boolean
  lastChangePwd?: string | null
  /** 所屬角色（RBAC_RoleUser），不含自動擁有的 everyone。 */
  roleIds: number[]
}

/** 工號下拉用。 */
export interface UserListItem {
  account: string
  userName: string
  isEnable: boolean
  /** 有沒有掛 superAdmin 角色。 */
  isAdmin: boolean
  isLocked: boolean
}

/**
 * 權限樹節點（權限管理的樹）。MODULE / GROUP 是純分類，checkable = false，
 * 但照樣有 permissionKey——存檔時勾到的頁面／細項會沿路把它們一起帶上（側欄要靠它們長出上層）。
 */
export interface PermissionTreeNode {
  key: string
  label: string
  checkable: boolean
  /** 節點停用（自己或祖先 aStatus = 'N'）：照樣顯示、原本的勾選照樣顯示，但不能改，存檔也不送。 */
  disabled: boolean
  nodeType: PermissionNodeType
  permissionKey: string
  children: PermissionTreeNode[]
}
