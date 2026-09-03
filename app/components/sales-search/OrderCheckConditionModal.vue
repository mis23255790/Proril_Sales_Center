<script setup lang="ts">
/**
 * 「檢核條件」說明 modal：COP_CheckRule 清單的唯讀表格，沒有互動。
 */
import type { TableColumn } from '@nuxt/ui'
import type { CopCheckRule } from '~/types/orderInfoVerify'

defineProps<{
  loading: boolean
  rows: CopCheckRule[]
}>()

const open = defineModel<boolean>('open', { default: false })

const columns: TableColumn<CopCheckRule>[] = [
  { accessorKey: 'recType', header: '檢核種類' },
  { accessorKey: 'erpfield', header: '檢核欄位' },
  { accessorKey: 'chkRule', header: '檢核規則' }
]
</script>

<template>
  <UModal v-model:open="open" title="檢核條件" :ui="{ content: 'max-w-3xl' }">
    <template #body>
      <div class="overflow-x-auto rounded-lg border border-default">
        <UTable :data="rows" :columns="columns" :loading="loading" :ui="{ td: 'whitespace-nowrap' }">
          <template #empty>
            <p class="py-8 text-center text-sm text-muted">
              查無檢核條件資料
            </p>
          </template>
        </UTable>
      </div>
    </template>

    <template #footer>
      <div class="flex w-full justify-end">
        <UButton color="neutral" variant="outline" @click="open = false">
          關閉
        </UButton>
      </div>
    </template>
  </UModal>
</template>
