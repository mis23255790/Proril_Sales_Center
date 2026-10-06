<script setup lang="ts">
import { h, resolveComponent } from 'vue'
import type { TableColumn } from '@nuxt/ui'
import type { CopCheckRule, OrderInfoVerifyGroup, OrderInfoVerifySummary, VPoDetail } from '~/types/orderInfoVerify'
import type { SalesShippingCustomer } from '~/types/salesShipping'
import { ORDER_ROW_STATUS, feFinChk, groupOrderInfoVerifyRows, isOrderAmountAlert, orderRowStatus } from '~/utils/orderInfoVerify'

definePageMeta({ title: '訂單資料檢核' })

useSeoMeta({ title: '訂單資料檢核 · PRORIL 業務中心' })

const api = useOrderInfoVerifyApi()
const { checkPermission } = usePermission()
const toast = useToast()
const { breadcrumbFor, appPath } = useAppNavigation()
const { pagination } = useTablePagination(20)
const table = useTemplateRef('table')

const loading = ref(false)
// 不整頁遮罩，改用整頁 wait cursor 提示載入中。
useWaitCursor(loading)
const exporting = ref<'Y' | 'N' | null>(null)
const showAmount = ref(false)
const customers = ref<SalesShippingCustomer[]>([])

/** 訂單日期預設昨天～今天，對照舊版 UI_InitQueryDate(..., _default_date = 1)。 */
const DEFAULT_DAYS = 1

const dateDaysAgo = (days: number) => toDateString(new Date(Date.now() - days * 24 * 60 * 60 * 1000))

