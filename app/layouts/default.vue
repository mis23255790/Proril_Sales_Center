<script setup lang="ts">
import type { DropdownMenuItem, NavigationMenuItem } from '@nuxt/ui'

const route = useRoute()
const { public: { appVersion } } = useRuntimeConfig()
const { sidebarModules, modulePath, itemPath, appBaseLabel, loadUserFunctions, isLoadingUserFunctions, hasNoAccessibleModule, findItemByPath, findModuleBySlug } = useAppNavigation()
const { account } = useAuthAccount()
const { getCurrentUser } = useCurrentUser()
const { getSystemByNo } = useSystemInfo()

const collapsed = ref(false)

const logout = async () => {
  await logoutAuth()
  // 帶 logged_out，登入頁才不會自動導去通行證又立刻登回來（見 pages/login.vue）
  navigateTo('/login?logged_out=1')
}

const userMenuItems = computed<DropdownMenuItem[][]>(() => [
  [{ label: '登出', icon: 'i-lucide-log-out', onSelect: logout }]
])

/**
 * 側欄整棵樹從 DB 來（RBAC_Permission），再依目前登入者的角色權限過濾，
 * 在這裡載一次，之後整個站共用（見 useAppNavigation.loadUserFunctions）。
 */
onMounted(() => {
  loadUserFunctions()
})

/** 姓名不在 JWT 裡，要另外查；查不到就退回顯示帳號，不要整塊空著。 */
const userName = ref('')
onMounted(async () => {
  try {
    const res = await getCurrentUser()
    userName.value = res?.body?.username || ''
  } catch (err) {
    console.log('load current user failed -->', err)
  }
})

/**
 * 正式區/測試區環境圖示，沿用 1.0 _AuthLayout：圖檔路徑本身就是環境差異。
 *
 * ImagePath 是 1.0 站台根目錄下的相對路徑（例如 /images/ic_mission.png）。
 * 不能直接拼 config.public.apiBase 當 origin：這個值是給 server/api/proxy 在
 * server 端打的，部署上常是 docker 內部服務名稱（例如 web-server），瀏覽器解析不到。
 * 一律走同源的 /api/proxy/** 轉發（跟其他 API 呼叫同一條路），由 Nuxt server 代打。
 */
const systemImagePath = ref<string | null>(null)
const systemImageUrl = computed(() => {
  if (!systemImagePath.value) return null
  return `/api/proxy${systemImagePath.value}`
})
onMounted(async () => {
  try {
    const res = await getSystemByNo(ENV_ICON_SYSTEM_NO)
    systemImagePath.value = res?.body?.[0]?.imagePath || null
  } catch (err) {
    console.log('load system image failed -->', err)
  }
})

// 路徑是 /sales-center/<模組>/<功能>，模組代號在第 2 段
// （split('/') 之後 [0] 是空字串、[1] 是 sales-center）
const activeModuleSlug = computed(() => route.path.split('/')[2] || '')

/**
 * defaultOpen 只在 UNavigationMenu 建立時套用一次；權限清單（sidebarModules）是之後才非同步載入的，
 * 不重建的話後來才出現的模組會是收合的。用模組清單當 key，清單變了就重建。
 */
const menuKey = computed(() => sidebarModules.value.map(m => m.path).join('|'))

/**
 * 頂部導覽列顯示目前頁面名稱（各頁不再自己放大標題）：
 * usePageHeading 覆寫 → definePageMeta 的 title → 權限樹對應的功能名稱 → 模組首頁的模組名稱 → 預設。
 */
const pageHeading = useState<string>('pageHeading', () => '')
const navbarTitle = computed(() => {
  if (pageHeading.value) return pageHeading.value
  if (typeof route.meta.title === 'string' && route.meta.title) return route.meta.title
  const found = findItemByPath(route.path)
  if (found) return found.item.label
  // 模組首頁：/sales-center/<模組>
  if (route.path.split('/').filter(Boolean).length === 2) {
    const mod = findModuleBySlug(activeModuleSlug.value)
    if (mod) return mod.label
  }
  return 'PRORIL 業務中心'
})

/**
 * 側欄列出全部功能，沒權限的頁面 disable（不隱藏），讓使用者知道有這個功能、只是還沒開通。
 * 只 disable 頁面這一層：NavigationMenu 在 vertical 模式會把 disabled 的節點連同展開一起鎖住，
 * 模組／分組若 disable 就看不到底下的頁面了。模組底下一個能進的頁面都沒有時拿掉連結，
 * 點模組名稱只展開、不進模組首頁（那頁依權限過濾後會是空的）。
 * 模組與分組一律預設展開（2026-10-06 起），不再只展開目前所在的模組。
 * 系統管理模組沒有任何權限時整個不顯示（2026-10-07 起，見 useAppNavigation 的 HIDDEN_WHEN_NO_ACCESS_MODULES）。
 */
