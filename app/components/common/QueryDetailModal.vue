<script setup lang="ts" generic="T extends Record<string, any>">
/**
 * 業務檢索類查詢頁的「單一XX明細」共用 modal。
 *
 * 對應舊畫面各自的 #modalProductDetail / #modalSoDetail，內容都是「表頭幾個
 * 唯讀欄位 + 總金額 + 一張細項表」，差別只在欄位定義，所以共用一個元件，
 * 欄位定義（fields / columns）交給呼叫端決定。泛型 T 是明細列的型別
 * （銷貨檢索用 CopSalesOrderRow、未完成訂單用 UnfinOrderRow…）。
 */
import type { TableColumn } from '@nuxt/ui'

defineProps<{
  title: string
  fields: { label: string, value: string }[]
  summaryAmount: number | null
  showAmount: boolean
  loading: boolean
  rows: T[]
  columns: TableColumn<T>[]
}>()

const open = defineModel<boolean>('open', { default: false })
</script>

<template>
  <UModal v-model:open="open" :title="title" :ui="{ content: 'max-w-6xl' }">
    <template #body>
      <div class="flex flex-col gap-4">
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <UFormField v-for="field in fields" :key="field.label" :label="field.label" size="sm">
            <UInput :model-value="field.value" readonly class="w-full" />
          </UFormField>
        </div>

        <div v-if="showAmount" class="rounded-lg border border-default bg-elevated/40 p-3">
          <p class="text-xs text-muted">
            總金額 NT
          </p>
          <p class="text-lg font-semibold text-highlighted">
            {{ formatAmount(summaryAmount) || '0' }}
          </p>
        </div>

        <div class="overflow-x-auto rounded-lg border border-default">
          <UTable :data="rows" :columns="columns" :loading="loading" :ui="{ td: 'whitespace-nowrap' }">
            <template #empty>
              <p class="py-8 text-center text-sm text-muted">
                查無明細資料
              </p>
            </template>
          </UTable>
        </div>
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
