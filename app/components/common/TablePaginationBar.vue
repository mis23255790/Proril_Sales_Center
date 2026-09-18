<script setup lang="ts">
/**
 * `total` 是給後端分頁的頁面用的：資料已經是「切好的那一頁」，
 * `getFilteredRowModel().rows.length` 只會是當頁筆數，不是總筆數，要外部傳真正的總數進來。
 * 純前端分頁（不傳 total）維持原本行為，用 row model 自己的筆數。
 */
const props = defineProps<{
  table: any
  total?: number
}>()

const totalCount = computed(() => props.total ?? (props.table?.tableApi?.getFilteredRowModel().rows.length ?? 0))

const pageSize = computed({
  get: () => props.table?.tableApi?.getState().pagination.pageSize ?? 20,
  set: (v: number) => props.table?.tableApi?.setPageSize(v)
})
</script>

<template>
  <div v-if="totalCount > 0" class="flex flex-wrap items-center justify-between gap-3 border-t border-default px-4 py-3">
    <p class="text-sm text-muted">
      總共 {{ totalCount }} 筆資料
    </p>
    <div class="flex items-center gap-3">
      <USelect
        v-model="pageSize"
        :items="PAGE_SIZE_OPTIONS"
        value-key="value"
        label-key="label"
        size="sm"
        class="w-28"
      />
      <UPagination
        :page="(table?.tableApi?.getState().pagination.pageIndex || 0) + 1"
        :items-per-page="table?.tableApi?.getState().pagination.pageSize"
        :total="totalCount"
        @update:page="(p: number) => table?.tableApi?.setPageIndex(p - 1)"
      />
    </div>
  </div>
</template>
