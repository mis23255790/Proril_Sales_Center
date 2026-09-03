<script setup lang="ts">
import { h } from 'vue'
import type { TableColumn } from '@nuxt/ui'
import type { UnfinOrderQuery } from '~/composables/useSalesOrderUnfinishApi'
import type { UnfinOrder, UnfinOrderRow } from '~/types/salesOrderUnfinish'
import { UNFINISH_AMOUNT_LINK_TYPE, UNFINISH_FUNCTION_NO } from '~/types/salesOrderUnfinish'
import type { SalesShippingCustomer } from '~/types/salesShipping'
import { isUnfinishDetailRow } from '~/types/salesOrderUnfinish'

definePageMeta({ title: '未完成訂單檢索' })

useSeoMeta({ title: '未完成訂單檢索 · PRORIL 業務中心' })

const api = useSalesOrderUnfinishApi()
const { checkLinkTypePermission } = usePermission()
const toast = useToast()
const { breadcrumbFor, appPath } = useAppNavigation()

/** 90 天內資料，對照舊版 UI_InitQueryDate(..., 90)。 */
const DEFAULT_DAYS = 90

const dateDaysAgo = (days: number) => toDateString(new Date(Date.now() - days * 24 * 60 * 60 * 1000))

const loading = ref(false)
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

const productRows = ref<UnfinOrder[]>([])
const soRows = ref<UnfinOrder[]>([])

const productDetailRows = computed(() => toUnfinishProductDetailRows(productRows.value))
const productGroupRows = computed(() => toUnfinishProductGroupRows(productRows.value))
const soDetailRows = computed(() => toUnfinishSoDetailRows(soRows.value))
const soGroupRows = computed(() => toUnfinishSoGroupRows(soRows.value))
const totalAmount = computed(() => sumUnfinishTotalAmount(productRows.value))

const customerOptions = computed(() => [
  { label: '全部客戶', value: '' },
  ...customers.value.map(c => ({
    label: `${c.customerNo}-${c.longName ?? ''}(${c.shortName ?? ''})`,
    value: c.customerNo
  }))
])

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
    showAmount.value = await checkLinkTypePermission(UNFINISH_FUNCTION_NO, UNFINISH_AMOUNT_LINK_TYPE)
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

