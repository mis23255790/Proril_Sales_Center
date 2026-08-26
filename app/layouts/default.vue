<script setup lang="ts">
import type { NavigationMenuItem } from '@nuxt/ui'

const route = useRoute()
const { modules } = useAppNavigation()

const collapsed = ref(false)

const activeModuleSlug = computed(() => route.path.split('/')[1] || '')

const items = computed<NavigationMenuItem[][]>(() => [
  [
    { label: '現場作業', type: 'label' as const },
    ...modules.map(mod => ({
      label: mod.label,
      icon: mod.icon,
      defaultOpen: route.path.startsWith(mod.to),
      children: mod.groups.map(group => ({
        label: group.groupName,
        defaultOpen: group.items.some(item => item.to === route.path),
        children: group.items.map(item => ({ label: item.label, to: item.to }))
      }))
    }))
  ]
])
</script>

<template>
  <UDashboardGroup storage="local" storage-key="proril-dashboard">
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
        <UDashboardNavbar title="PRORIL 製造中心" :ui="{ root: 'bg-white dark:bg-white' }">
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
