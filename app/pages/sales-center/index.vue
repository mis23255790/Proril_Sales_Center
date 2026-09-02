<script setup lang="ts">
/**
 * 業務中心首頁：只列**模組**，比照 1.0 的層級逐層下鑽。
 * 點模組才會看到它底下的功能（app/pages/sales-center/[module]/index.vue）。
 */
const { modules, modulePath, countItems } = useAppNavigation()

useSeoMeta({ title: 'PRORIL 業務中心' })
</script>

<template>
  <div>
    <div class="mb-6">
      <h1 class="text-2xl font-bold text-highlighted">
        業務中心
      </h1>
      <p class="mt-1 text-sm text-muted">
        選擇要進入的系統。
      </p>
    </div>

    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
      <NavCard
        v-for="mod in modules"
        :key="mod.path"
        :to="modulePath(mod)"
        :icon="mod.icon"
        :title="mod.label"
        :subtitle="`${mod.labelEn} · ${countItems(mod)} 項功能`"
      />
    </div>
  </div>
</template>
