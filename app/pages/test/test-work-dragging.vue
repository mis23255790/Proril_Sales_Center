<script setup lang="ts">
import { getPaginationRowModel } from '@tanstack/vue-table'
import type { TableColumn } from '@nuxt/ui'
import type { ApiResponse, WoByPoItem, ProductByWoItem, ProductDetailViewModel } from '~/types/test'
import type { TestValues } from '~/components/test/TestValueFields.vue'

const { apiFetch } = useApi()
const toast = useToast()
const { pagination } = useTablePagination()
const table = useTemplateRef('table')

const loading = ref(false)
const allRows = ref<WoByPoItem[]>([])

const NONE = '0'
const selectedPo = ref(NONE)
const selectedProduct = ref(NONE)
const search = ref('')

const fetchList = async () => {
  loading.value = true
  try {
    const res = await apiFetch<ApiResponse<WoByPoItem[]>>('/WorkOrderApi/GetWoByPo', {
      params: { poNo: NONE, productNo: '' }
    })
    allRows.value = res?.body ?? []
  } catch {
    allRows.value = []
  } finally {
    loading.value = false
  }
}

onMounted(fetchList)

const poOptions = computed(() => {
  const seen = new Map<string, string>()
  allRows.value.forEach(r => seen.set(r.poNo, r.planNumber))
  return [{ label: '請選擇計畫批號', value: NONE }, ...[...seen.entries()].map(([poNo, planNumber]) => ({ label: `${planNumber} (${poNo})`, value: poNo }))]
})

const productOptions = computed(() => {
  const rows = selectedPo.value === NONE ? allRows.value : allRows.value.filter(r => r.poNo === selectedPo.value)
  const names = [...new Set(rows.map(r => r.modelName))]
  return [{ label: '全部品名', value: NONE }, ...names.map(n => ({ label: n, value: n }))]
})

watch(selectedPo, () => { selectedProduct.value = NONE })

const filteredRows = computed(() => {
  let rows = allRows.value
  if (selectedPo.value !== NONE) rows = rows.filter(r => r.poNo === selectedPo.value)
  if (selectedProduct.value !== NONE) rows = rows.filter(r => r.modelName === selectedProduct.value)
  if (search.value) {
    const kw = search.value.toLowerCase()
    rows = rows.filter(r => r.serialNo?.toLowerCase().includes(kw) || r.modelName?.toLowerCase().includes(kw))
  }
  return rows
})

watch([selectedPo, selectedProduct, search], () => { pagination.value.pageIndex = 0 })

const columns: TableColumn<WoByPoItem>[] = [
  { accessorKey: 'planNumber', header: '計畫批號' },
  { accessorKey: 'serialNo', header: '序號' },
  { accessorKey: 'modelName', header: '品名' },
  { accessorKey: 'phase', header: '相數' },
  { accessorKey: 'frequency', header: '頻率' },
  { accessorKey: 'voltage', header: '電壓' },
  { accessorKey: 'checkQty', header: '抽檢號' },
  { accessorKey: 'testPlace', header: '測試地點' },
  { id: 'actions', header: '功能' }
]

const testOpen = ref(false)
const testLoading = ref(false)
const testSubmitting = ref(false)
const header = ref<ProductByWoItem | null>(null)
const reference = ref<ProductDetailViewModel | null>(null)
const currentWoNo = ref('')
const currentProductNo = ref('')
const testPlace = ref('')

const emptyValues = (): TestValues => ({
  maxWater: null, maxLift: null, maxWatt: null, maxAmpere: null,
  standardWater: null, standardLift: null, standardWatt: null, standardAmpere: null
})
const inputValues = ref<TestValues>(emptyValues())
const blankStandard = emptyValues()

const loadTestContext = async (woNo: string) => {
  testLoading.value = true
  header.value = null
  reference.value = null
  try {
    const [headerRes, refRes] = await Promise.all([
      apiFetch<ApiResponse<ProductByWoItem>>('/ProductApi/GetProductByWo', { params: { input: woNo } }),
      apiFetch<ProductDetailViewModel>('/WorkOrderApi/GetWoStandard', { params: { woNo } })
    ])
    header.value = headerRes?.body ?? null
    reference.value = refRes
  } finally {
    testLoading.value = false
  }
}

const openTest = async (row: WoByPoItem) => {
  currentWoNo.value = row.woNo
  currentProductNo.value = row.productNo
  testPlace.value = row.testPlace
  inputValues.value = emptyValues()
  testOpen.value = true
  await loadTestContext(row.woNo)
}

