<script setup lang="ts">
import { h } from 'vue'
import type { TableColumn } from '@nuxt/ui'
import type { SalesOrderQuery } from '~/composables/useSalesShippingApi'
import type {
  CopSalesOrder,
  CopSalesOrderRow,
  SalesOrderPageSummary,
  SalesOrderTab,
  SalesShippingCustomer
} from '~/types/salesShipping'
import { isDetailRow } from '~/types/salesShipping'

definePageMeta({ title: '銷貨檢索' })

useSeoMeta({ title: '銷貨檢索 · PRORIL 業務中心' })

const api = useSalesShippingApi()
const { checkPermission } = usePermission()
const toast = useToast()
const { breadcrumbFor, appPath } = useAppNavigation()
const { pagination } = useTablePagination(20)
const table = useTemplateRef('table')

/** 1 年內資料，對照舊版 sales-shipping.js 的 _default_date = 365。 */
const DEFAULT_DAYS = 365
/** 「全部」按鈕：20 年，等於不限日期。 */
const ALL_DAYS = 365 * 20

const dateDaysAgo = (days: number) => toDateString(new Date(Date.now() - days * 24 * 60 * 60 * 1000))

const loading = ref(false)
// 不整頁遮罩，改用整頁 wait cursor 提示載入中。
useWaitCursor(loading)
const exporting = ref(false)
const showAmount = ref(false)
const customers = ref<SalesShippingCustomer[]>([])

const filters = reactive({
  customerNo: '',
  show5x: true,
  showX: true,
  productNo: '',
  productName: '',
  productSpec: '',
  serialNo: '',
  orderNo: '',
  planNum: '',
  startDate: dateDaysAgo(DEFAULT_DAYS),
  endDate: toDateString(new Date())
})

/** 目前頁籤、目前這一頁的資料（後端分頁，見 GetSalesOrderPage）。 */
const pageRows = ref<CopSalesOrderRow[]>([])

const EMPTY_SUMMARY: SalesOrderPageSummary = {
  totalCount: 0,
  productDetailCount: 0,
  productGroupCount: 0,
  soDetailCount: 0,
  soGroupCount: 0,
  totalAmount: 0
}
/** 四個頁籤筆數 + 總金額 + 目前頁籤筆數，後端算好放在 body2。 */
const summary = ref<SalesOrderPageSummary>({ ...EMPTY_SUMMARY })

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
    console.log('shipping-inquiry loadCustomers failed -->', err)
    customers.value = []
  }
}

const loadPermission = async () => {
  try {
    showAmount.value = await checkPermission(PERMISSION_KEYS.salesSearch.mixSalesShippingViewAmount)
  } catch (err) {
    console.log('shipping-inquiry loadPermission failed -->', err)
    showAmount.value = false
  }
}

const baseQuery = (): Omit<SalesOrderQuery, 'groupName'> => ({
  customerNo: filters.customerNo,
  productType: getProductType(filters.show5x, filters.showX),
  productNo: filters.productNo.trim(),
  productName: filters.productName.trim(),
  productSpec: filters.productSpec.trim(),
  startDate: toCompactDate(filters.startDate),
  endDate: toCompactDate(filters.endDate),
  serialNo: filters.serialNo.trim(),
  // 舊畫面的「訂單單號」欄位其實送的是 poNo，不是後面 orderType/orderNo
  // （那兩個只有單一銷貨單明細 modal 才會帶，用來篩單一 TH001+TH002）。
  poNo: filters.orderNo.trim(),
  inPlanNumber: filters.planNum.trim()
})

/**
 * 上次按「查詢」時的條件快照。翻頁／切頁籤／兩個明細 modal 都用它，不用畫面上
 * 改到一半還沒按查詢的條件——後端快取 key 就是這組條件，送不一樣的會對不到快取、重跑 SP。
 */
const lastQuery = ref<Omit<SalesOrderQuery, 'groupName'>>(baseQuery())

/**
 * 表格目前「顯示中」資料所屬的頁籤與起始列號。
 * 畫面不再整頁遮罩，切頁籤／翻頁時舊資料會留在表格上直到 API 回來，
 * 欄位定義、列號、整列可點都要跟著顯示中的資料走，不能跟著已經切過去的 activeTab。
 */
