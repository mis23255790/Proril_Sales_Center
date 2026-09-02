<script setup lang="ts">
defineProps<{
  table: any
}>()
</script>

<template>
  <div v-if="(table?.tableApi?.getFilteredRowModel().rows.length ?? 0) > 0" class="flex items-center justify-between border-t border-default px-4 py-3">
    <p class="text-sm text-muted">
      總共 {{ table?.tableApi?.getFilteredRowModel().rows.length }} 筆資料
    </p>
    <UPagination
      :page="(table?.tableApi?.getState().pagination.pageIndex || 0) + 1"
      :items-per-page="table?.tableApi?.getState().pagination.pageSize"
      :total="table?.tableApi?.getFilteredRowModel().rows.length"
      @update:page="(p: number) => table?.tableApi?.setPageIndex(p - 1)"
    />
  </div>
</template>