const items = computed<NavigationMenuItem[][]>(() => [
  [
    { label: appBaseLabel, type: 'label' as const },
    ...sidebarModules.value.map(mod => ({
      label: mod.label,
      icon: mod.icon,
      // 點模組名稱進模組首頁（跟首頁卡片同一個目的地），展開則看得到底下的功能
      to: mod.accessible ? modulePath(mod) : undefined,
      defaultOpen: true,
      children: mod.groups.map(group => ({
        label: group.groupName,
        defaultOpen: true,
        children: group.items.map(item => item.accessible
          ? { label: item.label, to: itemPath(item) }
          : { label: item.label, disabled: true, trailingIcon: 'i-lucide-lock' })
      }))
    }))
  ]
])
</script>

<template>
  <UDashboardGroup storage="local" storage-key="proril-sales-dashboard">
    <UDashboardSidebar
      v-model:collapsed="collapsed"
      collapsible
      resizable
      :min-size="16"
      :max-size="26"
      :default-size="18"
      :collapsed-size="4"
      :ui="{ header: 'h-10 px-2' }"
    >
      <template #header="{ collapsed: isCollapsed }">
        <!-- header 跟右側 UDashboardNavbar 同高（h-10），LOGO 在這裡縮成 h-8；登入頁的 AppLogo 不受影響 -->
        <div class="flex w-full justify-center [&_img]:h-8 [&_img]:w-auto">
          <AppLogo :collapsed="isCollapsed" />
        </div>
      </template>

      <template #default="{ collapsed: isCollapsed }">
        <UNavigationMenu
          :key="menuKey"
          :collapsed="isCollapsed"
          :items="items"
          orientation="vertical"
          class="-mx-1"
          :ui="{ link: 'cursor-pointer aria-disabled:cursor-not-allowed aria-disabled:opacity-50', childLink: 'cursor-pointer' }"
        />

        <!-- 權限清單回來之前先放佔位，不先列出全部功能（否則沒權限的項目會閃一下再消失） -->
        <div v-if="isLoadingUserFunctions" class="space-y-2 px-1">
          <USkeleton v-for="n in 3" :key="n" class="h-8 w-full" />
        </div>

        <!--
          一個功能都沒有時要講話，不能只是空白一片：
          使用者分不出「沒權限」跟「系統壞了」，而這條路徑後端是回成功的，
          不會有任何 toast 或 console error 可以看。
        -->
        <p
          v-if="hasNoAccessibleModule && !isCollapsed"
          class="px-2 py-3 text-xs leading-relaxed text-muted"
        >
          目前沒有任何可用功能，請洽系統管理員開通權限。
        </p>
      </template>

      <!-- 收合時寬度不夠，只留版本號 -->
      <template #footer="{ collapsed: isCollapsed }">
        <div class="w-full text-center text-xs leading-relaxed text-muted">
          <template v-if="isCollapsed">
            v{{ appVersion }}
          </template>
          <template v-else>
            © {{ new Date().getFullYear() }} PRORIL 業務中心<br>v{{ appVersion }}
          </template>
        </div>
      </template>
    </UDashboardSidebar>

    <UDashboardPanel :ui="{ body: 'bg-white dark:bg-white min-h-0 p-3 sm:p-3' }">
      <template #header>
        <UDashboardNavbar :title="navbarTitle" :ui="{ root: 'h-10 px-3 sm:px-3 bg-white dark:bg-white' }">
          <template #leading>
            <UDashboardSidebarCollapse />
          </template>

          <template #right>
            <div class="flex items-center gap-2">
              <img
                v-if="systemImageUrl"
                :src="systemImageUrl"
                width="24"
                height="24"
                class="opacity-50"
                alt=""
              >
              <UColorModeButton v-if="false" />
              <UDropdownMenu v-if="userName || account" :items="userMenuItems">
                <UButton
                  color="neutral"
                  variant="ghost"
                  size="sm"
                  trailing-icon="i-lucide-chevron-down"
                  class="text-sm text-gray-600 dark:text-gray-300"
                >
                  {{ userName || account }}
                </UButton>
              </UDropdownMenu>
            </div>
          </template>
        </UDashboardNavbar>
      </template>

      <template #body>
        <slot />
      </template>
    </UDashboardPanel>
  </UDashboardGroup>
</template>