const goToNextOrClose = async () => {
  const res = await apiFetch<ApiResponse<{ productNo: string, woNo: string }>>('/WorkOrderApi/GetNextProduct', {
    params: { woNo: currentWoNo.value, productNo: currentProductNo.value }
  })
  if (res?.isSuccess && res.body?.woNo) {
    currentWoNo.value = res.body.woNo
    currentProductNo.value = res.body.productNo
    inputValues.value = emptyValues()
    await loadTestContext(currentWoNo.value)
  } else {
    testOpen.value = false
    toast.add({ title: '此訂單該機型已無待測資料', color: 'info' })
  }
  await fetchList()
}

const submit = async () => {
  const hasEmpty = Object.values(inputValues.value).some(v => v == null)
  if (hasEmpty) {
    toast.add({ title: '請完整輸入 8 項測試數值', color: 'warning' })
    return
  }
  testSubmitting.value = true
  try {
    const res = await apiFetch<ApiResponse<any>>('/TestApi/SaveTestData', {
      params: {
        woNo: currentWoNo.value,
        productNo: currentProductNo.value,
        testPlace: testPlace.value,
        ...inputValues.value
      }
    })
    if (res?.isSuccess) {
      toast.add({ title: '測試資料已送出', color: 'success' })
      await goToNextOrClose()
    } else {
      toast.add({ title: '送出失敗', description: res?.message ?? '', color: 'error' })
    }
  } finally {
    testSubmitting.value = false
  }
}
</script>

<template>
  <div>
    <FullPageLoading :show="loading" />

    <UBreadcrumb :items="[{ label: '首頁', to: '/', icon: 'i-lucide-house' }, { label: '測試系統', icon: 'i-lucide-flask-conical' }, { label: '測試作業' }, { label: '著托測試' }]" class="mb-4" />

    <h1 class="mb-4 text-2xl font-bold text-highlighted">
      著托測試
    </h1>

    <div class="mb-4 flex flex-wrap items-center gap-3">
      <UInput v-model="search" icon="i-lucide-search" placeholder="搜尋序號/品名..." class="w-56" />
      <USelectMenu v-model="selectedPo" value-key="value" :items="poOptions" class="w-64" />
      <USelectMenu v-model="selectedProduct" value-key="value" :items="productOptions" class="w-56" />
      <UButton icon="i-lucide-refresh-cw" color="neutral" variant="outline" :loading="loading" class="sm:ml-auto" @click="fetchList">
        重新整理
      </UButton>
    </div>

    <div class="overflow-hidden rounded-lg border border-default">
      <UTable
        ref="table"
        v-model:pagination="pagination"
        :pagination-options="{ getPaginationRowModel: getPaginationRowModel() }"
        :data="filteredRows"
        :columns="columns"
        :loading="loading"
      >
        <template #actions-cell="{ row }">
          <UButton size="xs" @click="openTest(row.original)">
            測試
          </UButton>
        </template>
      </UTable>
      <TablePaginationBar :table="table" />
    </div>

    <USlideover v-model:open="testOpen" title="著托測試" :description="header?.modelName">
      <template #body>
        <div v-if="testLoading" class="text-sm text-muted">
          載入中...
        </div>
        <div v-else class="space-y-6">
          <div v-if="header" class="grid grid-cols-2 gap-4 sm:grid-cols-3">
            <UFormField label="計畫批號"><UInput :model-value="header.planNumber" disabled /></UFormField>
            <UFormField label="序號"><UInput :model-value="header.serialNo" disabled /></UFormField>
            <UFormField label="相數/頻率/電壓"><UInput :model-value="`${header.phase} / ${header.frequency} / ${header.voltage}`" disabled /></UFormField>
          </div>

          <UFormField label="測試地點">
            <UInput v-model="testPlace" />
          </UFormField>

          <div v-if="reference">
            <h3 class="mb-2 text-sm font-semibold text-highlighted">
              測試標準：{{ reference.testName }}（{{ reference.testPlace }}）
            </h3>
            <TestReferenceGrid :rows="reference.productDetail" class="mb-4" />
          </div>

          <div>
            <h3 class="mb-2 text-sm font-semibold text-highlighted">
              實測數值
            </h3>
            <TestValueFields v-model="inputValues" :standard="blankStandard" />
          </div>

          <USeparator />
          <TestMemoPanel v-if="currentWoNo" :link-type="211" :link-number="currentWoNo" />
        </div>
      </template>
      <template #footer>
        <UButton :loading="testSubmitting" @click="submit">
          送出
        </UButton>
      </template>
    </USlideover>
  </div>
</template>
