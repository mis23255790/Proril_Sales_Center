<script setup lang="ts">
/**
 * 模組首頁：列出這個模組底下的功能，依群組分段。
 *
 * 這是動態路由，所有模組共用一支 —— 新增模組只要在 useAppNavigation 的
 * NAV_MODULES 加一筆，不用再開一個頁面檔。
 * 若哪天某個模組要客製首頁（例如放儀表板），在
 * app/pages/sales-center/<模組>/index.vue 放一支靜態頁即可，
 * Nuxt 的靜態路由優先於動態路由，會自動蓋過這裡。
 */
const route = useRoute()
const { findModuleBySlug, allModules, itemPath, breadcrumbForModule } = useAppNavigation()

const slug = computed(() => String(route.params.module ?? ''))

// 模組存不存在看未過濾的完整表；權限過濾只影響「列出哪幾張卡片」，
// 不該讓一個真的存在的模組變成 404（權限清單是非同步載入的，會有先後順序）。
if (!allModules.some(m => m.path === slug.value)) {
  throw createError({ statusCode: 404, statusMessage: '找不到此模組' })
}

const mod = computed(() => findModuleBySlug(slug.value))

useSeoMeta({ title: `${mod.value?.label ?? ''} · PRORIL 業務中心` })
</script>

<template>
  <div v-if="mod">
    <UBreadcrumb :items="breadcrumbForModule(mod)" class="mb-4" />

    <div class="mb-6">
      <h1 class="flex items-center gap-2 text-2xl font-bold text-highlighted">
        <UIcon :name="mod.icon" class="size-6 text-primary" />
        {{ mod.label }}
      </h1>
      <p class="mt-1 text-sm text-muted">
        選擇要執行的作業。
      </p>
    </div>

    <div v-for="group in mod.groups" :key="group.groupName" class="mb-6">
      <h2 class="mb-3 text-sm font-semibold text-muted">
        {{ group.groupName }}
      </h2>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
        <NavCard
          v-for="item in group.items"
          :key="item.path"
          :to="itemPath(item)"
          :icon="item.icon || mod.icon"
          :title="item.label"
          :description="item.description"
        />
      </div>
    </div>
  </div>
</template>
