<script setup lang="ts">
import { getPaginationRowModel } from '@tanstack/vue-table'
import type { TableColumn } from '@nuxt/ui'
import type { ApiResponse, PoListItem, PoDetailViewModel } from '~/types/test'
import ConfirmDialog from '~/components/ConfirmDialog.vue'

type GroupedPo = PoListItem & { poGroupType: number }

const GROUP = { notGenerated: 1, generated: 2, tested: 3, abandoned: 4, notDefined: 5 } as const
const GROUP_LABELS: Record<number, string> = {
  1: '未生成單據',
  2: '已生成測試工單',
  3: '已測試',
  4: '已廢棄',
  5: '未定義'
}

const { apiFetch } = useApi()
const toast = useToast()
const overlay = useOverlay()
const confirmDialog = overlay.create(ConfirmDialog)
const { pagination } = useTablePagination()
const table = useTemplateRef('table')

const loading = ref(false)
const rawList = ref<PoListItem[]>([])
const filterTab = ref<'notGenerated' | 'generated' | 'tested' | 'abandoned' | 'all'>('notGenerated')
const search = ref('')

const groupPoList = (list: PoListItem[]): GroupedPo[] => {
  const withGroup: GroupedPo[] = list.map((po) => {
    let type: number
    if (po.Detail_Qty === 0) {
      type = GROUP.tested
    } else if (po.Abandoner != null) {
      type = GROUP.abandoned
    } else if (po.PoStatus === 1 || (po.Detail_Abandoner == null && po.DW_ID == null)) {
      type = GROUP.notGenerated
    } else {
      const allTested = !(po.Wos ?? []).some(w => w.WoStatus === 0 && (po.Detail_Qty ?? 0) > 0)
      if (po.Detail_Abandoner != null) {
        type = GROUP.abandoned
      } else if (allTested && po.Detail_Abandoner == null && po.DW_ID != null) {
        type = GROUP.tested
      } else {
        type = GROUP.generated
      }
    }
    return { ...po, poGroupType: type }
  })

  const result: GroupedPo[] = []
  let curPoNo = ''
  let curPo: GroupedPo | null = null
  let curType = 0

  const flush = () => { if (curPo) { curPo.poGroupType = curType; result.push(curPo) } }

  withGroup.forEach((po) => {
    if (po.PoNo !== curPoNo && curPoNo.length > 0) flush()

    if (curPoNo !== po.PoNo) {
      curPo = po
      curPoNo = po.PoNo
      curType = po.poGroupType
    } else if (po.poGroupType === GROUP.notGenerated) {
      curType = GROUP.notGenerated
    } else if (po.poGroupType === GROUP.abandoned) {
      curType = GROUP.abandoned
    } else if (po.poGroupType === GROUP.generated) {
      curType = GROUP.generated
    }
  })
  flush()

  return result
}

const grouped = computed(() => groupPoList(rawList.value))

const filtered = computed(() => {
  const tab = filterTab.value
  let rows = tab === 'all' ? grouped.value : grouped.value.filter(po => po.poGroupType === GROUP[tab as Exclude<typeof tab, 'all'>])

  if (search.value) {
    const kw = search.value.toLowerCase()
    rows = rows.filter(po =>
      po.PoNo?.toLowerCase().includes(kw)
      || po.PlanNumber?.toLowerCase().includes(kw)
      || po.CustomerNo?.toLowerCase().includes(kw)
    )
  }

  return rows
})

watch([filterTab, search], () => { pagination.value.pageIndex = 0 })

const fetchList = async () => {
  loading.value = true
  try {
    const res = await apiFetch<ApiResponse<string>>('/PurchaseOrderApi/GetPoList_2')
    rawList.value = res?.body ? JSON.parse(res.body) : []
  } catch {
    rawList.value = []
  } finally {
    loading.value = false
  }
}

onMounted(fetchList)

const memoOpen = ref(false)
const memoTarget = ref<GroupedPo | null>(null)
const openMemo = (po: GroupedPo) => { memoTarget.value = po; memoOpen.value = true }

