<script setup lang="ts">
import { h } from 'vue'
import type { TableColumn } from '@nuxt/ui'
import type { UnfinOrderQuery } from '~/composables/useSalesOrderUnfinishApi'
import {
  type UnfinOrder,
  type UnfinOrderPageSummary,
  type UnfinOrderRow,
  type UnfinOrderTab,
  isUnfinishDetailRow
} from '~/types/salesOrderUnfinish'
import type { SalesShippingCustomer } from '~/types/salesShipping'

definePageMeta({ title: '未完成訂單檢索' })

useSeoMeta({ title: '未完成訂單檢索 · PRORIL 業務中心' })

const api = useSalesOrderUnfinishApi()
const { checkPermission } = usePermission()
const toast = useToast()
const { breadcrumbFor, appPath } = useAppNavigation()
const { pagination } = useTablePagination(20)
const table = useTemplateRef('table')

/** 90 天內資料，對照舊版 UI_InitQueryDate(..., 90)。 */
const DEFAULT_DAYS = 90

const dateDaysAgo = (days: number) => toDateString(new Date(Date.now() - days * 24 * 60 * 60 * 1000))

/** 查詢條件區塊縮小高度：label 與輸入框間距收窄。 */
const FIELD_UI = { container: 'mt-0.5' }

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
  orderType: '',
  orderNo: '',
  planNum: '',
  startDate: dateDaysAgo(DEFAULT_DAYS),
  endDate: toDateString(new Date()),
  // 預交日期舊版預設不設定，不套用此條件過濾。
  deliveryStartDate: '',
  deliveryEndDate: ''
})

/** 目前頁籤、目前這一頁的資料（後端分頁，見 GetUnfinOrderPage）。 */
const pageRows = ref<UnfinOrderRow[]>([])

const EMPTY_SUMMARY: UnfinOrderPageSummary = {
  totalCount: 0,
  productDetailCount: 0,
  productGroupCount: 0,
  soDetailCount: 0,
  soGroupCount: 0,
  totalAmount: 0
}
/** 四個頁籤筆數 + 總金額 + 目前頁籤筆數，後端算好放在 body2。 */
const summary = ref<UnfinOrderPageSummary>({ ...EMPTY_SUMMARY })

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
    console.log('unfinished-orders loadCustomers failed -->', err)
    customers.value = []
  }
}

const loadPermission = async () => {
  try {
    showAmount.value = await checkPermission(PERMISSION_KEYS.salesSearch.queryUnFinishViewAmount)
  } catch (err) {
    console.log('unfinished-orders loadPermission failed -->', err)
    showAmount.value = false
  }
}

const baseQuery = (): Omit<UnfinOrderQuery, 'groupName'> => ({
  customerNo: filters.customerNo,
  productType: getProductType(filters.show5x, filters.showX),
  productNo: filters.productNo.trim(),
  productName: filters.productName.trim(),
  productSpec: filters.productSpec.trim(),
  startDate: toCompactDate(filters.startDate),
  endDate: toCompactDate(filters.endDate),
  deliveryStartDate: toCompactDate(filters.deliveryStartDate),
  deliveryEndDate: toCompactDate(filters.deliveryEndDate),
  serialNo: filters.serialNo.trim(),
  poNo: filters.orderNo.trim(),
  orderType: filters.orderType.trim(),
  inPlanNumber: filters.planNum.trim()
})

/**
 * 上次按「查詢」時的條件快照。翻頁／切頁籤／兩個明細 modal 都用它，不用畫面上
 * 改到一半還沒按查詢的條件——後端快取 key 就是這組條件，送不一樣的會對不到快取、重跑 SP。
 */
const lastQuery = ref<Omit<UnfinOrderQuery, 'groupName'>>(baseQuery())

