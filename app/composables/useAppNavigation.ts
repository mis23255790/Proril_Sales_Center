export type AppNavItem = {
  label: string
  /** 相對於 APP_BASE 的路徑，例如 'sales-issue/issues'。用 itemPath() 取完整路徑。 */
  path: string
  icon?: string
  description?: string
}

export type AppNavModule = {
  label: string
  labelEn: string
  icon: string
  /** 相對於 APP_BASE 的模組路徑，例如 'sales-issue'。 */
  path: string
  enabled: boolean
  groups: {
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

/**
 * 業務中心的功能表。
 *
 * `enabled: false` 的模組不會出現在側欄，用來佔位標示「已規劃、還沒搬過來」。
 * `path` 一律**不含** APP_BASE，統一由 modulePath() / itemPath() 補上，
 * 這樣以後要換根路徑只要改一個地方。
 */
const NAV_MODULES: AppNavModule[] = [
  {
    label: '業務議題',
    labelEn: 'Sales Issue',
    icon: 'i-lucide-messages-square',
    path: 'sales-issue',
    enabled: true,
    groups: [
      {
        groupName: '議題管理',
        items: [
          {
            label: '議題維護',
            path: 'sales-issue/issues',
            icon: 'i-lucide-clipboard-list',
            description: '依客戶別追蹤議題進度、附件與結案狀態'
          }
        ]
      },
      {
        groupName: '基本資料',
        items: [
          {
            label: '類別維護',
            path: 'sales-issue/kind-maintain',
            icon: 'i-lucide-tags',
            description: '維護議題的類別與職能主題關鍵字'
          }
        ]
      }
    ]
  },
  {
    label: '業務檢索',
    labelEn: 'Sales Search',
    icon: 'i-lucide-search',
    path: 'sales-search',
    enabled: true,
    groups: [
      {
        groupName: '銷貨',
        items: [
          {
            label: '銷貨檢索',
            path: 'sales-search/shipping-inquiry',
            icon: 'i-lucide-truck',
            description: '依客戶別、期間、品號查詢銷貨單，含品號/銷貨單細項與統計'
          }
        ]
      }
    ]
  }
]

/** 把相對路徑接上 APP_BASE。傳空字串就是業務中心首頁。 */
export const appPath = (relative = '') =>
  relative ? `${APP_BASE}/${relative.replace(/^\/+/, '')}` : APP_BASE

export const useAppNavigation = () => {
  const enabledModules = NAV_MODULES.filter(mod => mod.enabled)

  /** 模組的完整路徑。 */
  const modulePath = (mod: AppNavModule) => appPath(mod.path)

  /** 功能的完整路徑。 */
  const itemPath = (item: AppNavItem) => appPath(item.path)

  /**
   * 用完整路徑反查所屬模組／群組，麵包屑用。
   * 子路由（例如 /sales-center/sales-issue/issues/000062）請傳父層路徑。
   */
  const findItemByPath = (path: string) => {
    for (const mod of enabledModules) {
      for (const group of mod.groups) {
        const item = group.items.find(i => itemPath(i) === path)
        if (item) return { module: mod, group, item }
      }
    }
    return null
  }

  /** 用模組代號（網址第 2 段）反查模組，模組首頁用。 */
  const findModuleBySlug = (slug: string) =>
    enabledModules.find(mod => mod.path === slug) ?? null

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
    modules: enabledModules,
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