const filters = reactive({
  customerNo: '',
  orderType: '',
  startDate: dateDaysAgo(DEFAULT_DAYS),
  endDate: toDateString(new Date())
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

/**
 * 每次 load 遞增；回來時不是最新一次就丟掉，避免慢的舊回應蓋掉新結果。
 * 畫面不再整頁遮罩，等待中仍可切頁籤／翻頁／再按查詢，所以一定要擋。
 */
let loadSeq = 0

/** 送出目前的篩選條件、頁籤、分頁狀態，實際打 API 的唯一入口。 */
const load = async () => {
  const seq = ++loadSeq
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
    if (seq !== loadSeq) return
    groups.value = res?.isSuccess ? groupOrderInfoVerifyRows(res.body ?? []) : []
    // 換資料就收起展開列（列 id 是 index，不收會展開到別張訂單）
    expanded.value = {}
    summary.value = res?.body2 ?? { ...EMPTY_SUMMARY }
    if (res && !res.isSuccess && res.message) {
      toast.add({ title: '查無資料', description: res.message, color: 'warning' })
    }
  } catch (err) {
    console.log('order-info-verify load failed -->', err)
    if (seq !== loadSeq) return
    groups.value = []
    summary.value = { ...EMPTY_SUMMARY }
    toast.add({ title: '查詢失敗', color: 'error' })
  } finally {
    if (seq === loadSeq) loading.value = false
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
  filters.startDate = dateDaysAgo(DEFAULT_DAYS)
  filters.endDate = toDateString(new Date())
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
    openExportDownload(res.body)
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

/**
 * 欄位順序與名稱對照 1.0 Views/Mix/OrderInfoVerify.cshtml 的 table-order-notchecked/checked
 * （兩個頁籤欄位相同）。1.0 的 FinChk/feFinChk 是除錯用的原始值欄，2.0 改成「檢核結果」燈號；
 * 「編輯」在 1.0 是夾在目的港口與運輸方式中間，這裡照放。
 * value 有給就用它取值（客戶金額在 copPoCheck 裡，不在訂單表頭）。
 */
type ColDef = {
  id: string
  header: string
  value?: (row: OrderInfoVerifyGroup) => string | number | null | undefined
  amount?: boolean
  numeric?: boolean
  /** 金額欄紅底（訂單金額／客戶金額），對照舊版 cellStyle。 */
  amountAlert?: boolean
}

const STATUS_COL = '__status'
const ACTIONS_COL = '__actions'

const COLS: (ColDef | typeof STATUS_COL | typeof ACTIONS_COL)[] = [
  // 來源／單別名稱／單別／單號：1.0 欄位定義有，但實際畫面不顯示（依欄位設定隱藏），
  // 單別／單號在展開列的品號明細裡看得到。
  { id: '訂單日期', header: '訂單日期' },
  { id: '客戶名稱', header: '客戶名稱' },
  { id: '部門代號', header: '部門' },
  { id: 'packinglist備註', header: 'PackingList備註' },
  { id: '客戶單號', header: '客戶單號' },
  { id: '訂單金額', header: '訂單金額', numeric: true, amount: true, amountAlert: true },
  { id: 'custAmt', header: '客戶金額', value: r => r.copPoCheck?.custAmt, numeric: true, amount: true, amountAlert: true },
  { id: '交易條件', header: '交易條件', amount: true },
  { id: '交易條件名稱', header: '交易條件名稱', amount: true },
  { id: '起始港口', header: '起始港口' },
  { id: '目的港口', header: '目的港口' },
  STATUS_COL,
  ACTIONS_COL,
  { id: '運輸方式', header: '運輸方式' },
  { id: '流程代號', header: '流程代號' },
  { id: '業務名稱', header: '業務名稱' },
  { id: '業務人員', header: '業務人員' }
]

const cellValue = (row: OrderInfoVerifyGroup, def: ColDef) =>
  def.value ? def.value(row) : (row as any)[def.id] as string | number | null | undefined

const NUMBER_CELL = (value: unknown) =>
  h('span', { class: 'block text-right tabular-nums' }, value == null || value === '' ? '' : formatAmount(value as number))

const TEXT_CELL = (value: unknown) => h('span', {}, (value as string | null | undefined) ?? '')

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

/** 展開列狀態（1.0 的 exp 欄：點放大鏡在列下方展開該訂單的品號明細）。 */
const expanded = ref<Record<string, boolean>>({})

/** 展開列裡的品號明細欄位，對照 1.0 get_detail_work_record_head。 */
const DETAIL_COLS: { header: string, value: (d: VPoDetail) => unknown, numeric?: boolean, amount?: boolean }[] = [
  { header: '單別', value: d => d.單別 },
  { header: '單號', value: d => d.單號 },
  { header: '序號', value: d => d.序號 },
  { header: '品號', value: d => d.品號 },
  { header: '品名', value: d => d.品名 },
  { header: '規格', value: d => d.規格 },
  { header: '幣別', value: d => d.幣別, amount: true },
  { header: '匯率', value: d => d.匯率, numeric: true, amount: true },
  { header: '訂單數量', value: d => d.訂單數量, numeric: true },
  { header: '單位', value: d => d.單位 },
  // 1.0 表頭寫「本幣單價／本幣金額」，但欄位對不到資料（一直是空的），這裡顯示實際有的外幣單價／外幣金額
  { header: '外幣單價', value: d => d.外幣單價, numeric: true, amount: true },
  { header: '外幣金額', value: d => d.外幣金額, numeric: true, amount: true },
  { header: '台幣金額', value: d => d.台幣金額, numeric: true, amount: true },
  { header: '預交日', value: d => d.預交日 },
  // 1.0 表頭是 FinFlag，實際是 ERP 訂單明細結案碼（COPTD.TD016）
  { header: '結案碼', value: d => d.finFlag }
]

const detailCols = computed(() => DETAIL_COLS.filter(c => !c.amount || showAmount.value))

const buildColumns = (): TableColumn<OrderInfoVerifyGroup>[] => {
  const cols: TableColumn<OrderInfoVerifyGroup>[] = [
    { id: 'expand', header: '' },
    {
      id: 'no',
      header: '#',
      cell: ({ row }) => h('span', { class: 'block text-right text-dimmed' }, String(row.index + 1))
    }
  ]

  for (const def of COLS) {
    if (def === STATUS_COL) {
      cols.push({
        id: 'status',
        header: '檢核結果',
        cell: ({ row }) => h(resolveComponent('CheckLight'), { chk: feFinChk(row.original.copPoCheck) })
      })
      continue
    }
    if (def === ACTIONS_COL) {
      cols.push({ id: 'actions', header: '編輯' })
      continue
    }
    if (def.amount && !showAmount.value) continue
    cols.push({
      id: def.id,
      header: def.header,
      cell: ({ row }) => (def.numeric ? NUMBER_CELL(cellValue(row.original, def)) : TEXT_CELL(cellValue(row.original, def))),
      ...(def.amountAlert
        ? { meta: { class: { td: (cell: any) => (isOrderAmountAlert(cell.row.original.copPoCheck) ? 'bg-[#f8ccc8]' : '') } } }
        : {})
    })
  }

  return cols
}

const columns = computed(() => buildColumns())

/** 整列底色依檢核狀態（需修改／未檢核／特規Pass／正確），對照舊版 rowStylePO。 */
const tableMeta = {
  class: { tr: (row: any) => ORDER_ROW_STATUS[orderRowStatus(row.original.copPoCheck)].class }
}

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
  <div class="flex min-h-0 flex-1 flex-col">
    <!--
      整頁撐滿右側面板（UDashboardPanel body 是 flex-col），表格吃掉剩下的高度、自己捲動，
      面板外框不出現捲軸。畫面太矮時表格至少保留 16rem，才退回由面板捲動。
    -->
    <!-- 不用 FullPageLoading 整頁遮罩：查詢條件與頁籤一開始就可操作，下方表格等 API 回來才更新。 -->
    <UBreadcrumb v-if="false" :items="breadcrumbFor(appPath('sales-search/order-info-verify'))" class="mb-4" />

    <!-- 查詢條件 -->
    <div class="mb-4 rounded-lg border border-default bg-elevated/40 p-4">
      <!-- 操作列放在查詢區塊最上方（欄位已排滿整列，沒有空位跟欄位同一行） -->
      <div class="mb-3 flex items-center justify-end gap-2">
        <UButton icon="i-lucide-rotate-cw" color="neutral" variant="outline" size="sm" @click="onClickReset">
          重設
        </UButton>
        <UButton icon="i-lucide-search" size="sm" :loading="loading" @click="search">
          查詢
        </UButton>
      </div>

      <div class="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-4">
        <UFormField label="訂單單別" size="sm">
          <ClearInput v-model="filters.orderType" placeholder="訂單單別" class="w-full" @keyup.enter="search" />
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

    <!--
      表頭 sticky：外層不能再包 overflow-x-auto（會變成另一個捲動容器讓 sticky 失效），
      改由 UTable 自己的根節點（預設 overflow-auto）捲動；高度由 flex-1 撐滿剩餘空間，不用固定 max-h。
    -->
    <div class="flex min-h-64 flex-1 flex-col overflow-hidden rounded-lg border border-default">
      <UTable
        ref="table"
        sticky
        class="min-h-0 flex-1"
        :pagination="pagination"
        :pagination-options="{ manualPagination: true, rowCount: summary.totalCount }"
        :data="groups"
        :columns="columns"
        :loading="loading"
        v-model:expanded="expanded"
        :meta="tableMeta"
        :ui="{ tr: clickableRowTr, td: 'whitespace-nowrap' }"
        @update:pagination="onPaginationUpdate"
        @select="(_e: Event, row: any) => openDetail(row.original)"
      >
        <template #expand-cell="{ row }">
          <div @click.stop>
            <UButton
              size="xs" color="success" variant="outline"
              :icon="row.getIsExpanded() ? 'i-lucide-zoom-out' : 'i-lucide-zoom-in'"
              :title="row.getIsExpanded() ? '收合品號明細' : '展開品號明細'"
              @click="row.toggleExpanded()"
            />
          </div>
        </template>
        <!-- 品號明細：外層列 hover 會把底下所有 td 加底線、游標變手指，這裡強制蓋掉 -->
        <template #expanded="{ row }">
          <div class="cursor-default overflow-x-auto rounded-md border border-default bg-[#d3d3d3]/30 p-2" @click.stop>
            <table class="w-full text-xs">
              <thead>
                <tr class="text-left text-muted">
                  <th class="px-2 py-1 text-right">
                    #
                  </th>
                  <th v-for="col in detailCols" :key="col.header" class="px-2 py-1" :class="col.numeric ? 'text-right' : ''">
                    {{ col.header }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="(item, i) in (row.original as OrderInfoVerifyGroup).rows"
                  :key="item.vPoDetail.序號"
                  class="border-t border-default"
                >
                  <td class="px-2 py-1 text-right text-dimmed !no-underline">
                    {{ i + 1 }}
                  </td>
                  <td
                    v-for="col in detailCols"
                    :key="col.header"
                    class="px-2 py-1 !no-underline"
                    :class="col.numeric ? 'text-right tabular-nums' : ''"
                  >
                    {{ col.numeric ? formatAmount(col.value(item.vPoDetail) as number) : (col.value(item.vPoDetail) ?? '') }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </template>
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

    <!-- 表格下方：最左邊檢核條件按鈕，接著底色說明（對照舊版 footer-description：文字直接放在對應底色上） -->
    <div class="mt-2 flex flex-wrap items-center gap-2 text-xs">
      <UButton size="xs" color="neutral" variant="outline" icon="i-lucide-list-checks" class="me-2" @click="conditionModalOpen = true">
        檢核條件
      </UButton>
      <span class="text-muted">底色說明：</span>
      <span
        v-for="(status, key) in ORDER_ROW_STATUS"
        :key="key"
        class="rounded border border-default px-2 py-0.5 text-default"
        :class="status.class"
      >
        {{ status.label }}
      </span>
      <span class="text-muted">；訂單金額欄紅底 = 訂單金額低於客戶金額或客戶金額檢核不通過</span>
    </div>

    <OrderCheckDetailModal
      v-model:open="detailModalOpen"
      :order-key="openOrderKey"
      :show-amount="showAmount"
      :condition-loading="conditionLoading"
      :condition-rows="conditionRows"
      @checked="load"
    />

    <OrderCheckConditionModal
      v-model:open="conditionModalOpen"
      :loading="conditionLoading"
      :rows="conditionRows"
    />
  </div>
</template>