const shownTab = ref<SalesOrderTab>('productDetail')
const shownOffset = ref(0)

/** 每次 load 遞增；回來時不是最新一次就丟掉，避免慢的舊回應蓋掉新結果。 */
let loadSeq = 0

/**
 * 實際打 API 的唯一入口。refresh=true 會讓後端重跑兩支 SP（按查詢／重設／全部），
 * false 是翻頁、切頁籤，後端直接從快取切那一頁。
 */
const load = async (refresh: boolean) => {
  const seq = ++loadSeq
  const tab = activeTab.value
  const offset = pagination.value.pageIndex * pagination.value.pageSize
  loading.value = true
  try {
    const res = await api.getSalesOrderPage(lastQuery.value, {
      tab,
      pageIndex: pagination.value.pageIndex,
      // ALL_PAGE_SIZE 是前端「全部」選項的哨兵值，後端用 pageSize <= 0 代表不分頁
      pageSize: pagination.value.pageSize >= ALL_PAGE_SIZE ? 0 : pagination.value.pageSize,
      refresh
    })
    if (seq !== loadSeq) return

    // 查無資料時後端回 isSuccess: false + 說明訊息，不是錯誤，當空清單處理。
    pageRows.value = res?.isSuccess ? ((res.body ?? []) as CopSalesOrderRow[]) : []
    summary.value = res?.isSuccess ? (res.body2 ?? { ...EMPTY_SUMMARY }) : { ...EMPTY_SUMMARY }
    shownTab.value = tab
    shownOffset.value = offset

    if (res && !res.isSuccess && res.message) {
      toast.add({ title: '查詢無資料', description: res.message, color: 'warning' })
    }
  } catch (err) {
    console.log('shipping-inquiry load failed -->', err)
    if (seq !== loadSeq) return
    pageRows.value = []
    summary.value = { ...EMPTY_SUMMARY }
    shownTab.value = tab
    shownOffset.value = offset
    toast.add({ title: '查詢失敗', color: 'error' })
  } finally {
    if (seq === loadSeq) loading.value = false
  }
}

/** 按查詢：記下目前條件、回第一頁、重跑 SP。 */
const search = () => {
  lastQuery.value = baseQuery()
  pagination.value.pageIndex = 0
  load(true)
}

/**
 * UTable 分頁狀態變更的唯一入口（翻頁、切每頁筆數），比照未完成訂單檢索：
 * 不用 v-model:pagination + watch，避免 search() 把 pageIndex 歸零時又多打一次。
 */
const onPaginationUpdate = (value?: { pageIndex: number, pageSize: number }) => {
  if (!value) return
  const sizeChanged = value.pageSize !== pagination.value.pageSize
  pagination.value = sizeChanged ? { pageIndex: 0, pageSize: value.pageSize } : value
  load(false)
}

onMounted(() => {
  loadPermission()
  loadCustomers()
  search()
})

const onClickReset = () => {
  filters.customerNo = ''
  filters.show5x = true
  filters.showX = true
  filters.productNo = ''
  filters.productName = ''
  filters.productSpec = ''
  filters.serialNo = ''
  filters.orderNo = ''
  filters.planNum = ''
  filters.startDate = dateDaysAgo(DEFAULT_DAYS)
  filters.endDate = toDateString(new Date())
  search()
}

const onClickAll = () => {
  filters.customerNo = ''
  filters.show5x = false
  filters.showX = false
  filters.productNo = ''
  filters.productName = ''
  filters.productSpec = ''
  filters.serialNo = ''
  filters.orderNo = ''
  filters.planNum = ''
  filters.startDate = dateDaysAgo(ALL_DAYS)
  filters.endDate = toDateString(new Date())
  search()
}

const onExport = async () => {
  exporting.value = true
  try {
    const res = await api.exportXls({ ...baseQuery(), groupName: 'TH001' })
    if (!res?.isSuccess || !res.body) {
      toast.add({ title: '匯出失敗', description: res?.message ?? '', color: 'error' })
      return
    }
    openExportDownload(res.body)
  } catch (err) {
    console.log('shipping-inquiry onExport failed -->', err)
    toast.add({ title: '匯出失敗', color: 'error' })
  } finally {
    exporting.value = false
  }
}

