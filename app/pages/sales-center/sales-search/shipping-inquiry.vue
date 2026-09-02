<script setup lang="ts">
import { h } from 'vue'
import type { TableColumn } from '@nuxt/ui'
import type { SalesOrderQuery } from '~/composables/useSalesShippingApi'
import type { CopSalesOrder, CopSalesOrderRow, SalesShippingCustomer } from '~/types/salesShipping'
import { isDetailRow, SALES_SHIPPING_AMOUNT_LINK_TYPE, SALES_SHIPPING_FUNCTION_NO } from '~/types/salesShipping'

definePageMeta({ title: '銷貨檢索' })

useSeoMeta({ title: '銷貨檢索 · PRORIL 業務中心' })

const api = useSalesShippingApi()
const { checkLinkTypePermission } = usePermission()
const toast = useToast()
const { breadcrumbFor, appPath } = useAppNavigation()

/** 90 天內資料，對照舊版 UI_InitQueryDate(..., 90)。 */
const DEFAULT_DAYS = 90
/** 「全部」按鈕：20 年，等於不限日期。 */
const ALL_DAYS = 365 * 20

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
  orderNo: '',
  planNum: '',
  startDate: dateDaysAgo(DEFAULT_DAYS),
  endDate: toDateString(new Date())
})

const productRows = ref<CopSalesOrder[]>([])
const soRows = ref<CopSalesOrder[]>([])

const productDetailRows = computed(() => toProductDetailRows(productRows.value))
const productGroupRows = computed(() => toProductGroupRows(productRows.value))
const soDetailRows = computed(() => toSoDetailRows(soRows.value))
const soGroupRows = computed(() => toSoGroupRows(soRows.value))
const totalAmount = computed(() => sumTotalAmount(productRows.value))

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
    console.log('shipping-inquiry loadCustomers failed -->', err)
    customers.value = []
  }
}

const loadPermission = async () => {
  try {
    showAmount.value = await checkLinkTypePermission(SALES_SHIPPING_FUNCTION_NO, SALES_SHIPPING_AMOUNT_LINK_TYPE)
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

const load = async () => {
  loading.value = true
  try {
    const [productRes, soRes] = await Promise.all([
      api.getSalesOrder({ ...baseQuery(), groupName: 'TH004' }),
      api.getSalesOrder1({ ...baseQuery(), groupName: 'TH001' })
    ])

    // 查無資料時後端回 isSuccess: false + 說明訊息，不是錯誤，當空清單處理。
    productRows.value = productRes?.isSuccess ? (productRes.body ?? []) : []
    soRows.value = soRes?.isSuccess ? (soRes.body ?? []) : []

    if (productRes && !productRes.isSuccess && productRes.message) {
      toast.add({ title: '品號查詢無資料', description: productRes.message, color: 'warning' })
    }
  } catch (err) {
    console.log('shipping-inquiry load failed -->', err)
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
  filters.orderNo = ''
  filters.planNum = ''
  filters.startDate = dateDaysAgo(DEFAULT_DAYS)
  filters.endDate = toDateString(new Date())
  load()
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
  load()
}

const onExport = async () => {
  exporting.value = true
  try {
    const res = await api.exportXls({ ...baseQuery(), groupName: 'TH001' })
    if (!res?.isSuccess || !res.body) {
      toast.add({ title: '匯出失敗', description: res?.message ?? '', color: 'error' })
      return
    }
    const path = `/ShareRoot/${res.body}`
    const name = res.body.split('/').pop() || 'export.xlsx'
    window.open(`/api/download?path=${encodeURIComponent(path)}&name=${encodeURIComponent(name)}`, '_blank')
  } catch (err) {
    console.log('shipping-inquiry onExport failed -->', err)
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
  { label: '銷貨單細項', value: 'soDetail', icon: 'i-lucide-list' },
  { label: '銷貨單統計', value: 'soGroup', icon: 'i-lucide-chart-bar' }
] as const

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

const buildColumns = (defs: ColDef[], amountAllowed: boolean, withAction?: string): TableColumn<CopSalesOrderRow>[] => {
  const cols: TableColumn<CopSalesOrderRow>[] = [
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

const productDetailColumns = computed(() => buildColumns(DETAIL_COLS, showAmount.value))
const productGroupColumns = computed(() => buildColumns(PRODUCT_GROUP_COLS, showAmount.value, '內容'))
const soDetailColumns = computed(() => buildColumns(DETAIL_COLS, showAmount.value))
const soGroupColumns = computed(() => buildColumns(SO_GROUP_COLS, showAmount.value, '內容'))
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
      ...baseQuery(),
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
      ...baseQuery(),
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
</script>

<template>
  <div>
    <FullPageLoading :show="loading" />

    <UBreadcrumb :items="breadcrumbFor(appPath('sales-search/shipping-inquiry'))" class="mb-4" />

    <div class="mb-5">
      <h1 class="text-2xl font-bold text-highlighted">
        銷貨檢索
      </h1>
      <p class="mt-1 text-sm text-muted">
        依客戶別、期間、品號等條件查詢銷貨資料，可依品號或銷貨單分別檢視細項與統計。
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

        <UFormField label="訂單單號" size="sm">
          <UInput v-model="filters.orderNo" placeholder="訂單單號" class="w-full" @keyup.enter="load" />
        </UFormField>

        <UFormField label="計畫批號" size="sm">
          <UInput v-model="filters.planNum" placeholder="計畫批號" class="w-full" @keyup.enter="load" />
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
          <UButton icon="i-lucide-list-x" color="neutral" variant="outline" size="sm" @click="onClickAll">
            全部
          </UButton>
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
            沒有符合條件的銷貨單細項
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
            沒有符合條件的銷貨單統計
          </p>
        </template>
      </UTable>
    </div>

    <SalesOrderDetailModal
      v-model:open="productModalOpen"
      title="單一品號明細"
      :fields="productModalFields"
      :summary-amount="productModalSum"
      :show-amount="showAmount"
      :loading="productModalLoading"
      :rows="productModalRows as CopSalesOrderRow[]"
      :columns="productModalColumns"
    />

    <SalesOrderDetailModal
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