const detailOpen = ref(false)
const detailLoading = ref(false)
const detailPoNo = ref('')
const detailItems = ref<PoDetailViewModel[]>([])
const generating = ref(false)

const openDetail = async (po: GroupedPo) => {
  detailPoNo.value = po.PoNo
  detailOpen.value = true
  detailLoading.value = true
  try {
    detailItems.value = await apiFetch<PoDetailViewModel[]>('/PurchaseOrderApi/GetPoDetailList', {
      params: { poNo: po.PoNo, customerNo: po.CustomerNo }
    }) ?? []
  } finally {
    detailLoading.value = false
  }
}

const generatePo = async (poNo: string) => {
  generating.value = true
  try {
    const res = await apiFetch<ApiResponse<any>>('/WorkOrderApi/SaveDWordOrder', { params: { poNo } })
    if (res?.isSuccess) {
      toast.add({ title: `生成存檔成功${res.message ? ' - ' + res.message : ''}`, color: 'success' })
    } else {
      toast.add({ title: '生成失敗', description: res?.message ?? '', color: 'error' })
    }
    detailOpen.value = false
    await fetchList()
  } finally {
    generating.value = false
  }
}

const generateLine = async (poNo: string, productNo: string) => {
  generating.value = true
  try {
    const res = await apiFetch<ApiResponse<any>>('/WorkOrderApi/SaveDWordOrder_ProductNo', { params: { poNo, productNo } })
    if (res?.isSuccess) {
      toast.add({ title: `生成存檔成功${res.message ? ' - ' + res.message : ''}`, color: 'success' })
    } else {
      toast.add({ title: '生成失敗', description: res?.message ?? '', color: 'error' })
    }
    await openDetail({ PoNo: poNo } as GroupedPo)
    await fetchList()
  } finally {
    generating.value = false
  }
}

const abandonPo = async (poNo: string) => {
  const confirmed = await confirmDialog.open({
    title: '確定要刪單？',
    description: `PO: ${poNo}`,
    confirmLabel: '刪單',
    confirmColor: 'error'
  }).result
  if (!confirmed) return

  const ok = await apiFetch<boolean>('/WorkOrderApi/AbandonedWorkOrder', { params: { poNo } })
  toast.add({ title: ok ? '刪單存檔成功' : '刪單存檔失敗', color: ok ? 'success' : 'error' })
  await fetchList()
}

const reimportPo = async (poNo: string) => {
  const confirmed = await confirmDialog.open({
    title: '確定要重匯？',
    description: `PO單: ${poNo} 會刪除既有資料重新匯入`,
    confirmLabel: '重匯',
    confirmColor: 'warning'
  }).result
  if (!confirmed) return

  const res = await apiFetch<ApiResponse<any>>('/ErpImportApi/ReImportTestOrder', { params: { poNo } })
  if (res?.isSuccess) {
    toast.add({ title: `重匯成功(ERP匯入${res.message}筆)`, color: 'success' })
  } else {
    toast.add({ title: '重匯失敗', description: res?.message ?? '', color: 'error' })
  }
  await fetchList()
}

const tabs = [
  { label: '未生成單據', value: 'notGenerated' },
  { label: '已生成測試工單', value: 'generated' },
  { label: '已測試', value: 'tested' },
  { label: '已廢棄', value: 'abandoned' },
  { label: '全部', value: 'all' }
]

const columns: TableColumn<GroupedPo>[] = [
  { accessorKey: 'PoNo', header: '單號' },
  { accessorKey: 'PlanNumber', header: '計畫批號' },
  { accessorKey: 'CustomerNo', header: '客戶' },
  { accessorKey: 'ShippingDate', header: '出貨日' },
  { accessorKey: 'poGroupType', header: '狀態' },
  { id: 'actions', header: '功能' }
]
</script>