const load = async () => {
  loading.value = true
  try {
    const [productRes, soRes] = await Promise.all([
      api.getUnfinOrder({ ...baseQuery(), groupName: 'TD004' }),
      api.queryUnfinOrder1({ ...baseQuery(), groupName: 'TC001' })
    ])

    // 查無資料時後端回 isSuccess: false + 說明訊息，不是錯誤，當空清單處理。
    productRows.value = productRes?.isSuccess ? (productRes.body ?? []) : []
    soRows.value = soRes?.isSuccess ? (soRes.body ?? []) : []

    if (productRes && !productRes.isSuccess && productRes.message) {
      toast.add({ title: '品號查詢無資料', description: productRes.message, color: 'warning' })
    }
  } catch (err) {
    console.log('unfinished-orders load failed -->', err)
    productRows.value = []
    soRows.value = []
    toast.add({ title: '查詢失敗', color: 'error' })
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  loadPermission()
  loadCustomers()
  load()
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
  load()
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

const activeTab = ref<'productDetail' | 'productGroup' | 'soDetail' | 'soGroup'>('productDetail')

const tabItems = [
  { label: '品號細項', value: 'productDetail', icon: 'i-lucide-list' },
  { label: '品號統計', value: 'productGroup', icon: 'i-lucide-chart-bar' },
  { label: '訂單細項', value: 'soDetail', icon: 'i-lucide-list' },
  { label: '訂單統計', value: 'soGroup', icon: 'i-lucide-chart-bar' }
] as const

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

const buildColumns = (defs: ColDef[], amountAllowed: boolean, withAction?: string): TableColumn<UnfinOrderRow>[] => {
  const cols: TableColumn<UnfinOrderRow>[] = [
    {
      id: 'no',
      header: '#',
      cell: ({ row }) => h('span', { class: 'block text-right text-dimmed' }, String(row.index + 1))
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

const productDetailColumns = computed(() => buildColumns(PRODUCT_DETAIL_COLS, showAmount.value))
const productGroupColumns = computed(() => buildColumns(PRODUCT_GROUP_COLS, showAmount.value, '內容'))
const soDetailColumns = computed(() => buildColumns(SO_DETAIL_COLS, showAmount.value))
const soGroupColumns = computed(() => buildColumns(SO_GROUP_COLS, showAmount.value, '內容'))
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
      ...baseQuery(),
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
      ...baseQuery(),
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
</script>

<template>
  <div>
    <FullPageLoading :show="loading" />

    <UBreadcrumb :items="breadcrumbFor(appPath('sales-search/unfinished-orders'))" class="mb-4" />

    <div class="mb-5">
      <h1 class="text-2xl font-bold text-highlighted">
        未完成訂單檢索
      </h1>
      <p class="mt-1 text-sm text-muted">
        依客戶別、訂單日期、預交日期、品號等條件查詢尚未出貨的訂單，可依品號或訂單分別檢視細項與統計。
      </p>
    </div>

    <!-- 查詢條件 -->
    <div class="mb-4 rounded-lg border border-default bg-elevated/40 p-4">
      <div class="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-4">
        <UFormField label="客戶別" size="sm">
          <USelectMenu
            v-model="filters.customerNo"
            :items="customerOptions"
            value-key="value"
            label-key="label"
            placeholder="全部客戶"
            class="w-full"
          />
        </UFormField>

        <UFormField label="品號種類" size="sm">
          <div class="flex h-full items-center gap-4">
            <UCheckbox v-model="filters.show5x" label="成品(5開頭)" />
            <UCheckbox v-model="filters.showX" label="零件(x開頭)" />
          </div>
        </UFormField>

        <UFormField label="品號" size="sm">
          <UInput v-model="filters.productNo" placeholder="品號" class="w-full" @keyup.enter="load" />
        </UFormField>

        <UFormField label="品名" size="sm">
          <UInput v-model="filters.productName" placeholder="品名" class="w-full" @keyup.enter="load" />
        </UFormField>

        <UFormField label="規格" size="sm">
          <UInput v-model="filters.productSpec" placeholder="規格" class="w-full" @keyup.enter="load" />
        </UFormField>

        <UFormField label="序號" size="sm">
          <UInput v-model="filters.serialNo" placeholder="銘版序號" class="w-full" @keyup.enter="load" />
        </UFormField>

        <UFormField label="訂單單別" size="sm">
          <UInput v-model="filters.orderType" placeholder="訂單單別" class="w-full" @keyup.enter="load" />
        </UFormField>

        <UFormField label="訂單單號" size="sm">
          <UInput v-model="filters.orderNo" placeholder="訂單單號" class="w-full" @keyup.enter="load" />
        </UFormField>

        <UFormField label="計畫批號" size="sm">
          <UInput v-model="filters.planNum" placeholder="計畫批號" class="w-full" @keyup.enter="load" />
        </UFormField>

        <UFormField label="訂單日期（起~迄）" size="sm" class="md:col-span-2">
          <div class="flex items-center gap-2">
            <UInput v-model="filters.startDate" type="date" class="w-full" />
            <span class="text-sm text-muted">至</span>
            <UInput v-model="filters.endDate" type="date" class="w-full" />
            <UButton icon="i-lucide-x" color="neutral" variant="ghost" size="sm" title="清除訂單日期" @click="onClickClearOrderDate" />
          </div>
        </UFormField>

        <UFormField label="預交日期（起~迄）" size="sm" class="md:col-span-2">
          <div class="flex items-center gap-2">
            <UInput v-model="filters.deliveryStartDate" type="date" class="w-full" />
            <span class="text-sm text-muted">至</span>
            <UInput v-model="filters.deliveryEndDate" type="date" class="w-full" />
            <UButton icon="i-lucide-x" color="neutral" variant="ghost" size="sm" title="清除預交日期" @click="onClickClearDeliveryDate" />
          </div>
        </UFormField>
      </div>

      <div class="mt-3 flex items-center justify-between gap-2">
        <p v-if="showAmount" class="text-sm">
          總金額 NT
          <span class="font-semibold text-highlighted">{{ formatAmount(totalAmount) || '0' }}</span>
        </p>
        <p v-else class="text-xs text-muted">
          無金額欄位檢視權限
        </p>
        <div class="flex items-center gap-2">
          <UButton icon="i-lucide-rotate-cw" color="neutral" variant="outline" size="sm" @click="onClickReset">
            重設
          </UButton>
          <UButton icon="i-lucide-search" size="sm" :loading="loading" @click="load">
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
        @click="activeTab = tab.value"
      >
        {{ tab.label }}
      </UButton>
    </div>

    <div class="overflow-x-auto rounded-lg border border-default">
      <UTable
        v-if="activeTab === 'productDetail'"
        :data="productDetailRows"
        :columns="productDetailColumns"
        :loading="loading"
        :ui="{ td: 'whitespace-nowrap' }"
      >
        <template #empty>
          <p class="py-12 text-center text-sm text-muted">
            沒有符合條件的品號細項
          </p>
        </template>
      </UTable>

      <UTable
        v-else-if="activeTab === 'productGroup'"
        :data="productGroupRows"
        :columns="productGroupColumns"
        :loading="loading"
        :ui="{ td: 'whitespace-nowrap' }"
      >
        <template #actions-cell="{ row }">
          <UButton size="xs" color="primary" variant="outline" @click="openProductDetail(row.original)">
            內容
          </UButton>
        </template>
        <template #empty>
          <p class="py-12 text-center text-sm text-muted">
            沒有符合條件的品號統計
          </p>
        </template>
      </UTable>

      <UTable
        v-else-if="activeTab === 'soDetail'"
        :data="soDetailRows"
        :columns="soDetailColumns"
        :loading="loading"
        :ui="{ td: 'whitespace-nowrap' }"
      >
        <template #empty>
          <p class="py-12 text-center text-sm text-muted">
            沒有符合條件的訂單細項
          </p>
        </template>
      </UTable>

      <UTable
        v-else
        :data="soGroupRows"
        :columns="soGroupColumns"
        :loading="loading"
        :ui="{ td: 'whitespace-nowrap' }"
      >
        <template #actions-cell="{ row }">
          <UButton size="xs" color="primary" variant="outline" @click="openSoDetail(row.original)">
            內容
          </UButton>
        </template>
        <template #empty>
          <p class="py-12 text-center text-sm text-muted">
            沒有符合條件的訂單統計
          </p>
        </template>
      </UTable>
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
