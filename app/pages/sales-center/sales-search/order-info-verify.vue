<script setup lang="ts">
import { h, resolveComponent } from 'vue'
import type { TableColumn } from '@nuxt/ui'
import type { CopCheckRule, OrderInfoVerifyGroup, OrderInfoVerifySummary } from '~/types/orderInfoVerify'
import type { SalesShippingCustomer } from '~/types/salesShipping'
import { chkBadgeColor, chkBadgeLabel, feFinChk, groupOrderInfoVerifyRows } from '~/utils/orderInfoVerify'

definePageMeta({ title: '訂單資料檢核' })

useSeoMeta({ title: '訂單資料檢核 · PRORIL 業務中心' })

const api = useOrderInfoVerifyApi()
const { checkPermission } = usePermission()
const toast = useToast()
const { breadcrumbFor, appPath } = useAppNavigation()
const { pagination } = useTablePagination(20)
const table = useTemplateRef('table')

const loading = ref(false)
const exporting = ref<'Y' | 'N' | null>(null)
const showAmount = ref(false)
const customers = ref<SalesShippingCustomer[]>([])

const filters = reactive({
  customerNo: '',
  orderType: '',
  startDate: '',
  endDate: ''
})

/**
 * USelectMenu（Reka UI Combobox）不允許 item 的 value 是空字串（保留給「清空選取」），
 * 用這個哨兵值代表「全部客戶」，實際存到 filters.customerNo 的還是空字串，
 * 透過下面的 customerNoSelectValue 轉換。
 */
const ALL_CUSTOMER = '__all_customer__'

const customerOptions = computed(() => [
  { label: '全部客戶', value: ALL_CUSTOMER },
  ...customers.value.map(c => ({
    label: `${c.customerNo}-${c.longName ?? ''}(${c.shortName ?? ''})`,
    value: c.customerNo
  }))
])

const customerNoSelectValue = computed({
  get: () => filters.customerNo || ALL_CUSTOMER,
  set: (v: string) => { filters.customerNo = v === ALL_CUSTOMER ? '' : v }
})

const loadCustomers = async () => {
  try {
    const res = await api.getCustomers()
    customers.value = res?.isSuccess ? (res.body ?? []) : []
  } catch (err) {
    console.log('order-info-verify loadCustomers failed -->', err)
    customers.value = []
  }
}

const loadPermission = async () => {
  try {
    showAmount.value = await checkPermission(PERMISSION_KEYS.salesSearch.orderInfoVerifyViewAmount)
  } catch (err) {
    console.log('order-info-verify loadPermission failed -->', err)
    showAmount.value = false
  }
}

const groups = ref<OrderInfoVerifyGroup[]>([])

const EMPTY_SUMMARY: OrderInfoVerifySummary = { totalCount: 0, notCheckedCount: 0, checkedCount: 0 }
/** 兩個頁籤各自的訂單數 + 目前頁籤篩選後的總筆數，後端算好放在 body2。 */
const summary = ref<OrderInfoVerifySummary>({ ...EMPTY_SUMMARY })

/** 送出目前的篩選條件、頁籤、分頁狀態，實際打 API 的唯一入口。 */
const load = async () => {
  loading.value = true
  try {
    const res = await api.getPOCheckView({
      customerNo: filters.customerNo,
      orderType: filters.orderType.trim(),
      startDate: toCompactDate(filters.startDate),
      endDate: toCompactDate(filters.endDate),
      tab: activeTab.value,
      pageIndex: pagination.value.pageIndex,
      // ALL_PAGE_SIZE 是前端「全部」選項的哨兵值，後端用 pageSize <= 0 代表不分頁
      pageSize: pagination.value.pageSize >= ALL_PAGE_SIZE ? 0 : pagination.value.pageSize
    })
    groups.value = res?.isSuccess ? groupOrderInfoVerifyRows(res.body ?? []) : []
    summary.value = res?.body2 ?? { ...EMPTY_SUMMARY }
    if (res && !res.isSuccess && res.message) {
      toast.add({ title: '查無資料', description: res.message, color: 'warning' })
    }
  } catch (err) {
    console.log('order-info-verify load failed -->', err)
    groups.value = []
    summary.value = { ...EMPTY_SUMMARY }
    toast.add({ title: '查詢失敗', color: 'error' })
  } finally {
    loading.value = false
  }
}

/** 篩選條件變更：跳回第一頁再查詢。分頁列自己翻頁則不會經過這裡，見 onPaginationUpdate。 */
const search = () => {
  pagination.value.pageIndex = 0
  load()
}

onMounted(() => {
  loadPermission()
  loadCustomers()
  load()
  loadConditions()
})

const onClickReset = () => {
  filters.customerNo = ''
  filters.orderType = ''
  filters.startDate = ''
  filters.endDate = ''
  search()
}

/**
 * UTable 分頁狀態變更的唯一入口（翻頁、切每頁筆數）。
 * 不用 v-model:pagination + watch，是為了避免「篩選條件改變時順手把 pageIndex
 * 歸零」又觸發一次 watch，多打一次一模一樣的 API。
 */