// ---------------------------------------------------------------- 頁籤

const activeTab = ref<SalesOrderTab>('productDetail')

// 換頁籤時回到第一頁（否則在第 3 頁切到只有 1 頁的頁籤會看到空白表格），從後端快取取該頁籤。
const onClickTab = (tab: SalesOrderTab) => {
  if (tab === activeTab.value) return
  activeTab.value = tab
  pagination.value.pageIndex = 0
  load(false)
}

const tabItems = [
  { label: '品號細項', value: 'productDetail', icon: 'i-lucide-list', countKey: 'productDetailCount' },
  { label: '品號統計', value: 'productGroup', icon: 'i-lucide-chart-bar', countKey: 'productGroupCount' },
  { label: '銷貨單細項', value: 'soDetail', icon: 'i-lucide-list', countKey: 'soDetailCount' },
  { label: '銷貨單統計', value: 'soGroup', icon: 'i-lucide-chart-bar', countKey: 'soGroupCount' }
] as const

const EMPTY_TEXT: Record<SalesOrderTab, string> = {
  productDetail: '沒有符合條件的品號細項',
  productGroup: '沒有符合條件的品號統計',
  soDetail: '沒有符合條件的銷貨單細項',
  soGroup: '沒有符合條件的銷貨單統計'
}

// ---------------------------------------------------------------- 欄位定義

type ColDef = { key: string, header: string, amount?: boolean, numeric?: boolean }

const NUMBER_CELL = (row: CopSalesOrderRow, key: string) => {
  const value = (row as any)[key]
  return h('span', { class: 'block text-right tabular-nums' }, value === null || value === undefined ? '' : formatAmount(value))
}

const TEXT_CELL = (row: CopSalesOrderRow, key: string) => {
  const value = (row as any)[key]
  return h('span', {}, value ?? '')
}

const DETAIL_COLS: ColDef[] = [
  { key: 'copSource', header: 'ERP來源' },
  { key: 'customerName', header: '客戶名稱' },
  { key: 'th001', header: '銷貨單別' },
  { key: 'th002', header: '銷貨單號' },
  { key: 'th003', header: '銷貨序號' },
  { key: 'th004', header: '品號' },
  { key: 'th005', header: '品名' },
  { key: 'th006', header: '規格' },
  { key: 'th009', header: '單位' },
  { key: 'th008', header: '數量', numeric: true },
  { key: 'th012', header: '單價', numeric: true, amount: true },
  { key: 'th013', header: '數量*單價', numeric: true, amount: true },
  { key: 'tg011', header: '幣別', amount: true },
  { key: 'tg012', header: '匯率', numeric: true, amount: true },
  { key: 'th037', header: '台幣未稅', numeric: true, amount: true },
  { key: 'th038', header: '台幣稅額', numeric: true, amount: true },
  { key: 'sumAmt', header: '台幣總額', numeric: true, amount: true },
  { key: 'th014', header: '訂單單別' },
  { key: 'th015', header: '訂單單號' },
  { key: 'th016', header: '訂單序號' },
  { key: 'serialNosJson', header: '銘版序號' },
  { key: 'th018', header: '備註' },
  { key: 'ta001', header: '製令單別' },
  { key: 'ta002', header: '製令單號' },
  { key: 'planNumber', header: '計劃批號' },
  { key: 'tc012', header: '客戶單號' }
]

const PRODUCT_GROUP_COLS: ColDef[] = [
  { key: 'th004', header: '品號' },
  { key: 'th005', header: '品名' },
  { key: 'th006', header: '規格' },
  { key: 'th009', header: '單位' },
  { key: 'sumQty', header: '數量', numeric: true },
  { key: 'sumAmt', header: '台幣總額', numeric: true, amount: true }
]

const SO_GROUP_COLS: ColDef[] = [
  { key: 'customerName', header: '客戶名稱' },
  { key: 'th001', header: '銷貨單別' },
  { key: 'th002', header: '銷貨單號' },
  { key: 'sumQty', header: '數量', numeric: true },
  { key: 'sumAmt', header: '台幣總額', numeric: true, amount: true }
]

