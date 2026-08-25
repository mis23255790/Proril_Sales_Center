<script setup lang="ts">
import { getPaginationRowModel } from '@tanstack/vue-table'
import type { TableColumn } from '@nuxt/ui'
import type { ProductListItem, ProductDetailViewModel, DTestStandard, ApiResponse } from '~/types/test'

const { apiFetch } = useApi()
const toast = useToast()
const { testTypeOptions } = useTestEnums()
const { pagination } = useTablePagination()
const table = useTemplateRef('table')

const loading = ref(false)
const importing = ref(false)
const products = ref<ProductListItem[]>([])
const search = ref('')

const fetchProducts = async () => {
  loading.value = true
  try {
    const res = await apiFetch<ApiResponse<ProductListItem[]>>('/ProductApi/GetProductList')
    products.value = res?.body ?? []
  } catch {
    products.value = []
  } finally {
    loading.value = false
  }
}

onMounted(fetchProducts)

const filtered = computed(() => {
  if (!search.value) return products.value
  const kw = search.value.toLowerCase()
  return products.value.filter(p =>
    p.productNo?.toLowerCase().includes(kw) || p.productName?.toLowerCase().includes(kw)
  )
})

watch(search, () => { pagination.value.pageIndex = 0 })

const testTypeLabel = (v?: number) => testTypeOptions.find(o => o.value === v)?.label ?? '-'

const runImport = async () => {
  importing.value = true
  try {
    await apiFetch<boolean>('/ErpImportApi/SP_ImportProduct')
    toast.add({ title: 'ERP 品號資料匯入完成', color: 'success' })
    await fetchProducts()
  } finally {
    importing.value = false
  }
}

const detailOpen = ref(false)
const detailLoading = ref(false)
const selected = ref<ProductListItem | null>(null)
const detail = ref<ProductDetailViewModel | null>(null)

const openDetail = async (row: ProductListItem) => {
  selected.value = row
  detailOpen.value = true
  detail.value = null
  if (!row.testNo) return
  detailLoading.value = true
  try {
    detail.value = await apiFetch<ProductDetailViewModel>('/TestApi/GetProductStandard', { params: { productNo: row.productNo } })
  } finally {
    detailLoading.value = false
  }
}

const bindOpen = ref(false)
const bindTarget = ref<ProductListItem | null>(null)
const bindSearchName = ref('')
const bindSearching = ref(false)
const bindBinding = ref(false)
const bindFound = ref<DTestStandard | null>(null)

const openBind = (row: ProductListItem) => {
  bindTarget.value = row
  bindSearchName.value = ''
  bindFound.value = null
  bindOpen.value = true
}

const searchStandard = async () => {
  if (!bindSearchName.value.trim()) return
  bindSearching.value = true
  bindFound.value = null
  try {
    const res = await apiFetch<ApiResponse<DTestStandard>>('/TestApi/GetTestPlan', {
      params: { input: bindSearchName.value.trim(), test_rule: '' }
    })
    if (res?.isSuccess && res.body?.testNo) {
      bindFound.value = res.body
    } else {
      toast.add({ title: '查無此測試標準', description: '請確認名稱完全正確', color: 'warning' })
    }
  } finally {
    bindSearching.value = false
  }
}

const confirmBind = async () => {
  if (!bindTarget.value || !bindFound.value) return
  bindBinding.value = true
  try {
    const res = await apiFetch<ApiResponse<any>>('/TestApi/CombineTestPlan', {
      params: { productNo: bindTarget.value.productNo, testNo: bindFound.value.testNo }
    })
    if (res?.isSuccess) {
      toast.add({ title: '測試標準綁定成功', color: 'success' })
      bindOpen.value = false
      await fetchProducts()
    } else {
      toast.add({ title: '綁定失敗', description: res?.message ?? '', color: 'error' })
    }
  } finally {
    bindBinding.value = false
  }
}

const columns: TableColumn<ProductListItem>[] = [
  { accessorKey: 'productNo', header: '品號' },
  { accessorKey: 'productName', header: '品名' },
  { accessorKey: 'specification', header: '規格' },
  { accessorKey: 'testName', header: '測試標準' }
]
</script>