const onPaginationUpdate = (value?: { pageIndex: number, pageSize: number }) => {
  if (!value) return
  const sizeChanged = value.pageSize !== pagination.value.pageSize
  pagination.value = sizeChanged ? { pageIndex: 0, pageSize: value.pageSize } : value
  load()
}

const onExport = async (confirmFlag: 'Y' | 'N') => {
  exporting.value = confirmFlag
  try {
    const res = await api.exportXls({
      customerNo: filters.customerNo,
      orderType: filters.orderType.trim(),
      startDate: toCompactDate(filters.startDate),
      endDate: toCompactDate(filters.endDate),
      confirmFlag
    })
    if (!res?.isSuccess || !res.body) {
      toast.add({ title: '匯出失敗', description: res?.message ?? '', color: 'error' })
      return
    }
    const path = `/ShareRoot/${res.body}`
    const name = res.body.split('/').pop() || 'export.xlsx'
    window.open(`/api/download?path=${encodeURIComponent(path)}&name=${encodeURIComponent(name)}`, '_blank')
  } catch (err) {
    console.log('order-info-verify onExport failed -->', err)
    toast.add({ title: '匯出失敗', color: 'error' })
  } finally {
    exporting.value = null
  }
}

// ---------------------------------------------------------------- 頁籤

const activeTab = ref<'notChecked' | 'checked'>('notChecked')

const selectTab = (value: 'notChecked' | 'checked') => {
  activeTab.value = value
  search()
}

// ---------------------------------------------------------------- 欄位定義

type ColDef = { key: keyof OrderInfoVerifyGroup, header: string, amount?: boolean, numeric?: boolean }

const NUMBER_CELL = (row: OrderInfoVerifyGroup, key: keyof OrderInfoVerifyGroup) => {
  const value = row[key] as number | null | undefined
  return h('span', { class: 'block text-right tabular-nums' }, value == null ? '' : formatAmount(value))
}

const TEXT_CELL = (row: OrderInfoVerifyGroup, key: keyof OrderInfoVerifyGroup) =>
  h('span', {}, (row[key] as string | null | undefined) ?? '')

const COLS: ColDef[] = [
  { key: 'copSource', header: 'ERP來源' },
  { key: '單別名稱', header: '單別名稱' },
  { key: '單別', header: '單別' },
  { key: '單號', header: '單號' },
  { key: '訂單日期', header: '訂單日期' },
  { key: '客戶代號', header: '客戶代號' },
  { key: '客戶名稱', header: '客戶名稱' },
  { key: '部門代號', header: '部門' },
  { key: 'packinglist備註', header: 'PackingList備註' },
  { key: '客戶單號', header: '客戶單號' },
  { key: '訂單金額', header: '訂單金額', numeric: true, amount: true },
  { key: '交易條件名稱', header: '交易條件', amount: true },
  { key: '起始港口', header: '起始港口' },
  { key: '目的港口', header: '目的港口' },
  { key: '運輸方式', header: '運輸方式' },
  { key: '流程代號', header: '流程代號' },
  { key: '業務名稱', header: '業務名稱' },
  { key: '業務人員', header: '業務人員' }
]

const openOrderKey = ref<{ copSource: string, orderType: string, orderNo: string, customerNo: string } | null>(null)
const detailModalOpen = ref(false)

const openDetail = (group: OrderInfoVerifyGroup) => {
  openOrderKey.value = {
    copSource: group.copSource,
    orderType: group.單別,
    orderNo: group.單號,
    customerNo: group.客戶代號 ?? ''
  }
  detailModalOpen.value = true
}

const buildColumns = (): TableColumn<OrderInfoVerifyGroup>[] => {
  const cols: TableColumn<OrderInfoVerifyGroup>[] = [
    {
      id: 'no',
      header: '#',
      cell: ({ row }) => h('span', { class: 'block text-right text-dimmed' }, String(row.index + 1))
    }
  ]

  for (const def of COLS) {
    if (def.amount && !showAmount.value) continue
    cols.push({
      accessorKey: def.key,
      header: def.header,
      cell: ({ row }) => (def.numeric ? NUMBER_CELL(row.original, def.key) : TEXT_CELL(row.original, def.key))
    })
  }

  cols.push({
    id: 'status',
    header: '檢核結果',
    cell: ({ row }) => {
      const chk = feFinChk(row.original.copPoCheck)
      return h(resolveComponent('UBadge'), { color: chkBadgeColor(chk), variant: 'subtle' }, () => chkBadgeLabel(chk))
    }
  })

  cols.push({ id: 'actions', header: '操作' })

  return cols
}

const columns = computed(() => buildColumns())

// ---------------------------------------------------------------- 檢核條件

const conditionModalOpen = ref(false)
const conditionLoading = ref(false)
const conditionRows = ref<CopCheckRule[]>([])

