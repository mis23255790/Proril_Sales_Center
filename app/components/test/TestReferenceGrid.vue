<script setup lang="ts">
import type { ProductDetailRow } from '~/types/test'

defineProps<{
  rows: ProductDetailRow[]
}>()
</script>

<template>
  <table class="w-full text-sm">
    <thead>
      <tr class="border-b border-default text-left text-xs text-muted">
        <th class="py-1.5 pr-2 font-medium">
          項目
        </th>
        <th class="py-1.5 px-2 font-medium">
          公制
        </th>
        <th class="py-1.5 px-2 font-medium">
          英制
        </th>
        <th class="py-1.5 pl-2 font-medium">
          允收標準
        </th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="row in rows" :key="row.title" class="border-b border-default last:border-0">
        <td class="py-1.5 pr-2 text-highlighted">
          {{ row.title }}
        </td>
        <td class="py-1.5 px-2 text-muted">
          {{ row.metric }}
        </td>
        <td class="py-1.5 px-2 text-muted">
          {{ row.imperial }}
        </td>
        <td class="py-1.5 pl-2 font-medium text-highlighted">
          {{ row.standard }}
        </td>
      </tr>
    </tbody>
  </table>
</template>