const PRODUCT_MODAL_COLS: ColDef[] = [
  { key: 'copSource', header: 'ERP來源' },
  { key: 'customerName', header: '客戶名稱' },
  { key: 'th001', header: '銷貨單別' },
  { key: 'th002', header: '銷貨單號' },
  { key: 'th003', header: '銷貨序號' },
  { key: 'th009', header: '單位' },
  { key: 'th008', header: '數量', numeric: true },
  { key: 'th037', header: '台幣未稅', numeric: true, amount: true },
  { key: 'th038', header: '台幣稅額', numeric: true, amount: true },
  { key: 'sumAmt', header: '台幣總額', numeric: true, amount: true },
  { key: 'th014', header: '訂單單別' },
  { key: 'th015', header: '訂單單號' },
  { key: 'th016', header: '訂單序號' },
  { key: 'serialNosJson', header: '銘版序號' },
  { key: 'ta001', header: '製令單別' },
  { key: 'ta002', header: '製令單號' },
  { key: 'planNumber', header: '計劃批號' }
]

const SO_MODAL_COLS: ColDef[] = [
  { key: 'copSource', header: 'ERP來源' },
  { key: 'customerName', header: '客戶名稱' },
  { key: 'th004', header: '品號' },
  { key: 'th005', header: '品名' },
  { key: 'th006', header: '規格' },
  { key: 'th003', header: '銷貨序號' },
  { key: 'th009', header: '單位' },
  { key: 'sumQty', header: '數量', numeric: true },
  { key: 'th037', header: '台幣未稅', numeric: true, amount: true },
  { key: 'th038', header: '台幣稅額', numeric: true, amount: true },
  { key: 'sumAmt', header: '台幣總額', numeric: true, amount: true },
  { key: 'th014', header: '訂單單別' },
  { key: 'th015', header: '訂單單號' },
  { key: 'th016', header: '訂單序號' },
  { key: 'serialNosJson', header: '銘版序號' },
  { key: 'ta001', header: '製令單別' },
  { key: 'ta002', header: '製令單號' },
  { key: 'planNumber', header: '計劃批號' }
]

/**
 * paged = true 是外層四個頁籤（後端分頁，row.index 只是當頁第幾列，要加上前面幾頁的筆數），
 * 明細 modal 是一次全撈，不用加。
 */
const buildColumns = (defs: ColDef[], amountAllowed: boolean, withAction?: string, paged = false): TableColumn<CopSalesOrderRow>[] => {
  const cols: TableColumn<CopSalesOrderRow>[] = [
    {
      id: 'no',
      header: '#',
      cell: ({ row }) => {
        const offset = paged ? shownOffset.value : 0
        return h('span', { class: 'block text-right text-dimmed' }, String(offset + row.index + 1))
      }
    }
  ]

  for (const def of defs) {
    if (def.amount && !amountAllowed) continue
    cols.push({
      accessorKey: def.key,
      header: def.header,
      cell: ({ row }) => (def.numeric ? NUMBER_CELL(row.original, def.key) : TEXT_CELL(row.original, def.key))
    })
  }

  if (withAction) {
    cols.push({ id: 'actions', header: withAction })
  }

  return cols
}

const detailColumns = computed(() => buildColumns(DETAIL_COLS, showAmount.value, undefined, true))
const productGroupColumns = computed(() => buildColumns(PRODUCT_GROUP_COLS, showAmount.value, '內容', true))
const soGroupColumns = computed(() => buildColumns(SO_GROUP_COLS, showAmount.value, '內容', true))

/** 四個頁籤共用一個 UTable，欄位依顯示中資料的頁籤切換（兩個細項頁籤欄位相同）。 */
const activeColumns = computed(() => ({
  productDetail: detailColumns.value,
  productGroup: productGroupColumns.value,
  soDetail: detailColumns.value,
  soGroup: soGroupColumns.value
})[shownTab.value])
const productModalColumns = computed(() => buildColumns(PRODUCT_MODAL_COLS, showAmount.value))
const soModalColumns = computed(() => buildColumns(SO_MODAL_COLS, showAmount.value))

// ---------------------------------------------------------------- 明細 modal

const productModalOpen = ref(false)
const productModalLoading = ref(false)
const productModalRows = ref<CopSalesOrder[]>([])
const productModalFields = ref<{ label: string, value: string }[]>([])
const productModalSum = ref<number | null>(null)

