<script setup lang="ts">
import { getPaginationRowModel } from '@tanstack/vue-table'
import type { TableColumn } from '@nuxt/ui'
import type { ApiResponse, FailedWoItem, ProductDetailViewModel, ProductByWoItem, HWorkOrder } from '~/types/test'

const { apiFetch } = useApi()
const toast = useToast()
const { pagination } = useTablePagination()
const table = useTemplateRef('table')

const loading = ref(false)
const list = ref<FailedWoItem[]>([])
const search = ref('')

const fetchList = async () => {
  loading.value = true
  try {
    const res = await apiFetch<ApiResponse<FailedWoItem[]>>('/WorkOrderApi/GetFailedWo')
    list.value = res?.body ?? []
  } catch {
    list.value = []
  } finally {
    loading.value = false
  }
}

onMounted(fetchList)

const filtered = computed(() => {
  if (!search.value) return list.value
  const kw = search.value.toLowerCase()
  return list.value.filter(row =>
    row.planNumber?.toLowerCase().includes(kw)
    || row.productNo?.toLowerCase().includes(kw)
    || row.modelName?.toLowerCase().includes(kw)
    || row.serialNo?.toLowerCase().includes(kw)
  )
})

watch(search, () => { pagination.value.pageIndex = 0 })

const detailOpen = ref(false)
const detailLoading = ref(false)
const selected = ref<FailedWoItem | null>(null)
const header = ref<ProductByWoItem | null>(null)
const reference = ref<ProductDetailViewModel | null>(null)
const actual = ref<HWorkOrder | null>(null)
const deciding = ref(false)

const openDetail = async (row: FailedWoItem) => {
  selected.value = row
  detailOpen.value = true
  detailLoading.value = true
  header.value = null
  reference.value = null
  actual.value = null
  try {
    const [headerRes, refRes, actualRes] = await Promise.all([
      apiFetch<ApiResponse<ProductByWoItem>>('/ProductApi/GetProductByWo', { params: { input: row.woNo } }),
      apiFetch<ProductDetailViewModel>('/WorkOrderApi/GetWoStandard', { params: { woNo: row.woNo } }),
      apiFetch<ApiResponse<HWorkOrder>>('/TestApi/GetTestHistoryByWo', { params: { input: row.woNo } })
    ])
    header.value = headerRes?.body ?? null
    reference.value = refRes
    actual.value = actualRes?.body ?? null
  } finally {
    detailLoading.value = false
  }
}

const decide = async (status: 2 | 3) => {
  if (!selected.value) return
  deciding.value = true
  try {
    const res = await apiFetch<ApiResponse<any>>('/WorkOrderApi/SetWoStatus', {
      params: { woNo: selected.value.woNo, woStatus: status }
    })
    if (res?.isSuccess !== false) {
      toast.add({ title: status === 3 ? '已標記為特採出貨' : '已送回重新測試', color: 'success' })
      detailOpen.value = false
      await fetchList()
    }
  } finally {
    deciding.value = false
  }
}

const columns: TableColumn<FailedWoItem>[] = [
  { accessorKey: 'planNumber', header: '計畫批號' },
  { accessorKey: 'productNo', header: '品號' },
  { accessorKey: 'modelName', header: '品名' },
  { accessorKey: 'serialNo', header: '序號' },
  { accessorKey: 'shippingDate', header: '出貨日' }
]
</script>

<template>
  <div>
    <FullPageLoading :show="loading" />

    <UBreadcrumb :items="[{ label: '首頁', to: '/', icon: 'i-lucide-house' }, { label: '測試系統', icon: 'i-lucide-flask-conical' }, { label: '測試作業' }, { label: '覆核列表' }]" class="mb-4" />

    <h1 class="text-2xl font-bold text-highlighted">
      覆核列表
    </h1>
    <p class="mb-4 text-sm text-muted">
      顯示測試失敗的工單，請覆核後決定「特採出貨」或「重新測試」。
    </p>

    <div class="mb-4">
      <UInput v-model="search" icon="i-lucide-search" placeholder="搜尋計畫批號/品號/品名/序號..." class="w-64" />
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
      />
      <TablePaginationBar :table="table" />
    </div>

    <USlideover v-model:open="detailOpen" title="測試失敗詳細資料" :description="selected?.woNo">
      <template #body>
        <div v-if="detailLoading" class="text-sm text-muted">
          載入中...
        </div>
        <div v-else class="space-y-6">
          <div v-if="header" class="grid grid-cols-2 gap-4 sm:grid-cols-3">
            <UFormField label="品名"><UInput :model-value="header.modelName" disabled /></UFormField>
            <UFormField label="計畫批號"><UInput :model-value="header.planNumber" disabled /></UFormField>
            <UFormField label="序號"><UInput :model-value="header.serialNo" disabled /></UFormField>
            <UFormField label="相數"><UInput :model-value="header.phase" disabled /></UFormField>
            <UFormField label="頻率"><UInput :model-value="header.frequency" disabled /></UFormField>
            <UFormField label="電壓"><UInput :model-value="header.voltage" disabled /></UFormField>
          </div>

          <div v-if="reference">
            <h3 class="mb-2 text-sm font-semibold text-highlighted">
              測試標準：{{ reference.testName }}（{{ reference.testPlace }}）
            </h3>
            <TestReferenceGrid :rows="reference.productDetail" />
          </div>

          <div v-if="actual">
            <h3 class="mb-2 text-sm font-semibold text-highlighted">
              測試失敗當時數值
            </h3>
            <div class="grid grid-cols-2 gap-4 sm:grid-cols-4">
              <UFormField label="最大水量"><UInput :model-value="actual.maxWater" disabled /></UFormField>
              <UFormField label="最大揚程"><UInput :model-value="actual.maxLift" disabled /></UFormField>
              <UFormField label="最大瓦特"><UInput :model-value="actual.maxWatt" disabled /></UFormField>
              <UFormField label="最大安培"><UInput :model-value="actual.maxAmpere" disabled /></UFormField>
              <UFormField label="標準水量"><UInput :model-value="actual.standardWater" disabled /></UFormField>
              <UFormField label="標準揚程"><UInput :model-value="actual.standardLift" disabled /></UFormField>
              <UFormField label="標準瓦特"><UInput :model-value="actual.standardWatt" disabled /></UFormField>
              <UFormField label="標準安培"><UInput :model-value="actual.standardAmpere" disabled /></UFormField>
            </div>
          </div>

          <USeparator />
          <TestMemoPanel v-if="selected" :link-type="6" :link-number="selected.woNo" />
        </div>
      </template>
      <template #footer>
        <UButton color="warning" variant="outline" :loading="deciding" @click="decide(3)">
          特採出貨
        </UButton>
        <UButton :loading="deciding" @click="decide(2)">
          重新測試
        </UButton>
      </template>
    </USlideover>
  </div>
</template>