<template>
  <div>
    <FullPageLoading :show="loading" />

    <UBreadcrumb :items="[{ label: '首頁', to: '/', icon: 'i-lucide-house' }, { label: '測試系統', icon: 'i-lucide-flask-conical' }, { label: '資料管理' }, { label: '產品資料維護' }]" class="mb-4" />

    <h1 class="mb-4 text-2xl font-bold text-highlighted">
      產品資料維護
    </h1>

    <div class="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center">
      <UInput v-model="search" icon="i-lucide-search" placeholder="搜尋品號/品名..." class="w-56" />
      <UButton icon="i-lucide-refresh-cw" color="neutral" variant="outline" :loading="importing" class="sm:ml-auto" @click="runImport">
        手動匯入 ERP 品號
      </UButton>
    </div>

    <div class="overflow-hidden rounded-lg border border-default">
      <UTable
        ref="table"
        v-model:pagination="pagination"
        :pagination-options="{ getPaginationRowModel: getPaginationRowModel() }"
        :data="filtered"
        :columns="columns"
        :loading="loading"
        :ui="{ tr: 'cursor-pointer' }"
        @select="(_e: Event, row: any) => openDetail(row.original)"
      >
        <template #testName-cell="{ row }">
          <span v-if="row.original.testName">{{ row.original.testName }}<span class="ml-1 text-xs text-muted">({{ testTypeLabel(row.original.testType) }})</span></span>
          <UBadge v-else color="warning" variant="subtle">
            尚未設定
          </UBadge>
        </template>
      </UTable>
      <TablePaginationBar :table="table" />
    </div>

    <USlideover v-model:open="detailOpen" title="產品詳細資料" :description="selected?.productNo">
      <template #body>
        <div v-if="selected" class="space-y-6">
          <div class="grid grid-cols-2 gap-4 sm:grid-cols-4">
            <UFormField label="品號"><UInput :model-value="selected.productNo" disabled /></UFormField>
            <UFormField label="機型"><UInput :model-value="selected.modelName" disabled /></UFormField>
            <UFormField label="相數"><UInput :model-value="selected.phase" disabled /></UFormField>
            <UFormField label="頻率"><UInput :model-value="selected.frequency" disabled /></UFormField>
            <UFormField label="電壓"><UInput :model-value="selected.voltage" disabled /></UFormField>
            <UFormField label="規格" class="col-span-2 sm:col-span-3"><UInput :model-value="selected.specification" disabled /></UFormField>
          </div>

          <USeparator />

          <div>
            <div class="mb-2 flex items-center justify-between">
              <h3 class="text-sm font-semibold text-highlighted">
                綁定測試標準
              </h3>
              <UButton size="xs" icon="i-lucide-link" @click="openBind(selected)">
                {{ selected.testName ? '變更' : '設定' }}測試標準
              </UButton>
            </div>
            <div v-if="detailLoading" class="text-sm text-muted">
              載入中...
            </div>
            <div v-else-if="!detail">
              <UAlert color="warning" variant="subtle" title="尚未設定測試標準" />
            </div>
            <TestReferenceGrid v-else :rows="detail.productDetail" />
          </div>

          <USeparator />

          <TestMemoPanel :link-type="3" :link-number="selected.productNo" />
        </div>
      </template>
    </USlideover>

    <UModal v-model:open="bindOpen" title="設定測試標準" :description="bindTarget?.productNo">
      <template #body>
        <div class="space-y-4">
          <UFormField label="測試標準名稱" description="請輸入完整且正確的測試標準名稱">
            <div class="flex gap-2">
              <UInput v-model="bindSearchName" class="flex-1" placeholder="例如: XXX-揚程水量測試" @keyup.enter="searchStandard" />
              <UButton icon="i-lucide-search" :loading="bindSearching" @click="searchStandard">
                查詢
              </UButton>
            </div>
          </UFormField>

          <div v-if="bindFound" class="rounded-lg border border-default p-3 text-sm">
            <p><span class="text-muted">名稱：</span>{{ bindFound.testName }}</p>
            <p><span class="text-muted">測試地點：</span>{{ bindFound.testPlace }}</p>
            <p><span class="text-muted">相數/頻率/電壓：</span>{{ bindFound.phase }} / {{ bindFound.frequency }} / {{ bindFound.voltage }}</p>
          </div>
        </div>
      </template>
      <template #footer>
        <UButton color="neutral" variant="outline" @click="bindOpen = false">
          取消
        </UButton>
        <UButton :disabled="!bindFound" :loading="bindBinding" @click="confirmBind">
          確認綁定
        </UButton>
      </template>
    </UModal>
  </div>
</template>