const openProductDetail = async (row: CopSalesOrderRow) => {
  productModalFields.value = [
    { label: '品號', value: row.th004 ?? '' },
    { label: '品名', value: row.th005 ?? '' },
    { label: '規格', value: row.th006 ?? '' }
  ]
  productModalSum.value = row.sumAmt ?? null
  productModalOpen.value = true
  productModalLoading.value = true
  try {
    const res = await api.getSalesOrder1({
      ...lastQuery.value,
      productNo: row.th004 ?? '',
      groupName: 'TH001'
    })
    productModalRows.value = res?.isSuccess ? (res.body ?? []).filter(r => isDetailRow(r.footerFlag)) : []
  } catch (err) {
    console.log('shipping-inquiry openProductDetail failed -->', err)
    productModalRows.value = []
    toast.add({ title: '讀取品號明細失敗', color: 'error' })
  } finally {
    productModalLoading.value = false
  }
}

const soModalOpen = ref(false)
const soModalLoading = ref(false)
const soModalRows = ref<CopSalesOrder[]>([])
const soModalFields = ref<{ label: string, value: string }[]>([])
const soModalSum = ref<number | null>(null)

const openSoDetail = async (row: CopSalesOrderRow) => {
  soModalFields.value = [
    { label: '銷貨單別', value: row.th001 ?? '' },
    { label: '銷貨單號', value: row.th002 ?? '' },
    { label: '客戶名稱', value: row.customerName ?? '' }
  ]
  soModalSum.value = row.sumAmt ?? null
  soModalOpen.value = true
  soModalLoading.value = true
  try {
    const res = await api.getSalesOrder1({
      ...lastQuery.value,
      orderType: row.th001 ?? '',
      orderNo: row.th002 ?? '',
      groupName: 'TH001'
    })
    soModalRows.value = res?.isSuccess ? (res.body ?? []).filter(r => isDetailRow(r.footerFlag)) : []
  } catch (err) {
    console.log('shipping-inquiry openSoDetail failed -->', err)
    soModalRows.value = []
    toast.add({ title: '讀取銷貨單明細失敗', color: 'error' })
  } finally {
    soModalLoading.value = false
  }
}

/** 品號統計／銷貨單統計有明細 modal，細項兩個頁籤沒有。 */
const isGroupTab = computed(() => shownTab.value === 'productGroup' || shownTab.value === 'soGroup')

const openGroupDetail = (row: CopSalesOrderRow) =>
  shownTab.value === 'productGroup' ? openProductDetail(row) : openSoDetail(row)
</script>

