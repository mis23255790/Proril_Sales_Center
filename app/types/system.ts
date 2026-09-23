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

/** M_Function：功能主檔，權限樹第二層。 */
export interface MFunction {
  id: number
  /** AAABBCC：SystemNo(3) + GroupNo(2) + 序號(2)，見 database/FunctionNoFormatMigration.sql。 */
  functionNo: string
  functionName?: string | null
  systemNo: number
  groupNo?: number | null
  groupName?: string | null
  imagrePath?: string | null
  href?: string | null
  aStatus?: string | null
  redirectHref?: string | null
}

/**
 * M_PermissionDef：字串權限主檔（`module.function.action`，見 app/utils/permissionKeys.ts）。
 * linkType = 1 是功能本身（`.view`），> 1 是功能底下的細項，權限樹第三層以後。
 */
export interface MPermissionDef {
  id: number
  permissionKey: string
  functionNo: string
  linkType: number
  parentPermissionKey?: string | null
  actionName: string
  sort: number
}

/** M_Permission：某帳號已有的權限列。 */
export interface MPermission {
  id: number
  linkNumber?: string | null
  functionNo: string
  linkType: number
  permissionLinkTypeId?: number | null
  /** migration 回填不到的舊列會是 null，樹上不會打勾，存檔時會被刪掉。 */
  permissionKey?: string | null
}

/** 人員管理畫面的帳號設定。 */
export interface UserSetting {
  account: string
  userName: string
  isEnable: boolean
  isAdmin: boolean
  isLocked: boolean
  isFirstLogin: boolean
  lastChangePwd?: string | null
}

/** 工號下拉用。 */
export interface UserListItem {
  account: string
  userName: string
  isEnable: boolean
  isAdmin: boolean
  isLocked: boolean
}

/** 群組（部門）下拉用。 */
export interface DepartmentListItem {
  depCode: string
  depName: string
}

/** 群組預設功能（M_PermissionGroup）+ 對照出來的名稱。 */
export interface DepFunction {
  id: number
  groupNo?: string | null
  functionNo?: string | null
  linkType?: number | null
  permissionKey?: string | null
  functionName: string
  linkTypeName: string
}

/** 側欄用：目前登入者可以進入的功能。 */
export interface UserFunction {
  systemNo: number
  systemName: string
  systemType: number
  typeName?: string | null
  systemSort: number
  functionNo: string
  functionName: string
  groupNo?: number | null
  groupName?: string | null
}

/**
 * 權限樹節點。上面兩層（系統類別／系統）是純分類，checkable = false、沒有 permissionKey；
 * 功能節點的 permissionKey 是該功能的 `.view`，細項節點是細項自己的 key。
 */
export interface PermissionTreeNode {
  key: string
  label: string
  checkable: boolean
  functionNo?: string
  permissionKey?: string
  children: PermissionTreeNode[]
}

/** 群組套用差異清單的一列。 */
export interface PermissionDiffItem {
  permissionKey: string
  /** 「業務檢索 / 銷貨檢索 / 顯示金額欄位」這種路徑，給人看的。 */
  path: string
}