<template>
  <div>
    <FullPageLoading :show="loading" />

    <UBreadcrumb :items="[{ label: '首頁', to: '/', icon: 'i-lucide-house' }, { label: '測試系統', icon: 'i-lucide-flask-conical' }, { label: '生管作業' }, { label: '訂單管理' }]" class="mb-4" />

    <h1 class="mb-4 text-2xl font-bold text-highlighted">
      訂單管理
    </h1>

    <div class="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center">
      <UInput v-model="search" icon="i-lucide-search" placeholder="搜尋單號/計畫批號/客戶..." class="w-64" />
      <UTabs v-model="filterTab" :items="tabs" :content="false" class="sm:ml-auto" />
    </div>

    <div class="overflow-hidden rounded-lg border border-default">
      <UTable
        ref="table"
        v-model:pagination="pagination"
        :pagination-options="{ getPaginationRowModel: getPaginationRowModel() }"
        :data="filtered"
        :columns="columns"
        :loading="loading"
      >
      <template #poGroupType-cell="{ row }">
        <UBadge variant="subtle">
          {{ GROUP_LABELS[row.original.poGroupType] }}
        </UBadge>
      </template>
      <template #actions-cell="{ row }">
        <div class="flex flex-wrap gap-1.5">
          <UButton size="xs" color="neutral" variant="outline" @click="openDetail(row.original)">
            內容
          </UButton>
          <UButton size="xs" color="neutral" variant="outline" @click="openMemo(row.original)">
            備註
          </UButton>
          <UButton v-if="row.original.poGroupType === GROUP.notGenerated" size="xs" @click="generatePo(row.original.PoNo)">
            生成
          </UButton>
          <UButton size="xs" color="neutral" variant="outline" @click="abandonPo(row.original.PoNo)">
            刪單
          </UButton>
          <UButton
            v-if="row.original.poGroupType === GROUP.notGenerated || row.original.poGroupType === GROUP.abandoned"
            size="xs"
            color="neutral"
            variant="outline"
            @click="reimportPo(row.original.PoNo)"
          >
            重匯
          </UButton>
        </div>
      </template>
      </UTable>
      <TablePaginationBar :table="table" />
    </div>

    <USlideover v-model:open="memoOpen" title="訂單備註" :description="memoTarget?.PoNo">
      <template #body>
        <TestMemoPanel v-if="memoTarget" :link-type="4" :link-number="memoTarget.PoNo" />
      </template>
    </USlideover>

    <USlideover v-model:open="detailOpen" title="訂單明細" :description="detailPoNo" side="right" :ui="{ content: 'max-w-3xl' }">
      <template #body>
        <div v-if="detailLoading" class="text-sm text-muted">
          載入中...
        </div>
        <div v-else class="space-y-3">
          <div v-for="item in detailItems" :key="item.productNo" class="rounded-lg border border-default p-3">
            <div class="mb-2 grid grid-cols-2 gap-x-4 gap-y-1 text-sm sm:grid-cols-4">
              <p><span class="text-muted">品號：</span>{{ item.productNo }}</p>
              <p><span class="text-muted">機型：</span>{{ item.modelName }}</p>
              <p><span class="text-muted">相數/頻率/電壓：</span>{{ item.phase }}/{{ item.frequency }}/{{ item.voltage }}</p>
              <p><span class="text-muted">數量：</span>{{ item.qty }}</p>
              <p><span class="text-muted">測試標準：</span>{{ item.testName ?? '-' }}</p>
              <p><span class="text-muted">檢驗規則：</span>{{ item.testTypeDescription ?? '-' }}</p>
              <p><span class="text-muted">測試數量：</span>{{ item.testQty ?? '-' }}</p>
            </div>
            <UButton
              v-if="item.testName"
              size="xs"
              :loading="generating"
              @click="generateLine(detailPoNo, item.productNo)"
            >
              生成
            </UButton>
            <UButton
              v-else
              size="xs"
              color="warning"
              variant="subtle"
              :to="`/test/product-maintain?editProductNo=${item.productNo}`"
            >
              設定測試標準
            </UButton>
          </div>
        </div>
      </template>
      <template #footer>
        <UButton :loading="generating" @click="generatePo(detailPoNo)">
          全部生成
        </UButton>
      </template>
    </USlideover>
  </div>
</template>
