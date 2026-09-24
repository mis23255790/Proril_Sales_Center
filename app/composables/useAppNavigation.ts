import type { RBACPermission } from '~/types/system'

export type AppNavItem = {
  label: string
  /** 相對於 APP_BASE 的路徑，例如 'sales-issue/issues'。用 itemPath() 取完整路徑。 */
  path: string
  icon?: string
  description?: string
  /** RBAC_Permission.PermissionKey（頁面節點），側欄靠它對目前登入者的權限過濾。 */
  permissionKey: string
}

export type AppNavModule = {
  label: string
  labelEn: string
  icon: string
  /** 相對於 APP_BASE 的模組路徑，例如 'sales-issue'。 */
  path: string
  permissionKey: string
  groups: {
    /** 空字串 = 直接掛在模組底下、沒有分組的頁面。 */
    groupName: string
    items: AppNavItem[]
  }[]
}

/**
 * 站台的根層級。
 *
 * 網址結構比照 1.0 多一層：`業務中心 / 模組 / 功能`
 *   /sales-center/sales-issue/issues
 *   /sales-center/sales-search/shipping-inquiry
 *
 * 頁面檔案的位置要跟著這個結構走（app/pages/sales-center/...），
 * 改這個常數的話 `app/pages/index.vue` 的 redirect 也要一起改
 * （definePageMeta 是編譯期巨集，讀不到這裡的值）。
 */
export const APP_BASE = '/sales-center'

export const APP_BASE_LABEL = '業務中心'

/** 把相對路徑接上 APP_BASE。傳空字串就是業務中心首頁。 */
export const appPath = (relative = '') =>
  relative ? `${APP_BASE}/${relative.replace(/^\/+/, '')}` : APP_BASE

/**
 * 把 RBAC_Permission 的節點排成側欄要的 模組 → 分組 → 頁面 三層。
 *
 * - 最上層只收 MODULE；MODULE 底下的 GROUP 是分組標題，GROUP 底下的 PAGE 是功能。
 * - PAGE 直接掛在 MODULE 底下（沒有分組）也可以，會放進一個沒有標題的分組。
 * - 側欄只顯示這三層，ACTION 與更深的巢狀不在側欄出現（權限管理的樹照樣看得到）。
 * - 節點已由後端依 sort 排好，這裡照原順序。
 */
const toModules = (nodes: RBACPermission[]): AppNavModule[] => {
  const childrenOf = new Map<string, RBACPermission[]>()
  for (const n of nodes) {
    if (!n.parentKey) continue
    const list = childrenOf.get(n.parentKey) ?? []
    list.push(n)
    childrenOf.set(n.parentKey, list)
  }

  const toItem = (n: RBACPermission): AppNavItem => ({
    label: n.label,
    path: n.path ?? '',
    icon: n.icon ?? undefined,
    description: n.description ?? undefined,
    permissionKey: n.permissionKey
  })
  const isPage = (n: RBACPermission) => n.nodeType === 'PAGE' && !!n.path

  return nodes
    .filter(n => n.nodeType === 'MODULE' && !n.parentKey)
    .map((mod) => {
      const children = childrenOf.get(mod.permissionKey) ?? []
      const groups: AppNavModule['groups'] = []

      const loosePages = children.filter(isPage).map(toItem)
      if (loosePages.length) groups.push({ groupName: '', items: loosePages })

      for (const group of children.filter(c => c.nodeType === 'GROUP')) {
        const items = (childrenOf.get(group.permissionKey) ?? []).filter(isPage).map(toItem)
        groups.push({ groupName: group.label, items })
      }

      return {
        label: mod.label,
        labelEn: mod.labelEn ?? '',
        icon: mod.icon ?? 'i-lucide-folder',
        path: mod.path ?? '',
        permissionKey: mod.permissionKey,
        groups
      }
    })
}

/**
 * 權限樹節點（RBAC_Permission）的快取。側欄、首頁卡片、模組首頁共用同一份，
 * 切頁面不重打。default.vue 在 onMounted 呼叫 loadUserFunctions()。
 */
const useNavNodeState = () => useState<RBACPermission[] | null>('app-nav-nodes', () => null)

/**
 * 載入狀態。`nodes === null` 同時代表「還沒載完」與「載入失敗」，兩者畫面處理不同，所以另外記。
 */
type NavStatus = 'idle' | 'loading' | 'loaded' | 'failed'
const useNavStatus = () => useState<NavStatus>('app-nav-status', () => 'idle')

/** 進行中的請求，同一輪 onMounted 好幾處同時呼叫時共用（只在 client 端呼叫）。 */
let pendingLoad: Promise<RBACPermission[] | null> | null = null

/**
 * 業務中心的功能表。
 *
 * **整棵樹都從 DB 來**（RBAC_Permission 單一表自我參照）：模組、分組、頁面的名稱、路由、icon、
 * 說明與順序都在那張表，要搬位置改 ParentKey、換順序改 Sort，前端不用改程式。
 * 「這個人看得到哪些」再用 usePermission 的有效權限過濾（superAdmin 全開）。
 *
 * 新增頁面：在 RBAC_Permission 加 PAGE 節點（Path 對到 app/pages/sales-center/ 底下的頁面），
 * 見 docs/modules/SystemSetting/logic.md「新增一個功能要改哪裡」。
 */