<template>
  <div class="flex min-h-0 flex-1 flex-col">
    <!--
      整頁撐滿右側面板（UDashboardPanel body 是 flex-col），表格吃掉剩下的高度、自己捲動，
      面板外框不出現捲軸。畫面太矮時表格至少保留 16rem，才退回由面板捲動。
    -->
    <!-- 不用 FullPageLoading 整頁遮罩：查詢條件與頁籤一開始就可操作，下方表格等 API 回來才更新。 -->
    <UBreadcrumb v-if="false" :items="breadcrumbFor(appPath('sales-search/shipping-inquiry'))" class="mb-4" />

    <!-- 查詢條件 -->
    <div class="mb-4 rounded-lg border border-default bg-elevated/40 p-4">
      <!-- 操作列放在查詢區塊最上方（欄位已排滿整列，沒有空位跟欄位同一行） -->
      <div class="mb-3 flex items-center justify-between gap-2">
        <p v-if="showAmount" class="text-sm">
          總金額 NT
          <span class="font-semibold text-highlighted">{{ formatAmount(summary.totalAmount) || '0' }}</span>
        </p>
        <p v-else class="text-xs text-muted">
          無金額欄位檢視權限
        </p>
        <div class="flex items-center gap-2">
          <UButton icon="i-lucide-list-x" color="neutral" variant="outline" size="sm" @click="onClickAll">
            全部
          </UButton>
          <UButton icon="i-lucide-rotate-cw" color="neutral" variant="outline" size="sm" @click="onClickReset">
            重設
          </UButton>
          <UButton icon="i-lucide-search" size="sm" :loading="loading" @click="search">
            查詢
          </UButton>
          <UButton icon="i-lucide-file-spreadsheet" color="success" variant="outline" size="sm" :loading="exporting" @click="onExport">
            輸出報表
          </UButton>
        </div>
      </div>

      <div class="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-4">
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

        <UFormField label="期間（起）" size="sm">
          <UInput v-model="filters.startDate" type="date" class="w-full" />
        </UFormField>

        <UFormField label="期間（迄）" size="sm">
          <UInput v-model="filters.endDate" type="date" class="w-full" />
        </UFormField>

        <UFormField label="品號種類" size="sm">
          <div class="flex h-full items-center gap-4">
            <UCheckbox v-model="filters.show5x" label="成品(5開頭)" />
            <UCheckbox v-model="filters.showX" label="零件(x開頭)" />
          </div>
        </UFormField>

        <UFormField label="品號" size="sm">
          <ClearInput v-model="filters.productNo" placeholder="品號" class="w-full" @keyup.enter="search" />
        </UFormField>

        <UFormField label="品名" size="sm">
          <ClearInput v-model="filters.productName" placeholder="品名" class="w-full" @keyup.enter="search" />
        </UFormField>

        <UFormField label="規格" size="sm">
          <ClearInput v-model="filters.productSpec" placeholder="規格" class="w-full" @keyup.enter="search" />
        </UFormField>

        <UFormField label="序號" size="sm">
          <ClearInput v-model="filters.serialNo" placeholder="銘版序號" class="w-full" @keyup.enter="search" />
        </UFormField>

        <UFormField label="訂單單號" size="sm">
          <ClearInput v-model="filters.orderNo" placeholder="訂單單號" class="w-full" @keyup.enter="search" />
        </UFormField>

        <UFormField label="計畫批號" size="sm">
          <ClearInput v-model="filters.planNum" placeholder="計畫批號" class="w-full" @keyup.enter="search" />
        </UFormField>
      </div>
    </div>

    <!-- 頁籤 -->
    <div class="mb-3 flex flex-wrap gap-2">
      <UButton
        v-for="tab in tabItems"
        :key="tab.value"
        :icon="tab.icon"
        :color="activeTab === tab.value ? 'primary' : 'neutral'"
        :variant="activeTab === tab.value ? 'solid' : 'outline'"
        size="sm"
        @click="onClickTab(tab.value)"
      >
        {{ tab.label }}
        <UBadge
          :label="String(summary[tab.countKey])"
          :color="activeTab === tab.value ? 'neutral' : 'primary'"
          variant="soft"
          size="sm"
        />
      </UButton>
    </div>

    <!--
      統計兩個頁籤有明細 modal，整列可點；細項兩個頁籤沒有，不掛。
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
        :data="pageRows"
        :columns="activeColumns"
        :loading="loading"
        :ui="{ tr: isGroupTab ? clickableRowTr : '', td: 'whitespace-nowrap' }"
        @update:pagination="onPaginationUpdate"
        @select="(_e: Event, row: any) => isGroupTab && openGroupDetail(row.original)"
      >
        <template #actions-cell="{ row }">
          <div @click.stop>
            <UButton size="xs" color="primary" variant="outline" @click="openGroupDetail(row.original)">
              內容
            </UButton>
          </div>
        </template>
        <template #empty>
          <p class="py-12 text-center text-sm text-muted">
            {{ EMPTY_TEXT[shownTab] }}
          </p>
        </template>
      </UTable>

      <TablePaginationBar :table="table" :total="summary.totalCount" />
    </div>

    <QueryDetailModal
      v-model:open="productModalOpen"
      title="單一品號明細"
      :fields="productModalFields"
      :summary-amount="productModalSum"
      :show-amount="showAmount"
      :loading="productModalLoading"
      :rows="productModalRows as CopSalesOrderRow[]"
      :columns="productModalColumns"
    />

    <QueryDetailModal
      v-model:open="soModalOpen"
      title="單一銷貨單明細"
      :fields="soModalFields"
      :summary-amount="soModalSum"
      :show-amount="showAmount"
      :loading="soModalLoading"
      :rows="soModalRows as CopSalesOrderRow[]"
      :columns="soModalColumns"
    />
  </div>
</template>