const loadConditions = async () => {
  conditionLoading.value = true
  try {
    const res = await api.getConditionList()
    conditionRows.value = res?.isSuccess ? (res.body ?? []) : []
  } catch (err) {
    console.log('order-info-verify loadConditions failed -->', err)
    conditionRows.value = []
  } finally {
    conditionLoading.value = false
  }
}
</script>

<template>
  <div>
    <FullPageLoading :show="loading" />

    <UBreadcrumb v-if="false" :items="breadcrumbFor(appPath('sales-search/order-info-verify'))" class="mb-4" />

    <div class="mb-5 flex items-start justify-between gap-2">
      <div>
        <h1 class="text-2xl font-bold text-highlighted">
          訂單資料檢核
        </h1>
        <p class="mt-1 text-sm text-muted">
          依訂單單別、日期、客戶等條件查核訂單資料，含金額/信用額度檢核與特規Pass。
        </p>
      </div>
      <UButton size="sm" color="neutral" variant="outline" @click="conditionModalOpen = true">
        檢核條件
      </UButton>
    </div>

    <!-- 查詢條件 -->
    <div class="mb-4 rounded-lg border border-default bg-elevated/40 p-4">
      <div class="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-4">
        <UFormField label="訂單單別" size="sm">
          <UInput v-model="filters.orderType" placeholder="訂單單別" class="w-full" @keyup.enter="search" />
        </UFormField>

        <UFormField label="客戶別" size="sm">
          <USelectMenu
            v-model="customerNoSelectValue"
            :items="customerOptions"
            value-key="value"
            label-key="label"
            placeholder="全部客戶"
            class="w-full"
          />
        </UFormField>

        <UFormField label="訂單日期（起~迄）" size="sm" class="md:col-span-2">
          <div class="flex items-center gap-2">
            <UInput v-model="filters.startDate" type="date" class="w-full" />
            <span class="text-sm text-muted">至</span>
            <UInput v-model="filters.endDate" type="date" class="w-full" />
          </div>
        </UFormField>
      </div>

      <div class="mt-3 flex items-center justify-end gap-2">
        <UButton icon="i-lucide-rotate-cw" color="neutral" variant="outline" size="sm" @click="onClickReset">
          重設
        </UButton>
        <UButton icon="i-lucide-search" size="sm" :loading="loading" @click="search">
          查詢
        </UButton>
      </div>
    </div>

    <!-- 頁籤 -->
    <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
      <div class="flex flex-wrap gap-2">
        <UButton
          icon="i-lucide-shopping-cart"
          :color="activeTab === 'notChecked' ? 'primary' : 'neutral'"
          :variant="activeTab === 'notChecked' ? 'solid' : 'outline'"
          size="sm"
          @click="selectTab('notChecked')"
        >
          未確認訂單
          <UBadge :color="activeTab === 'notChecked' ? 'neutral' : 'primary'" variant="subtle" size="sm">
            {{ summary.notCheckedCount }}
          </UBadge>
        </UButton>
        <UButton
          icon="i-lucide-check-circle"
          :color="activeTab === 'checked' ? 'primary' : 'neutral'"
          :variant="activeTab === 'checked' ? 'solid' : 'outline'"
          size="sm"
          @click="selectTab('checked')"
        >
          已確認訂單
          <UBadge :color="activeTab === 'checked' ? 'neutral' : 'primary'" variant="subtle" size="sm">
            {{ summary.checkedCount }}
          </UBadge>
        </UButton>
      </div>
      <UButton
        icon="i-lucide-file-spreadsheet" color="success" variant="outline" size="sm"
        :loading="exporting === (activeTab === 'notChecked' ? 'N' : 'Y')"
        @click="onExport(activeTab === 'notChecked' ? 'N' : 'Y')"
      >
        輸出報表
      </UButton>
    </div>

    <div class="overflow-x-auto rounded-lg border border-default">
      <UTable
        ref="table"
        :pagination="pagination"
        :pagination-options="{ manualPagination: true, rowCount: summary.totalCount }"
        :data="groups"
        :columns="columns"
        :loading="loading"
        :ui="{ tr: clickableRowTr, td: 'whitespace-nowrap' }"
        @update:pagination="onPaginationUpdate"
        @select="(_e: Event, row: any) => openDetail(row.original)"
      >
        <template #actions-cell="{ row }">
          <div @click.stop>
            <UButton size="xs" color="primary" variant="outline" @click="openDetail(row.original)">
              檢核結果
            </UButton>
          </div>
        </template>
        <template #empty>
          <p class="py-12 text-center text-sm text-muted">
            沒有符合條件的訂單
          </p>
        </template>
      </UTable>

      <TablePaginationBar :table="table" :total="summary.totalCount" />
    </div>

    <OrderCheckDetailModal
      v-model:open="detailModalOpen"
      v-model:show-condition="conditionModalOpen"
      :order-key="openOrderKey"
      :show-amount="showAmount"
      @checked="load"
    />

    <OrderCheckConditionModal
      v-model:open="conditionModalOpen"
      :loading="conditionLoading"
      :rows="conditionRows"
    />
  </div>
</template>
