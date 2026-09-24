import type { MyPermissions } from '~/types/system'

/**
 * 字串權限檢查（`module.function.action`，常數在 app/utils/permissionKeys.ts）。
 *
 * 權限是角色制：有效權限 = 所屬角色 ∪ everyone，superAdmin 全放行（後端 PermissionService）。
 * 登入後打一次 MainApi/GetMyPermissions 存在 useState，之後每個 key 都查這份，
 * 不用每個 key 各打一次後端。**這只決定畫面顯示**，真正的把關在後端
 * （RequirePermissionAttribute / HasPermission），前端判斷錯了也拿不到資料。
 *
 * 角色有異動（權限管理存檔）時呼叫 loadPermissions(true) 重載，才會反映到自己身上。
 */
type PermissionStatus = 'idle' | 'loading' | 'loaded' | 'failed'

const usePermissionState = () => useState<MyPermissions | null>('app-my-permissions', () => null)
const usePermissionStatus = () => useState<PermissionStatus>('app-my-permissions-status', () => 'idle')

/** 同一輪 onMounted 好幾個地方同時要權限時共用同一個請求（只在 client 端呼叫）。 */
let pendingLoad: Promise<MyPermissions | null> | null = null

export const usePermission = () => {
  const permissions = usePermissionState()
  const status = usePermissionStatus()

  const loadPermissions = async (force = false) => {
    if (status.value === 'loaded' && !force) return permissions.value
    if (pendingLoad && !force) return pendingLoad

    status.value = 'loading'
    pendingLoad = (async () => {
      try {
        const { getMyPermissions } = useSystemSettingApi()
        const res = await getMyPermissions()
        if (res?.isSuccess && res.body) {
          permissions.value = res.body
          status.value = 'loaded'
        } else {
          permissions.value = null
          status.value = 'failed'
        }
      } catch (err) {
        console.log('load my permissions failed -->', err)
        permissions.value = null
        status.value = 'failed'
      } finally {
        pendingLoad = null
      }
      return permissions.value
    })()
    return pendingLoad
  }

  const keySet = computed(() => new Set(permissions.value?.keys ?? []))

  /** 同步判斷（要先 loadPermissions）。沒載到一律當沒有權限。 */
  const can = (permissionKey: string) =>
    !!permissions.value && (permissions.value.isSuperAdmin || keySet.value.has(permissionKey))

  const isSuperAdmin = computed(() => !!permissions.value?.isSuperAdmin)

  /** 非同步判斷：會先確保權限已載入。頁面 onMounted 裡用這個最省事。 */
  const checkPermission = async (permissionKey: string) => {
    await loadPermissions()
    return can(permissionKey)
  }

  /** 權限載入失敗（API 掛了、token 過期）。側欄在這種情況不過濾，見 useAppNavigation。 */
  const failed = computed(() => status.value === 'failed')

  return { loadPermissions, can, checkPermission, isSuperAdmin, failed }
}
