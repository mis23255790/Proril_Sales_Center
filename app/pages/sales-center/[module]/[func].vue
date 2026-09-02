<script setup lang="ts">
/**
 * 佔位頁：功能表上有、但頁面還沒做的功能。
 * Nuxt 靜態路由優先於動態路由，所以已經有實作的功能不會落到這裡。
 */
const route = useRoute()
const { findItemByPath, appBase, appBaseLabel } = useAppNavigation()

const found = findItemByPath(route.path)

if (!found) {
  throw createError({ statusCode: 404, statusMessage: '找不到此功能頁面' })
}

const { module: mod, group, item } = found

const breadcrumbItems = [
  { label: appBaseLabel, to: appBase, icon: 'i-lucide-house' },
  { label: mod.label, icon: mod.icon },
  { label: group.groupName },
  { label: item.label }
]
</script>

<template>
  <div>
    <UBreadcrumb :items="breadcrumbItems" class="mb-4" />

    <h1 class="mb-6 text-2xl font-bold text-highlighted">
      {{ item.label }}
    </h1>

    <div class="flex flex-col items-center justify-center gap-3 rounded-lg border border-dashed border-default py-24 text-center">
      <UIcon name="i-lucide-hammer" class="size-8 text-muted" />
      <p class="font-medium text-highlighted">
        此功能頁面開發中
      </p>
      <p class="text-sm text-muted">
        {{ mod.label }} / {{ item.label }}
      </p>
    </div>
  </div>
</template>