/**
 * 表格目前「顯示中」資料所屬的頁籤與起始列號。
 * 畫面不再整頁遮罩，切頁籤／翻頁時舊資料會留在表格上直到 API 回來，
 * 欄位定義、列號、整列可點都要跟著顯示中的資料走，不能跟著已經切過去的 activeTab。
 */
const shownTab = ref<UnfinOrderTab>('productDetail')
const shownOffset = ref(0)

/** 每次 load 遞增；回來時不是最新一次就丟掉，避免慢的舊回應蓋掉新結果。 */
let loadSeq = 0

/**
 * 實際打 API 的唯一入口。refresh=true 會讓後端重跑兩支 SP（按查詢／重設），
 * false 是翻頁、切頁籤，後端直接從快取切那一頁。
 */
const load = async (refresh: boolean) => {
  const seq = ++loadSeq
  const tab = activeTab.value
  const offset = pagination.value.pageIndex * pagination.value.pageSize
  loading.value = true
  try {
    const res = await api.getUnfinOrderPage(lastQuery.value, {
      tab,
      pageIndex: pagination.value.pageIndex,
      // ALL_PAGE_SIZE 是前端「全部」選項的哨兵值，後端用 pageSize <= 0 代表不分頁
      pageSize: pagination.value.pageSize >= ALL_PAGE_SIZE ? 0 : pagination.value.pageSize,
      refresh
    })
    if (seq !== loadSeq) return

    // 查無資料時後端回 isSuccess: false + 說明訊息，不是錯誤，當空清單處理。
    pageRows.value = res?.isSuccess ? ((res.body ?? []) as UnfinOrderRow[]) : []
    summary.value = res?.isSuccess ? (res.body2 ?? { ...EMPTY_SUMMARY }) : { ...EMPTY_SUMMARY }
    shownTab.value = tab
    shownOffset.value = offset

    if (res && !res.isSuccess && res.message) {
      toast.add({ title: '查詢無資料', description: res.message, color: 'warning' })
    }
  } catch (err) {
    console.log('unfinished-orders load failed -->', err)
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
 * UTable 分頁狀態變更的唯一入口（翻頁、切每頁筆數），比照訂單資料檢核：
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
  filters.orderType = ''
  filters.orderNo = ''
  filters.planNum = ''
  filters.startDate = dateDaysAgo(DEFAULT_DAYS)
  filters.endDate = toDateString(new Date())
  filters.deliveryStartDate = ''
  filters.deliveryEndDate = ''
  search()
}

const onClickClearOrderDate = () => {
  filters.startDate = ''
  filters.endDate = ''
}

const onClickClearDeliveryDate = () => {
  filters.deliveryStartDate = ''
  filters.deliveryEndDate = ''
}

const onExport = async () => {
  exporting.value = true
  try {
    const res = await api.exportXls({ ...baseQuery(), groupName: 'TC001' })
    if (!res?.isSuccess || !res.body) {
      toast.add({ title: '匯出失敗', description: res?.message ?? '', color: 'error' })
      return
    }
    const path = `/ShareRoot/${res.body}`
    const name = res.body.split('/').pop() || 'export.xlsx'
    window.open(`/api/download?path=${encodeURIComponent(path)}&name=${encodeURIComponent(name)}`, '_blank')
  } catch (err) {
    console.log('unfinished-orders onExport failed -->', err)
    toast.add({ title: '匯出失敗', color: 'error' })
  } finally {
    exporting.value = false
  }
}

// ---------------------------------------------------------------- 頁籤

const activeTab = ref<UnfinOrderTab>('productDetail')

// 換頁籤時回到第一頁（否則在第 3 頁切到只有 1 頁的頁籤會看到空白表格），從後端快取取該頁籤。
const onClickTab = (tab: UnfinOrderTab) => {
  if (tab === activeTab.value) return
  activeTab.value = tab
  pagination.value.pageIndex = 0
  load(false)
}

const tabItems = [
  { label: '品號細項', value: 'productDetail', icon: 'i-lucide-list', countKey: 'productDetailCount' },
  { label: '品號統計', value: 'productGroup', icon: 'i-lucide-chart-bar', countKey: 'productGroupCount' },
  { label: '訂單細項', value: 'soDetail', icon: 'i-lucide-list', countKey: 'soDetailCount' },
  { label: '訂單統計', value: 'soGroup', icon: 'i-lucide-chart-bar', countKey: 'soGroupCount' }
] as const

const EMPTY_TEXT: Record<UnfinOrderTab, string> = {
  productDetail: '沒有符合條件的品號細項',
  productGroup: '沒有符合條件的品號統計',
  soDetail: '沒有符合條件的訂單細項',
  soGroup: '沒有符合條件的訂單統計'
}

// ---------------------------------------------------------------- 欄位定義

type ColDef = { key: string, header: string, amount?: boolean, numeric?: boolean }

const NUMBER_CELL = (row: UnfinOrderRow, key: string) => {
  const value = (row as any)[key]
  return h('span', { class: 'block text-right tabular-nums' }, value === null || value === undefined ? '' : formatAmount(value))
}

const TEXT_CELL = (row: UnfinOrderRow, key: string) => {
  const value = (row as any)[key]
  return h('span', {}, value ?? '')
}

/** 品號細項／訂單細項共用的欄位，訂單細項比這個多一欄「贈品量」(td024)。 */
const DETAIL_COLS_BASE: ColDef[] = [
  { key: 'tc001', header: '訂單單別' },
  { key: 'tc002', header: '訂單單號' },
  { key: 'td003', header: '訂單序號' },
  { key: 'tc003', header: '訂單日期' },
  { key: 'td013', header: '預交日' },
  { key: 'tc004', header: '客戶代號' },
  { key: 'ma002', header: '客戶名稱' },
  { key: 'tc019', header: '運輸方式' },
  { key: 'td004', header: '品號' },
  { key: 'td005', header: '品名' },
  { key: 'td006', header: '規格' },
  { key: 'td008', header: '訂單數量', numeric: true },
  { key: 'td010', header: '單位' },
  { key: 'td011', header: '原幣單價', numeric: true, amount: true },
  { key: 'td012', header: '原幣金額', numeric: true, amount: true },
  { key: 'tc008', header: '幣別', amount: true },
  { key: 'tc009', header: '匯率', numeric: true, amount: true },
  { key: 'ntd', header: '台幣金額', numeric: true, amount: true },
  { key: 'planNumber', header: '計畫批號' },
  { key: 'copSource', header: 'ERP' },
  { key: 'mq002', header: '單別名稱' },
  { key: 'tc006', header: '業務人員' },
  { key: 'mv002', header: '業務名稱' },
  { key: 'tc010', header: '送貨地址' },
  { key: 'tc014', header: '付款條件', amount: true },
  { key: 'tc016', header: '課稅別', amount: true },
  { key: 'serialNosJson', header: '銘版序號' }
]

const PRODUCT_DETAIL_COLS = DETAIL_COLS_BASE

const SO_DETAIL_COLS: ColDef[] = [
  ...DETAIL_COLS_BASE,
  { key: 'td024', header: '贈品量', numeric: true }
]

const PRODUCT_GROUP_COLS: ColDef[] = [
  { key: 'td004', header: '品號' },
  { key: 'td005', header: '品名' },
  { key: 'td006', header: '規格' },
  { key: 'td010', header: '單位' },
  { key: 'td008', header: '數量', numeric: true },
  { key: 'ntd', header: '台幣總額', numeric: true, amount: true }
]

const SO_GROUP_COLS: ColDef[] = [
  { key: 'tc001', header: '訂單單別' },
  { key: 'tc002', header: '訂單單號' },
  { key: 'td003', header: '訂單序號' },
  { key: 'tc003', header: '訂單日期' },
  { key: 'td013', header: '預交日' },
  { key: 'tc004', header: '客戶代號' },
  { key: 'ma002', header: '客戶名稱' },
  { key: 'tc019', header: '運輸方式' },
  { key: 'td008', header: '訂單數量', numeric: true },
  { key: 'ntd', header: '台幣金額', numeric: true, amount: true },
  { key: 'planNumber', header: '計畫批號' },
  { key: 'copSource', header: 'ERP' },
  { key: 'mq002', header: '單別名稱' },
  { key: 'tc006', header: '業務人員' },
  { key: 'mv002', header: '業務名稱' },
  { key: 'tc010', header: '送貨地址' },
  { key: 'tc014', header: '付款條件', amount: true },
  { key: 'tc016', header: '課稅別', amount: true }
]

const PRODUCT_MODAL_COLS: ColDef[] = [
  { key: 'copSource', header: 'ERP來源' },
  { key: 'mq002', header: '單別名稱' },
  { key: 'tc001', header: '訂單單別' },
  { key: 'tc002', header: '訂單單號' },
  { key: 'td003', header: '訂單序號' },
  { key: 'tc003', header: '訂單日期' },
  { key: 'tc004', header: '客戶代號' },
  { key: 'ma002', header: '客戶名稱' },
  { key: 'td008', header: '訂單數量', numeric: true },
  { key: 'ntd', header: '台幣金額', numeric: true, amount: true },
  { key: 'td013', header: '預交日' }
]

const SO_MODAL_COLS: ColDef[] = [
  { key: 'copSource', header: 'ERP來源' },
  { key: 'mq002', header: '單別名稱' },
  { key: 'tc001', header: '訂單單別' },
  { key: 'tc002', header: '訂單單號' },
  { key: 'td003', header: '訂單序號' },
  { key: 'tc003', header: '訂單日期' },
  { key: 'tc004', header: '客戶代號' },
  { key: 'ma002', header: '客戶名稱' },
  { key: 'td004', header: '品號' },
  { key: 'td005', header: '品名' },
  { key: 'td006', header: '規格' },
  { key: 'td008', header: '訂單數量', numeric: true },
  { key: 'ntd', header: '台幣金額', numeric: true, amount: true },
  { key: 'td013', header: '預交日' }
]

/**
 * paged = true 是外層四個頁籤（後端分頁，row.index 只是當頁第幾列，要加上前面幾頁的筆數），
 * 明細 modal 是一次全撈，不用加。
 */
const buildColumns = (defs: ColDef[], amountAllowed: boolean, withAction?: string, paged = false): TableColumn<UnfinOrderRow>[] => {
  const cols: TableColumn<UnfinOrderRow>[] = [
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

const productDetailColumns = computed(() => buildColumns(PRODUCT_DETAIL_COLS, showAmount.value, undefined, true))
const productGroupColumns = computed(() => buildColumns(PRODUCT_GROUP_COLS, showAmount.value, '內容', true))
const soDetailColumns = computed(() => buildColumns(SO_DETAIL_COLS, showAmount.value, undefined, true))
const soGroupColumns = computed(() => buildColumns(SO_GROUP_COLS, showAmount.value, '內容', true))

/** 四個頁籤共用一個 UTable，欄位依顯示中資料的頁籤切換。 */
const activeColumns = computed(() => ({
  productDetail: productDetailColumns.value,
  productGroup: productGroupColumns.value,
  soDetail: soDetailColumns.value,
  soGroup: soGroupColumns.value
})[shownTab.value])
const productModalColumns = computed(() => buildColumns(PRODUCT_MODAL_COLS, showAmount.value))
const soModalColumns = computed(() => buildColumns(SO_MODAL_COLS, showAmount.value))

// ---------------------------------------------------------------- 明細 modal

const productModalOpen = ref(false)
const productModalLoading = ref(false)
const productModalRows = ref<UnfinOrder[]>([])
const productModalFields = ref<{ label: string, value: string }[]>([])
const productModalSum = ref<number | null>(null)

const openProductDetail = async (row: UnfinOrderRow) => {
  productModalFields.value = [
    { label: '品號', value: row.td004 ?? '' },
    { label: '品名', value: row.td005 ?? '' },
    { label: '規格', value: row.td006 ?? '' }
  ]
  productModalSum.value = row.ntd ?? null
  productModalOpen.value = true
  productModalLoading.value = true
  try {
    const res = await api.getUnfinOrder({
      ...lastQuery.value,
      productNo: row.td004 ?? '',
      groupName: 'TD004'
    })
    productModalRows.value = res?.isSuccess ? (res.body ?? []).filter(r => isUnfinishDetailRow(r.footerFlag)) : []
  } catch (err) {
    console.log('unfinished-orders openProductDetail failed -->', err)
    productModalRows.value = []
    toast.add({ title: '讀取品號明細失敗', color: 'error' })
  } finally {
    productModalLoading.value = false
  }
}

const soModalOpen = ref(false)
const soModalLoading = ref(false)
const soModalRows = ref<UnfinOrder[]>([])
const soModalFields = ref<{ label: string, value: string }[]>([])
const soModalSum = ref<number | null>(null)

const openSoDetail = async (row: UnfinOrderRow) => {
  soModalFields.value = [
    { label: '訂單單別', value: row.tc001 ?? '' },
    { label: '訂單單號', value: row.tc002 ?? '' },
    { label: '客戶名稱', value: row.ma002 ?? '' }
  ]
  soModalSum.value = row.ntd ?? null
  soModalOpen.value = true
  soModalLoading.value = true
  try {
    // SP 不支援 orderType/orderNo 篩單一筆，靠 poNo 帶 "單別-單號" 組合字串（對照舊版 onClickShowSoDetail）。
    const res = await api.queryUnfinOrder1({
      ...lastQuery.value,
      poNo: `${row.tc001 ?? ''}-${row.tc002 ?? ''}`,
      orderType: '',
      groupName: 'TC001'
    })
    soModalRows.value = res?.isSuccess ? (res.body ?? []).filter(r => isUnfinishDetailRow(r.footerFlag)) : []
  } catch (err) {
    console.log('unfinished-orders openSoDetail failed -->', err)
    soModalRows.value = []
    toast.add({ title: '讀取訂單明細失敗', color: 'error' })
  } finally {
    soModalLoading.value = false
  }
}

/** 品號統計／訂單統計有明細 modal，細項兩個頁籤沒有。 */
const isGroupTab = computed(() => shownTab.value === 'productGroup' || shownTab.value === 'soGroup')

const openGroupDetail = (row: UnfinOrderRow) =>
  shownTab.value === 'productGroup' ? openProductDetail(row) : openSoDetail(row)
</script>

<template>
  <div>
    <!-- 不用 FullPageLoading 整頁遮罩：查詢條件與頁籤一開始就可操作，下方表格等 API 回來才更新。 -->
    <UBreadcrumb v-if="false" :items="breadcrumbFor(appPath('sales-search/unfinished-orders'))" class="mb-4" />

    <div class="mb-5">
      <h1 class="text-2xl font-bold text-highlighted">
        未完成訂單檢索
      </h1>
    </div>

    <!-- 查詢條件 -->
    <div class="mb-4 rounded-lg border border-default bg-elevated/40 px-3 py-2.5">
      <div class="grid grid-cols-1 gap-x-3 gap-y-1.5 md:grid-cols-2 xl:grid-cols-5">
        <UFormField label="客戶別" size="xs" :ui="FIELD_UI">
          <USelectMenu
            v-model="customerNoSelectValue"
            :items="customerOptions"
            value-key="value"
            label-key="label"
            placeholder="全部客戶"
            class="w-full"
          />
        </UFormField>

        <UFormField label="品號種類" size="xs" :ui="FIELD_UI">
          <div class="flex h-full items-center gap-4">
            <UCheckbox v-model="filters.show5x" label="成品(5開頭)" />
            <UCheckbox v-model="filters.showX" label="零件(x開頭)" />
          </div>
        </UFormField>

        <UFormField label="品號" size="xs" :ui="FIELD_UI">
          <UInput v-model="filters.productNo" placeholder="品號" class="w-full" @keyup.enter="search" />
        </UFormField>

        <UFormField label="品名" size="xs" :ui="FIELD_UI">
          <UInput v-model="filters.productName" placeholder="品名" class="w-full" @keyup.enter="search" />
        </UFormField>

        <UFormField label="規格" size="xs" :ui="FIELD_UI">
          <UInput v-model="filters.productSpec" placeholder="規格" class="w-full" @keyup.enter="search" />
        </UFormField>

        <UFormField label="序號" size="xs" :ui="FIELD_UI">
          <UInput v-model="filters.serialNo" placeholder="銘版序號" class="w-full" @keyup.enter="search" />
        </UFormField>

        <UFormField label="訂單單別" size="xs" :ui="FIELD_UI">
          <UInput v-model="filters.orderType" placeholder="訂單單別" class="w-full" @keyup.enter="search" />
        </UFormField>

        <UFormField label="訂單單號" size="xs" :ui="FIELD_UI">
          <UInput v-model="filters.orderNo" placeholder="訂單單號" class="w-full" @keyup.enter="search" />
        </UFormField>

        <UFormField label="計畫批號" size="xs" :ui="FIELD_UI">
          <UInput v-model="filters.planNum" placeholder="計畫批號" class="w-full" @keyup.enter="search" />
        </UFormField>

        <UFormField label="訂單日期（起~迄）" size="xs" :ui="FIELD_UI" class="md:col-span-2">
          <div class="flex items-center gap-2">
            <UInput v-model="filters.startDate" type="date" class="w-full" />
            <span class="text-sm text-muted">至</span>
            <UInput v-model="filters.endDate" type="date" class="w-full" />
            <UButton icon="i-lucide-x" color="neutral" variant="ghost" size="xs" title="清除訂單日期" @click="onClickClearOrderDate" />
          </div>
        </UFormField>

        <UFormField label="預交日期（起~迄）" size="xs" :ui="FIELD_UI" class="md:col-span-2">
          <div class="flex items-center gap-2">
            <UInput v-model="filters.deliveryStartDate" type="date" class="w-full" />
            <span class="text-sm text-muted">至</span>
            <UInput v-model="filters.deliveryEndDate" type="date" class="w-full" />
            <UButton icon="i-lucide-x" color="neutral" variant="ghost" size="xs" title="清除預交日期" @click="onClickClearDeliveryDate" />
          </div>
        </UFormField>
      </div>

      <div class="mt-2 flex items-center justify-between gap-2">
        <p v-if="showAmount" class="text-sm">
          總金額 NT
          <span class="font-semibold text-highlighted">{{ formatAmount(summary.totalAmount) || '0' }}</span>
        </p>
        <p v-else class="text-xs text-muted">
          無金額欄位檢視權限
        </p>
        <div class="flex items-center gap-2">
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
      改由 UTable 自己的根節點（預設 overflow-auto）限高捲動。
    -->
    <div class="overflow-hidden rounded-lg border border-default">
      <UTable
        ref="table"
        sticky
        class="max-h-[70vh]"
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
      :rows="productModalRows as UnfinOrderRow[]"
      :columns="productModalColumns"
    />

    <QueryDetailModal
      v-model:open="soModalOpen"
      title="單一訂單明細"
      :fields="soModalFields"
      :summary-amount="soModalSum"
      :show-amount="showAmount"
      :loading="soModalLoading"
      :rows="soModalRows as UnfinOrderRow[]"
      :columns="soModalColumns"
    />
  </div>
</template>
