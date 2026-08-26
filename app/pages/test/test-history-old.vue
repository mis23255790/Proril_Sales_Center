<script setup lang="ts">
import { getPaginationRowModel } from '@tanstack/vue-table'
import type { TableColumn } from '@nuxt/ui'
import type { ApiResponse, HTestDataOld } from '~/types/test'

const { apiFetch } = useApi()
const { phaseOptions, frequencyOptions } = useTestEnums()
const { pagination } = useTablePagination()
const table = useTemplateRef('table')

const loading = ref(false)
const list = ref<HTestDataOld[]>([])

const filters = reactive({
  serialNo: '',
  shortName: '',
  modelName: '',
  phase: '',
  frequency: '',
  voltage: '',
  outDateS: '',
  outDateE: ''
})

const buildParams = () => {
  const p: Record<string, string> = {}
  if (filters.serialNo) p.SerialNo = filters.serialNo
  if (filters.shortName) p.ShortName = filters.shortName
  if (filters.modelName) p.ModelName = filters.modelName
  if (filters.phase) p.Phase = filters.phase
  if (filters.frequency) p.Frequency = filters.frequency
  if (filters.voltage) p.Voltage = filters.voltage
  if (filters.outDateS) p.OutDateS = filters.outDateS
  if (filters.outDateE) p.OutDateE = filters.outDateE
  return p
}

const query = async () => {
  loading.value = true
  try {
    const res = await apiFetch<ApiResponse<HTestDataOld[]>>('/TestApi/GetTestHistoryOld', { params: buildParams() })
    list.value = res?.body ?? []
  } catch {
    list.value = []
  } finally {
    loading.value = false
  }
}

const selectAll = () => {
  Object.assign(filters, { serialNo: '', shortName: '', modelName: '', phase: '', frequency: '', voltage: '', outDateS: '', outDateE: '' })
  query()
}

onMounted(query)

const columns: TableColumn<HTestDataOld>[] = [
  { accessorKey: 'serialNo', header: '序號' },
  { accessorKey: 'shippingDateTw', header: '出貨日' },
  { accessorKey: 'shortName', header: '客戶' },
  { accessorKey: 'checkSno', header: '抽檢量' },
  { accessorKey: 'productNo', header: '品號' },
  { accessorKey: 'modelName', header: '機型' },
  { accessorKey: 'voltage', header: '電壓' },
  { accessorKey: 'phase', header: '相數' },
  { accessorKey: 'frequency', header: '頻率' },
  { accessorKey: 'maxWater', header: '最大水量' },
  { accessorKey: 'maxLift', header: '最大揚程' },
  { accessorKey: 'maxWatt', header: '最大瓦特' },
  { accessorKey: 'maxAmpere', header: '最大安培' },
  { accessorKey: 'standardWater', header: '標準水量' },
  { accessorKey: 'standardLift', header: '標準揚程' },
  { accessorKey: 'standardWatt', header: '標準瓦特' },
  { accessorKey: 'standardAmpere', header: '標準安培' },
  { accessorKey: 'tester', header: '作業者' },
  { accessorKey: 'testResults', header: '測試結果' },
  { accessorKey: 'failProcess', header: '不符處置' }
]
</script>

<template>
  <div>
    <FullPageLoading :show="loading" />

    <UBreadcrumb :items="[{ label: '首頁', to: '/', icon: 'i-lucide-house' }, { label: '測試系統', icon: 'i-lucide-flask-conical' }, { label: '測試作業' }, { label: '測試歷史(舊版)' }]" class="mb-4" />

    <h1 class="mb-4 text-2xl font-bold text-highlighted">
      測試歷史(舊版)
    </h1>

    <UAlert
      color="neutral"
      variant="subtle"
      class="mb-4"
      title="舊系統資料"
      description="此為遷移前舊系統的測試歷史資料，僅供查閱，不提供編輯或回測功能。目前 API 未提供序號/客戶/機型清單查詢，篩選欄位暫以文字輸入取代原本下拉選單。"
    />

    <UCard class="mb-4">
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-3 lg:grid-cols-4">
        <UFormField label="序號"><UInput v-model="filters.serialNo" /></UFormField>
        <UFormField label="客戶簡稱"><UInput v-model="filters.shortName" /></UFormField>
        <UFormField label="機型"><UInput v-model="filters.modelName" /></UFormField>
        <UFormField label="相數"><USelectMenu v-model="filters.phase" value-key="value" :items="phaseOptions" placeholder="不限" class="w-full" /></UFormField>
        <UFormField label="頻率"><USelectMenu v-model="filters.frequency" value-key="value" :items="frequencyOptions" placeholder="不限" class="w-full" /></UFormField>
        <UFormField label="電壓"><UInput v-model="filters.voltage" /></UFormField>
        <UFormField label="出貨日(起)"><UInput v-model="filters.outDateS" type="date" /></UFormField>
        <UFormField label="出貨日(迄)"><UInput v-model="filters.outDateE" type="date" /></UFormField>
      </div>
      <div class="mt-4 flex gap-2">
        <UButton icon="i-lucide-search" :loading="loading" @click="query">
          查詢
        </UButton>
        <UButton color="neutral" variant="outline" @click="selectAll">
          全部顯示
        </UButton>
      </div>
    </UCard>

    <div class="overflow-hidden rounded-lg border border-default">
      <div class="overflow-x-auto">
        <UTable
          ref="table"
          v-model:pagination="pagination"
          :pagination-options="{ getPaginationRowModel: getPaginationRowModel() }"
          :data="list"
          :columns="columns"
          :loading="loading"
        />
      </div>
      <TablePaginationBar :table="table" />
    </div>
  </div>
</template>
