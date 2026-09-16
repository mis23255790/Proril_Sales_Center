<script setup lang="ts">
import type { DropdownMenuItem, NavigationMenuItem } from '@nuxt/ui'

const route = useRoute()
const { modules, modulePath, itemPath, appBaseLabel, loadUserFunctions, hasNoAccessibleModule } = useAppNavigation()
const { account } = useAuthAccount()
const { getCurrentUser } = useCurrentUser()
const { getSystemByNo } = useSystemInfo()

const collapsed = ref(false)

const logout = () => {
  clearAuthToken()
  navigateTo('/login')
}

const userMenuItems = computed<DropdownMenuItem[][]>(() => [
  [{ label: '登出', icon: 'i-lucide-log-out', onSelect: logout }]
])

/**
 * 側欄要顯示哪些功能是 DB 說了算（M_Function ∩ M_Permission），
 * 在這裡載一次，之後整個站共用（見 useAppNavigation.loadUserFunctions）。
 */
onMounted(() => { loadUserFunctions() })

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
    const res = await getSystemByNo(WORK_PROCESS_SYSTEM_NO)
    systemImagePath.value = res?.body?.[0]?.imagePath || null
  } catch (err) {
    console.log('load system image failed -->', err)
  }
})

// 路徑是 /sales-center/<模組>/<功能>，模組代號在第 2 段
// （split('/') 之後 [0] 是空字串、[1] 是 sales-center）
const activeModuleSlug = computed(() => route.path.split('/')[2] || '')

const items = computed<NavigationMenuItem[][]>(() => [
  [
    { label: appBaseLabel, type: 'label' as const },
    ...modules.value.map(mod => ({
      label: mod.label,
      icon: mod.icon,
      // 點模組名稱進模組首頁（跟首頁卡片同一個目的地），展開則看得到底下的功能
      to: modulePath(mod),
      defaultOpen: route.path.startsWith(modulePath(mod)),
      children: mod.groups.map(group => ({
        label: group.groupName,
        defaultOpen: group.items.some(item => itemPath(item) === route.path),
        children: group.items.map(item => ({ label: item.label, to: itemPath(item) }))
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
    >
      <template #header="{ collapsed: isCollapsed }">
        <AppLogo :collapsed="isCollapsed" />
      </template>

      <template #default="{ collapsed: isCollapsed }">
        <UNavigationMenu
          :key="activeModuleSlug"
          :collapsed="isCollapsed"
          :items="items"
          orientation="vertical"
          class="-mx-1"
          :ui="{ link: 'cursor-pointer', childLink: 'cursor-pointer' }"
        />

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
    </UDashboardSidebar>

    <UDashboardPanel :ui="{ body: 'bg-white dark:bg-white min-h-0 p-4 sm:p-4' }">
      <template #header>
        <UDashboardNavbar title="PRORIL 業務中心" :ui="{ root: 'h-12 bg-white dark:bg-white' }">
          <template #leading>
            <UDashboardSidebarCollapse />
          </template>

          <template #right>
            <div class="flex items-center gap-3">
              <img
                v-if="systemImageUrl"
                :src="systemImageUrl"
                width="30"
                height="30"
                class="opacity-50"
                alt=""
              >
              <UColorModeButton />
              <UDropdownMenu v-if="userName || account" :items="userMenuItems">
                <UButton
                  color="neutral"
                  variant="ghost"
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
