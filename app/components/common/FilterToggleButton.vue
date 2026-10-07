<script setup lang="ts">
/**
 * 查詢條件區塊的展開／收合按鈕，搭配 useFiltersOpen(pageKey) 使用：
 *   const filtersOpen = useFiltersOpen('shipping-inquiry')
 *   <FilterToggleButton v-model="filtersOpen" />
 *   <div v-show="filtersOpen" class="grid ...">（查詢欄位）</div>
 */
const open = defineModel<boolean>({ required: true })
</script>

<template>
  <UButton
    :icon="open ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
    color="neutral"
    variant="ghost"
    size="sm"
    :aria-expanded="open"
    @click="open = !open"
  >
    {{ open ? '收合條件' : '展開條件' }}
  </UButton>
</template>
