<script setup lang="ts">
import { getPaginationRowModel } from '@tanstack/vue-table'
import type { TableColumn } from '@nuxt/ui'
import type { ApiResponse, TestHistoryItem, ProductListItem, PoListItem, ProductByWoItem, ProductDetailViewModel, HWorkOrder } from '~/types/test'

const { apiFetch } = useApi()
const { phaseOptions, frequencyOptions } = useTestEnums()
const toast = useToast()
const { pagination } = useTablePagination()
const table = useTemplateRef('table')

const loading = ref(false)
const list = ref<TestHistoryItem[]>([])

const poOptions = ref<{ label: string, value: string }[]>([])
const planNumberOptions = ref<{ label: string, value: string }[]>([])
const modelNameOptions = ref<{ label: string, value: string }[]>([])
const voltageOptions = ref<{ label: string, value: string }[]>([])

const NONE = '0'
const filters = reactive({
  poNo: NONE,
  modelName: NONE,
  planNumber: NONE,
  phase: NONE,
  frequency: NONE,
  voltage: NONE,
  date: ''
})

const loadOptions = async () => {
  try {
    const [poRes, productRes] = await Promise.all([
      apiFetch<ApiResponse<string>>('/PurchaseOrderApi/GetPoList_2'),
      apiFetch<ApiResponse<ProductListItem[]>>('/ProductApi/GetProductList')
    ])

    const pos: PoListItem[] = poRes?.body ? JSON.parse(poRes.body) : []
    poOptions.value = [{ label: '不限', value: NONE }, ...pos.map(p => ({ label: `${p.PoNo} (${p.PlanNumber})`, value: p.PoNo }))]
    planNumberOptions.value = [{ label: '不限', value: NONE }, ...[...new Set(pos.map(p => p.PlanNumber).filter(Boolean))].map(v => ({ label: v, value: v }))]

    const products = productRes?.body ?? []
    modelNameOptions.value = [{ label: '不限', value: NONE }, ...[...new Set(products.map(p => p.modelName).filter(Boolean))].map(v => ({ label: v, value: v }))]
    voltageOptions.value = [{ label: '不限', value: NONE }, ...[...new Set(products.map(p => p.voltage).filter(Boolean))].map(v => ({ label: v, value: v }))]
  } catch {
    // 選項來源 API 無法連線時，維持空白選單，僅保留「不限」
  }
}

const query = async () => {
  loading.value = true
  try {
    const params: Record<string, string> = {
      input: filters.poNo,
      modelName: filters.modelName,
      planNumber: filters.planNumber,
      phase: filters.phase,
      frequency: filters.frequency,
      voltage: filters.voltage
    }
    if (filters.date) params.date = filters.date
    const res = await apiFetch<ApiResponse<TestHistoryItem[]>>('/WorkOrderApi/GetTestHistoryByPo', { params })
    list.value = res?.body ?? []
  } catch {
    list.value = []
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  await loadOptions()
  await query()
})

const detailOpen = ref(false)
const detailLoading = ref(false)
const selected = ref<TestHistoryItem | null>(null)
const header = ref<ProductByWoItem | null>(null)
const reference = ref<ProductDetailViewModel | null>(null)
const actual = ref<HWorkOrder | null>(null)
const retesting = ref(false)

const isToday = (row: TestHistoryItem) => row.testTime?.slice(0, 10).replace(/-/g, '/') === new Date().toLocaleDateString('zh-TW').replace(/\//g, '/')

const openDetail = async (row: TestHistoryItem) => {
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
      apiFetch<ApiResponse<HWorkOrder>>('/TestApi/GetTestHistoryById', { params: { input: row.id } })
    ])
    header.value = headerRes?.body ?? null
    reference.value = refRes
    actual.value = actualRes?.body ?? null
  } finally {
    detailLoading.value = false
  }
}

const retest = async () => {
  if (!selected.value) return
  retesting.value = true
  try {
    await apiFetch<ApiResponse<any>>('/WorkOrderApi/SetWoStatus', { params: { woNo: selected.value.woNo, woStatus: 0 } })
    toast.add({ title: '已回測，此工單將重新回到待測試清單', color: 'success' })
    detailOpen.value = false
    await query()
  } finally {
    retesting.value = false
  }
}

const columns: TableColumn<TestHistoryItem>[] = [
  { accessorKey: 'serialNo', header: '序號' },
  { accessorKey: 'modelName', header: '品名' },
  { accessorKey: 'planNumber', header: '計畫批號' },
  { accessorKey: 'userName', header: '測試者' },
  { accessorKey: 'testTime', header: '測試時間' },
  { accessorKey: 'testPlace', header: '測試地點' },
  { accessorKey: 'woStatusName', header: '工單狀態' }
]
</script>

<template>
  <div>
    <FullPageLoading :show="loading" />

    <UBreadcrumb :items="[{ label: '首頁', to: '/', icon: 'i-lucide-house' }, { label: '測試系統', icon: 'i-lucide-flask-conical' }, { label: '測試作業' }, { label: '測試歷史' }]" class="mb-4" />

    <h1 class="mb-4 text-2xl font-bold text-highlighted">
      測試歷史
    </h1>

    <UCard class="mb-4">
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-3 lg:grid-cols-4">
        <UFormField label="訂單"><USelectMenu v-model="filters.poNo" value-key="value" :items="poOptions" class="w-full" /></UFormField>
        <UFormField label="品名"><USelectMenu v-model="filters.modelName" value-key="value" :items="modelNameOptions" class="w-full" /></UFormField>
        <UFormField label="計畫批號"><USelectMenu v-model="filters.planNumber" value-key="value" :items="planNumberOptions" class="w-full" /></UFormField>
        <UFormField label="相數"><USelectMenu v-model="filters.phase" value-key="value" :items="[{ label: '不限', value: NONE }, ...phaseOptions]" class="w-full" /></UFormField>
        <UFormField label="頻率"><USelectMenu v-model="filters.frequency" value-key="value" :items="[{ label: '不限', value: NONE }, ...frequencyOptions]" class="w-full" /></UFormField>
        <UFormField label="電壓"><USelectMenu v-model="filters.voltage" value-key="value" :items="voltageOptions" class="w-full" /></UFormField>
        <UFormField label="出貨日"><UInput v-model="filters.date" type="date" /></UFormField>
      </div>
      <div class="mt-4">
        <UButton icon="i-lucide-search" :loading="loading" @click="query">
          查詢
        </UButton>
      </div>
    </UCard>

    <div class="overflow-hidden rounded-lg border border-default">
      <UTable
        ref="table"
        v-model:pagination="pagination"
        :pagination-options="{ getPaginationRowModel: getPaginationRowModel() }"
        :data="list"
        :columns="columns"
        :loading="loading"
        :ui="{ tr: 'cursor-pointer' }"
        @select="(_e: Event, row: any) => openDetail(row.original)"
      >
        <template #woStatusName-cell="{ row }">
          <UBadge :color="WO_STATUS_COLORS[row.original.woStatus]" variant="subtle">
            {{ row.original.woStatusName }}
          </UBadge>
        </template>
      </UTable>
      <TablePaginationBar :table="table" />
    </div>

    <USlideover v-model:open="detailOpen" title="測試歷史詳細資料" :description="selected?.woNo">
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
              當次測試數值
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
          <TestMemoPanel v-if="selected" :link-type="7" :link-number="selected.woNo" readonly />
        </div>
      </template>
      <template #footer>
        <UButton v-if="selected && isToday(selected)" :loading="retesting" @click="retest">
          回測
        </UButton>
      </template>
    </USlideover>
  </div>
</template>
