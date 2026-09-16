import type { UserFunction } from '~/types/system'

export type AppNavItem = {
  label: string
  /** 相對於 APP_BASE 的路徑，例如 'sales-issue/issues'。用 itemPath() 取完整路徑。 */
  path: string
  icon?: string
  description?: string
  /** M_Function.FunctionNo（AAABBCC 格式），側欄靠它對 M_Permission 過濾。 */
  functionNo: string
}

export type AppNavModule = {
  label: string
  labelEn: string
  icon: string
  /** 相對於 APP_BASE 的模組路徑，例如 'sales-issue'。 */
  path: string
  enabled: boolean
  /** M_System.SystemNo。目前只用來對照 1.0 的系統別，沒有拿來過濾。 */
  systemNo: number
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
 * **這張表管的是「2.0 有哪些頁面」——路徑、icon、分組與說明文字。
 * 「這個人看得到哪些」則是 DB 說了算**：側欄會打 `MainApi/GetUserFunctions`
 * （M_Function ∩ M_Permission，admin 全開），只留下有權限的 functionNo，
 * 並用 DB 的 FunctionName 蓋掉這裡的 label（權限管理改了名稱，側欄要跟著改）。
 *
 * 為什麼不乾脆整棵樹都從 DB 長：M_Function.Href 存的是 1.0 的網址，
 * 跟 2.0 的路由對不起來；而且 DB 裡有一大票 2.0 還沒搬的功能，
 * 照單全收會出現一堆點下去 404 的項目。所以路由留在這裡、可見性交給 DB。
 *
 * `enabled: false` 的模組不會出現在側欄，用來佔位標示「已規劃、還沒搬過來」。
 * `path` 一律**不含** APP_BASE，統一由 modulePath() / itemPath() 補上，
 * 這樣以後要換根路徑只要改一個地方。
 *
 * functionNo 是 AAABBCC 格式（SystemNo 3 碼 + GroupNo 2 碼 + 序號 2 碼），
 * 後端同一份常數在 api/Models/Enums.cs 的 FunctionIds，
 * 改號的來龍去脈見 database/FunctionNoFormatMigration.sql。
 */
const NAV_MODULES: AppNavModule[] = [
  {
    label: '業務議題',
    labelEn: 'Sales Issue',
    icon: 'i-lucide-messages-square',
    path: 'sales-issue',
    enabled: true,
    systemNo: 7,
    groups: [
      {
        groupName: '議題管理',
        items: [
          {
            label: '議題維護',
            path: 'sales-issue/issues',
            icon: 'i-lucide-clipboard-list',
            description: '依客戶別追蹤議題進度、附件與結案狀態',
            functionNo: '0070102'
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
            description: '維護議題的類別與職能主題關鍵字',
            functionNo: '0070101'
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
    systemNo: 32,
    groups: [
      {
        groupName: '客戶',
        items: [
          {
            label: '客戶檢索',
            path: 'sales-search/customer',
            icon: 'i-lucide-users',
            description: '查詢內網／ERP客戶，新增或編輯內網客戶資料與 ERP 對應',
            functionNo: '0320103'
          }
        ]
      },
      {
        groupName: '銷貨',
        items: [
          {
            label: '銷貨檢索',
            path: 'sales-search/shipping-inquiry',
            icon: 'i-lucide-truck',
            description: '依客戶別、期間、品號查詢銷貨單，含品號/銷貨單細項與統計',
            functionNo: '0320101'
          }
        ]
      },
      {
        groupName: '訂單',
        items: [
          {
            label: '未完成訂單檢索',
            path: 'sales-search/unfinished-orders',
            icon: 'i-lucide-package-search',
            description: '依客戶別、訂單日期、預交日期、品號查詢尚未出貨的訂單，含品號/訂單細項與統計',
            functionNo: '0320102'
          },
          {
            label: '訂單資料檢核',
            path: 'sales-search/order-info-verify',
            icon: 'i-lucide-shield-check',
            description: '對訂單金額、信用額度等項目執行檢核，支援特規覆核與 Excel 匯出',
            functionNo: '0320201'
          }
        ]
      }
    ]
  },
  {
    label: '系統管理',
    labelEn: 'System',
    icon: 'i-lucide-settings',
    path: 'system',
    enabled: true,
    systemNo: 0,
    groups: [
      {
        groupName: '權限控管',
        items: [
          {
            label: '人員管理',
            path: 'system/user-manager',
            icon: 'i-lucide-user-cog',
            description: '新增／停用帳號、設定管理員、重置密碼與解除鎖定',
            functionNo: '0000102'
          },
          {
            label: '權限管理',
            path: 'system/permission-manager',
            icon: 'i-lucide-shield-check',
            description: '逐人設定可用功能與細項權限，可套用或維護群組預設功能',
            functionNo: '0000101'
          }
        ]
      }
    ]
  }
]

/** 把相對路徑接上 APP_BASE。傳空字串就是業務中心首頁。 */
export const appPath = (relative = '') =>
  relative ? `${APP_BASE}/${relative.replace(/^\/+/, '')}` : APP_BASE

/**
 * 登入者可用功能的快取。
 *
 * 用 useState 而不是各自 ref：側欄、首頁卡片、模組首頁都要用同一份，
 * 一個頁面切到另一個頁面時不該重打。default.vue 在 onMounted 呼叫 loadUserFunctions()。
 */
const useUserFunctionState = () => useState<UserFunction[] | null>('app-user-functions', () => null)

export const useAppNavigation = () => {
  const userFunctions = useUserFunctionState()

  /**
   * 載入可用功能。沒載到（API 掛了、token 過期）就保持 null，
   * 側欄退回顯示全部項目——寧可多顯示，也不要讓人一進站看到空選單以為系統壞了。
   * 真正的把關在後端，每支 API 自己會擋。
   *
   * **「成功但回空陣列」不走這條 fallback**：那是「這個人一個功能權限都沒有」，
   * 語意上跟「拿不到清單」不同，所以照樣過濾成空。但空選單一定要有畫面說明
   * （見 hasNoAccessibleModule 與 sales-center/index.vue 的提示），
   * 否則使用者只會看到一片空白、也沒有任何錯誤訊息，完全無從判斷發生什麼事——
   * 實際踩過：新庫的 M_User/M_Permission 沒灌資料，連 admin 都被當成沒權限。
   */
  const loadUserFunctions = async (force = false) => {
    if (userFunctions.value !== null && !force) return userFunctions.value
    try {
      const { getUserFunctions } = useSystemSettingApi()
      const res = await getUserFunctions()
      userFunctions.value = res?.isSuccess ? (res.body ?? []) : null
    } catch (err) {
      console.log('load user functions failed -->', err)
      userFunctions.value = null
    }
    return userFunctions.value
  }

  /** functionNo → DB 的功能名稱。 */
  const functionNameByNo = computed(() => {
    const map = new Map<string, string>()
    for (const fn of userFunctions.value ?? []) {
      if (fn.functionName) map.set(fn.functionNo, fn.functionName)
    }
    return map
  })

  /** 沒載到就不過濾（見 loadUserFunctions 的說明）。 */
  const allowedFunctionNos = computed(() => {
    if (userFunctions.value === null) return null
    return new Set(userFunctions.value.map(fn => fn.functionNo))
  })

  /** 未過濾的完整功能表。麵包屑／路徑反查用，不受權限影響。 */
  const allModules = NAV_MODULES.filter(mod => mod.enabled)

  /** 側欄與首頁卡片用：只留有權限的功能，名稱以 DB 為準。 */
  const modules = computed<AppNavModule[]>(() => {
    const allowed = allowedFunctionNos.value
    const names = functionNameByNo.value

    return allModules
      .map(mod => ({
        ...mod,
        groups: mod.groups
          .map(group => ({
            ...group,
            items: group.items
              .filter(item => !allowed || allowed.has(item.functionNo))
              .map(item => ({ ...item, label: names.get(item.functionNo) || item.label }))
          }))
          .filter(group => group.items.length > 0)
      }))
      .filter(mod => mod.groups.length > 0)
  })

  /**
   * 權限清單已經載到、而且這個人連一個 2.0 功能都沒有。
   * 用來顯示「沒有可用功能」的提示，跟「還沒載完」要分得開。
   */
  const hasNoAccessibleModule = computed(() =>
    allowedFunctionNos.value !== null && modules.value.length === 0)

  /** 某個功能目前這個人有沒有權限。沒載到權限清單時一律放行，由後端把關。 */
  const canAccess = (functionNo: string) => {
    const allowed = allowedFunctionNos.value
    return !allowed || allowed.has(functionNo)
  }

  /** 模組的完整路徑。 */
  const modulePath = (mod: AppNavModule) => appPath(mod.path)

  /** 功能的完整路徑。 */
  const itemPath = (item: AppNavItem) => appPath(item.path)

  /**
   * 用完整路徑反查所屬模組／群組，麵包屑用。
   * 子路由（例如 /sales-center/sales-issue/issues/000062）請傳父層路徑。
   */
  const findItemByPath = (path: string) => {
    for (const mod of allModules) {
      for (const group of mod.groups) {
        const item = group.items.find(i => itemPath(i) === path)
        if (item) return { module: mod, group, item }
      }
    }
    return null
  }

  /** 用模組代號（網址第 2 段）反查模組，模組首頁用。 */
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
