<script setup lang="ts">
import type { NavigationMenuItem } from '@nuxt/ui'

const route = useRoute()
const { modules, modulePath, itemPath, appBaseLabel } = useAppNavigation()

const collapsed = ref(false)

// 路徑是 /sales-center/<模組>/<功能>，模組代號在第 2 段
// （split('/') 之後 [0] 是空字串、[1] 是 sales-center）
const activeModuleSlug = computed(() => route.path.split('/')[2] || '')

const items = computed<NavigationMenuItem[][]>(() => [
  [
    { label: appBaseLabel, type: 'label' as const },
    ...modules.map(mod => ({
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
      :ui="{ footer: 'border-t border-default' }"
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
      </template>

      <template #footer="{ collapsed: isCollapsed }">
        <UButton
          icon="i-lucide-log-out"
          :label="isCollapsed ? undefined : '登出'"
          color="neutral"
          variant="ghost"
          block
        />
      </template>
    </UDashboardSidebar>

    <UDashboardPanel :ui="{ body: 'bg-white dark:bg-white' }">
      <template #header>
        <UDashboardNavbar title="PRORIL 業務中心" :ui="{ root: 'bg-white dark:bg-white' }">
          <template #leading>
            <UDashboardSidebarCollapse />
          </template>

          <template #right>
            <UColorModeButton />
          </template>
        </UDashboardNavbar>
      </template>

      <template #body>
        <slot />
      </template>
    </UDashboardPanel>
  </UDashboardGroup>
</template>