export const useAppNavigation = () => {
  const nodes = useNavNodeState()
  const status = useNavStatus()
  const { loadPermissions, can, failed: permissionFailed } = usePermission()

  /**
   * 載入功能表與目前登入者的權限（兩支平行打）。
   *
   * - **載入中**：側欄不顯示任何功能，避免先列出全部、權限回來後又消失的閃動。
   * - **權限沒載到**（API 掛了、token 過期）：不過濾，顯示全部項目——
   *   寧可多顯示，也不要讓人一進站看到空選單以為系統壞了。真正的把關在後端。
   * - **功能表沒載到**：沒有別的來源可以長側欄，只能顯示空的，由 hasNoAccessibleModule 提示。
   *
   * 「權限載到但一個都沒有」照樣過濾成空，並顯示「沒有可用功能」的提示。
   */
  const loadUserFunctions = async (force = false) => {
    if (status.value === 'loaded' && !force) return nodes.value
    if (pendingLoad && !force) return pendingLoad

    status.value = 'loading'
    pendingLoad = (async () => {
      try {
        const { getPermissions } = useSystemSettingApi()
        const [res] = await Promise.all([getPermissions(), loadPermissions(force)])
        if (res?.isSuccess) {
          nodes.value = res.body ?? []
          status.value = 'loaded'
        } else {
          nodes.value = null
          status.value = 'failed'
        }
      } catch (err) {
        console.log('load navigation failed -->', err)
        nodes.value = null
        status.value = 'failed'
      } finally {
        pendingLoad = null
      }
      return nodes.value
    })()
    return pendingLoad
  }

  /** 還沒拿到結果（成功或失敗都算拿到）。側欄用來顯示載入中的佔位。 */
  const isLoadingUserFunctions = computed(() => status.value === 'idle' || status.value === 'loading')

  /** 某個節點目前這個人看不看得到。權限沒載到時一律放行，由後端把關。 */
  const canAccess = (permissionKey: string) => permissionFailed.value || can(permissionKey)

  /** 未過濾的完整功能表。模組是否存在、麵包屑用，不受權限影響。 */
  const allModules = computed(() => toModules(nodes.value ?? []))

  /** 側欄與首頁卡片用：只留看得到的頁面，空的分組與模組拿掉。載入中回空陣列。 */
  const modules = computed<AppNavModule[]>(() => {
    if (isLoadingUserFunctions.value) return []
    return allModules.value
      .map(mod => ({
        ...mod,
        groups: mod.groups
          .map(group => ({ ...group, items: group.items.filter(item => canAccess(item.permissionKey)) }))
          .filter(group => group.items.length > 0)
      }))
      .filter(mod => mod.groups.length > 0)
  })

  /**
   * 已經載完、而且這個人連一個功能都沒有（或功能表本身載入失敗）。
   * 用來顯示「沒有可用功能」的提示，跟「還沒載完」要分得開。
   */
  const hasNoAccessibleModule = computed(() => !isLoadingUserFunctions.value && modules.value.length === 0)

  /** 模組的完整路徑。 */
  const modulePath = (mod: AppNavModule) => appPath(mod.path)

  /** 功能的完整路徑。 */
  const itemPath = (item: AppNavItem) => appPath(item.path)

  /**
   * 用完整路徑反查所屬模組／群組，麵包屑用。
   * 子路由（例如 /sales-center/sales-issue/issues/000062）請傳父層路徑。
   */
  const findItemByPath = (path: string) => {
    for (const mod of allModules.value) {
      for (const group of mod.groups) {
        const item = group.items.find(i => itemPath(i) === path)
        if (item) return { module: mod, group, item }
      }
    }
    return null
  }

  /** 用模組代號（網址第 2 段）反查模組（已依權限過濾），模組首頁用。 */
  const findModuleBySlug = (slug: string) =>
    modules.value.find(mod => mod.path === slug) ?? null

  /** 模組底下的功能總數，卡片上顯示用。 */
  const countItems = (mod: AppNavModule) =>
    mod.groups.reduce((n, g) => n + g.items.length, 0)

  /** 麵包屑的第一層，固定是業務中心。 */
  const rootCrumb = () => ({ label: APP_BASE_LABEL, to: APP_BASE, icon: 'i-lucide-house' })

  /**
   * 功能頁的麵包屑：業務中心 / 模組 / 功能 [/ extra]。
   * 模組那一層會連到模組首頁，可以往回退一層。
   * extra 用來接「議題編號」這種動態層級。
   */
  const breadcrumbFor = (path: string, extra?: string) => {
    const items: { label: string, to?: string, icon?: string }[] = [rootCrumb()]
    const found = findItemByPath(path)
    if (found) {
      items.push({ label: found.module.label, to: modulePath(found.module), icon: found.module.icon })
      items.push({ label: found.item.label, to: extra ? path : undefined })
    }
    if (extra) items.push({ label: extra })
    return items
  }

  /** 模組首頁的麵包屑：業務中心 / 模組。 */
  const breadcrumbForModule = (mod: AppNavModule) => [
    rootCrumb(),
    { label: mod.label, icon: mod.icon }
  ]

  return {
    appBase: APP_BASE,
    appBaseLabel: APP_BASE_LABEL,
    modules,
    allModules,
    loadUserFunctions,
    isLoadingUserFunctions,
    hasNoAccessibleModule,
    canAccess,
    modulePath,
    itemPath,
    appPath,
    countItems,
    findItemByPath,
    findModuleBySlug,
    breadcrumbFor,
    breadcrumbForModule
  }
}
