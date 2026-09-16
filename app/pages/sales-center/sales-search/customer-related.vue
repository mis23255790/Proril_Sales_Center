<script setup lang="ts">
import type { TableColumn } from '@nuxt/ui'
import type { CustomerWithErp, ErpCustomer } from '~/types/customer'
import type {
  CustomerCreditRow,
  CustomerMemo,
  CustomerWorkProcessRow,
  SalesYearRow,
  UnfinOrderSummaryRow
} from '~/types/customerRelated'
import ConfirmDialog from '~/components/common/ConfirmDialog.vue'

definePageMeta({ title: '客戶相關資訊' })

useSeoMeta({ title: '客戶相關資訊 · PRORIL 業務中心' })

const route = useRoute()
const toast = useToast()
const overlay = useOverlay()
const api = useCustomerRelatedApi()
const { breadcrumbFor, appPath } = useAppNavigation()

/**
 * 網址參數沿用 1.0 的兩個 key（Customer / ErpCustomerNo），只是改成小駝峰。
 * 兩個都可能是空的：從內網客戶列點進來只有 customer，從 ERP 客戶列點進來只有 erpCustomerNo。
 */
const queryCustomerNo = computed(() => String(route.query.customer ?? '').trim())
const queryErpCustomerNo = computed(() => String(route.query.erpCustomerNo ?? '').trim())

const loading = ref(false)
const customer = ref<CustomerWithErp | null>(null)
const erpCustomer = ref<ErpCustomer | null>(null)
const memos = ref<CustomerMemo[]>([])
const unfinOrders = ref<UnfinOrderSummaryRow[]>([])
const salesYears = ref<SalesYearRow[]>([])
const credits = ref<CustomerCreditRow[]>([])
const workProcesses = ref<CustomerWorkProcessRow[]>([])

/**
 * 實際用來查情報／議題的內網客戶代號。
 *
 * 從 ERP 客戶列點進來時網址上只有 ERP 客編，但 GetCustom 用 ERP 客編也查得到
 * 對應的內網客戶，所以這裡改用查回來的結果，而不是直接用網址參數。
 *
 * **與 1.0 的差異**：1.0 是拿網址上的 Customer 去查情報與議題，從 ERP 客戶列點進來時
 * 那個值是 null，情報與議題兩個頁籤永遠空的（那支 API 甚至收到 erpCustomerNo 也刻意清空）。
 * 這裡補起來，讓兩個入口看到的內容一致。
 */
const effectiveCustomerNo = computed(() =>
  (customer.value?.customerNo ?? '').trim() || queryCustomerNo.value)

/** 銷售／訂單／信用額度都吃 ERP 客編，優先用查回來的，其次才是網址參數。 */
const effectiveErpCustomerNo = computed(() =>
  (customer.value?.erpcustomerNo ?? '').trim() || queryErpCustomerNo.value)

const displayTitle = computed(() => {
  const name = customer.value?.shortName || erpCustomer.value?.ma002 || ''
  const no = effectiveCustomerNo.value || effectiveErpCustomerNo.value || '（未指定客戶）'
  return name ? `${no}　${name}` : no
})

const creditCurrency = computed(() => credits.value[0]?.幣別 ?? '')

/** 基本資料兩個區塊的欄位，用資料驅動避免 template 塞十幾組 dt/dd。 */
const erpFields = computed(() => {
  const e = erpCustomer.value
  if (!e) return []
  return [
    { label: 'ERP客戶代號', value: e.ma001, wide: false },
    { label: '客戶名稱', value: e.ma002, wide: false },
    { label: '全名', value: e.ma003, wide: false },
    { label: '聯絡人', value: e.ma005, wide: false },
    { label: '聯絡電話-1', value: e.ma006, wide: false },
    { label: '聯絡電話-2', value: e.ma007, wide: false },
    { label: '傳真', value: e.ma008, wide: false },
    { label: 'EMail', value: e.ma009, wide: false },
    { label: '母公司', value: e.erpheadCustomer, wide: false },
    { label: '地址-1', value: e.ma023, wide: true },
    { label: '地址-2', value: e.ma024, wide: true }
  ]
})

const internalFields = computed(() => {
  const c = customer.value
  if (!c) return []
  return [
    { label: '客戶代號', value: c.customerNo, wide: false },
    { label: '客戶名稱', value: c.shortName, wide: false },
    { label: '全名', value: c.longName, wide: false },
    { label: '聯絡人', value: c.contactName, wide: false },
    { label: '聯絡電話', value: c.contactTel1, wide: false },
    { label: 'EMail', value: c.contactEmail, wide: false },
    { label: '負責業務', value: c.salesName, wide: false },
    { label: '潛在客戶', value: c.potentialCustom === 'Y' ? '是' : '否', wide: false }
  ]
})

/** 基本資料先載，之後四個頁籤要用它解出來的客戶代號，所以不能全部一起併發。 */
const loadBasic = async () => {
  const [customerRes, erpRes] = await Promise.all([
    api.getCustomer(queryCustomerNo.value, queryErpCustomerNo.value),
    api.getErpCustomer(queryErpCustomerNo.value)
  ])

  // isSuccess: false 不一定是錯誤，查無資料時也是這樣回，當空清單處理。
  customer.value = (customerRes?.isSuccess ? customerRes.body : null)?.[0] ?? null
  erpCustomer.value = (erpRes?.isSuccess ? erpRes.body : null)?.[0] ?? null
}

const loadTabs = async () => {
  const customerNo = effectiveCustomerNo.value
  const erpNo = effectiveErpCustomerNo.value

  const [memoRes, orderRes, salesRes, creditRes, wpRes] = await Promise.all([
    api.getMemos(customerNo, erpNo),
    api.getUnfinOrders(customerNo, erpNo),
    api.getSalesTotal(customerNo, erpNo),
    api.getCredits(customerNo, erpNo),
    api.getWorkProcesses(customerNo)
  ])

  memos.value = memoRes?.isSuccess ? (memoRes.body ?? []) : []
  unfinOrders.value = toUnfinOrderSummary(orderRes?.isSuccess ? (orderRes.body ?? []) : [])
  salesYears.value = toSalesYearRows(salesRes?.isSuccess ? (salesRes.body ?? []) : [])
  credits.value = creditRes?.isSuccess ? (creditRes.body ?? []) : []
  workProcesses.value = wpRes?.isSuccess ? (wpRes.body ?? []) : []
}

const load = async () => {
  loading.value = true
  try {
    await loadBasic()
    await loadTabs()
  } catch (err) {
    console.log('customer-related load failed -->', err)
    toast.add({ title: '載入客戶資料失敗', color: 'error' })
  } finally {
    loading.value = false
  }
}

onMounted(load)

// ---------------------------------------------------------------- 頁籤

const activeTab = ref<'info' | 'memo' | 'order' | 'sales' | 'credit' | 'issue'>('info')

/**
 * 1.0 這六個頁籤各自綁 M_Permission 的 PermissionLinkTypeId 10~60，但那段權限檢查
 * 實際上是壞的（GetPermission 的 where 整段被註解，回傳整張表），等於誰都看得到全部。
 * 2.0 這次維持全開，跟其他業務檢索頁一致，見 docs/modules/Customer/logic.md。
 */
const tabItems = [
  { label: '基本資料', value: 'info', icon: 'i-lucide-id-card' },
  { label: '情報', value: 'memo', icon: 'i-lucide-notebook-pen' },
  { label: '訂單', value: 'order', icon: 'i-lucide-package' },
  { label: '銷售', value: 'sales', icon: 'i-lucide-chart-column' },
  { label: '信用額度', value: 'credit', icon: 'i-lucide-credit-card' },
  { label: '議題', value: 'issue', icon: 'i-lucide-messages-square' }
] as const

// ---------------------------------------------------------------- 情報

const memoModalOpen = ref(false)
const memoSaving = ref(false)
const memoForm = ref({ id: 0, memoType: '', memoDesc: '' })

const memoColumns: TableColumn<CustomerMemo>[] = [
  { accessorKey: 'memoType', header: '類別' },
  { accessorKey: 'memoDesc', header: '內容' },
  { accessorKey: 'creatorName', header: '作者' },
  {
    accessorKey: 'createTime',
    header: '建立日期',
    cell: ({ row }) => toDateTimeString(row.original.createTime)
  },
  { id: 'actions', header: '功能' }
]

const openAddMemo = () => {
  memoForm.value = { id: 0, memoType: '', memoDesc: '' }
  memoModalOpen.value = true
}

const openEditMemo = (row: CustomerMemo) => {
  memoForm.value = { id: row.id, memoType: row.memoType ?? '', memoDesc: row.memoDesc ?? '' }
  memoModalOpen.value = true
}

const reloadMemos = async () => {
  const res = await api.getMemos(effectiveCustomerNo.value, effectiveErpCustomerNo.value)
  memos.value = res?.isSuccess ? (res.body ?? []) : []
}

const onSaveMemo = async () => {
  if (!memoForm.value.memoDesc.trim()) {
    toast.add({ title: '請輸入情報內容', color: 'warning' })
    return
  }
  if (!effectiveCustomerNo.value) {
    toast.add({ title: '這個 ERP 客戶還沒建立內網客戶，無法新增情報', color: 'warning' })
    return
  }

  memoSaving.value = true
  try {
    const res = await api.saveMemo({
      id: memoForm.value.id,
      customerNo: effectiveCustomerNo.value,
      memoType: memoForm.value.memoType,
      memoDesc: memoForm.value.memoDesc
    })
    if (!res?.isSuccess) {
      toast.add({ title: '存檔失敗', description: res?.message ?? '', color: 'error' })
      return
    }
    toast.add({ title: '資料已存檔', color: 'success' })
    memoModalOpen.value = false
    await reloadMemos()
  } catch (err) {
    console.log('customer-related onSaveMemo failed -->', err)
    toast.add({ title: '存檔失敗', color: 'error' })
  } finally {
    memoSaving.value = false
  }
}

const confirmModal = overlay.create(ConfirmDialog)

const onDeleteMemo = async (row: CustomerMemo) => {
  try {
    const confirmed = await confirmModal.open({
      title: '刪除情報',
      description: '確定要刪除這筆情報？刪除後不會出現在清單，但資料仍保留在資料庫。',
      confirmLabel: '刪除',
      confirmColor: 'error'
    }).result

    if (!confirmed) return

    const res = await api.deleteMemo(row.id)
    if (!res?.isSuccess) {
      toast.add({ title: '刪除失敗', description: res?.message ?? '', color: 'error' })
      return
    }
    toast.add({ title: '情報已刪除', color: 'success' })
    await reloadMemos()
  } catch (err) {
    console.log('customer-related onDeleteMemo failed -->', err)
    toast.add({ title: '刪除失敗', color: 'error' })
  }
}

// ---------------------------------------------------------------- 訂單

const orderColumns: TableColumn<UnfinOrderSummaryRow>[] = [
  { accessorKey: 'copSource', header: '來源' },
  { accessorKey: 'tc001', header: '單別' },
  { accessorKey: 'tc002', header: '單號' },
  { accessorKey: 'tc003', header: '訂單日期' },
  { accessorKey: 'td013', header: '預交日' },
  { accessorKey: 'qty05', header: '成品數量' },
  { accessorKey: 'amt05', header: '成品金額', cell: ({ row }) => formatAmount(row.original.amt05) },
  { accessorKey: 'qty0x', header: '零件數量' },
  { accessorKey: 'amt0x', header: '零件金額', cell: ({ row }) => formatAmount(row.original.amt0x) },
  { accessorKey: 'qty0a', header: '總數量' },
  { accessorKey: 'amt0a', header: '總金額', cell: ({ row }) => formatAmount(row.original.amt0a) }
]

const orderTotalAmount = computed(() =>
  unfinOrders.value.reduce((sum, row) => sum + row.amt0a, 0))

// ---------------------------------------------------------------- 信用額度

const creditColumns: TableColumn<CustomerCreditRow>[] = [
  { accessorKey: 'parentCorpShortName', header: '母公司' },
  { accessorKey: 'parentCorpLongName', header: '母公司全名' },
  { accessorKey: '應收金額', header: '應收金額', cell: ({ row }) => formatAmount(row.original.應收金額) },
  { accessorKey: '未結帳銷貨', header: '未結帳銷貨', cell: ({ row }) => formatAmount(row.original.未結帳銷貨) },
  { accessorKey: '訂貨出貨通知金額', header: '訂貨出貨通知金額', cell: ({ row }) => formatAmount(row.original.訂貨出貨通知金額) },
  { accessorKey: '預收金額', header: '預收金額', cell: ({ row }) => formatAmount(row.original.預收金額) },
  { accessorKey: '已出貨抵預收金額', header: '已出貨抵預收金額', cell: ({ row }) => formatAmount(row.original.已出貨抵預收金額) },
  { accessorKey: '應收合計金額', header: '應收合計金額', cell: ({ row }) => formatAmount(row.original.應收合計金額) },
  { accessorKey: '未出貨訂單總金額', header: '未出貨訂單總金額', cell: ({ row }) => formatAmount(row.original.未出貨訂單總金額) },
  { accessorKey: '未出貨訂單金額比率', header: '未出貨訂單金額比率' },
  { accessorKey: '信用可超出額', header: '信用可超出額', cell: ({ row }) => formatAmount(row.original.信用可超出額) },
  { accessorKey: '信用餘額', header: '信用餘額', cell: ({ row }) => formatAmount(row.original.信用餘額) }
]

// ---------------------------------------------------------------- 議題

const issueColumns: TableColumn<CustomerWorkProcessRow>[] = [
  { accessorKey: 'wpno', header: '議題編號' },
  { accessorKey: 'sopTitle', header: '議題' },
  { accessorKey: 'userName', header: '作者' }
]

const openIssue = (row: CustomerWorkProcessRow) => {
  if (!row.wpno) return
  navigateTo(appPath(`sales-issue/issues/${row.wpno.trim()}`))
}
</script>

<template>
  <div>
    <FullPageLoading :show="loading" />

    <UBreadcrumb :items="breadcrumbFor(appPath('sales-search/customer'), '客戶相關資訊')" class="mb-4" />

    <div class="mb-5 flex flex-wrap items-start justify-between gap-3">
      <div>
        <h1 class="text-2xl font-bold text-highlighted">
          {{ displayTitle }}
        </h1>
        <p class="mt-1 text-sm text-muted">
          {{ customer?.longName || erpCustomer?.ma003 || '　' }}
        </p>
      </div>
      <UButton
        icon="i-lucide-arrow-left"
        color="neutral"
        variant="outline"
        :to="appPath('sales-search/customer')"
      >
        回客戶檢索
      </UButton>
    </div>

    <div
      v-if="!customer && erpCustomer"
      class="mb-4 rounded-lg border border-warning/40 bg-warning/10 p-3 text-sm"
    >
      這個 ERP 客戶尚未建立對應的內網客戶，「情報」與「議題」會是空的。
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

    <!-- 基本資料 -->
    <div v-if="activeTab === 'info'" class="flex flex-col gap-4">
      <div class="rounded-lg border border-default p-4">
        <h2 class="mb-3 text-base font-semibold text-highlighted">
          ERP 基本資料
        </h2>
        <dl v-if="erpCustomer" class="grid grid-cols-1 gap-x-6 gap-y-2 text-sm md:grid-cols-2 xl:grid-cols-3">
          <div v-for="field in erpFields" :key="field.label" :class="field.wide ? 'md:col-span-2' : ''">
            <dt class="text-muted">
              {{ field.label }}
            </dt>
            <dd>{{ field.value || '-' }}</dd>
          </div>
        </dl>
        <p v-else class="text-sm text-muted">
          這個客戶沒有對應的 ERP 資料
        </p>
      </div>

      <div class="rounded-lg border border-default p-4">
        <h2 class="mb-3 text-base font-semibold text-highlighted">
          內網基本資料
        </h2>
        <dl v-if="customer" class="grid grid-cols-1 gap-x-6 gap-y-2 text-sm md:grid-cols-2 xl:grid-cols-3">
          <div v-for="field in internalFields" :key="field.label">
            <dt class="text-muted">
              {{ field.label }}
            </dt>
            <dd>{{ field.value || '-' }}</dd>
          </div>
        </dl>
        <p v-else class="text-sm text-muted">
          尚未建立內網客戶資料
        </p>
      </div>
    </div>

    <!-- 情報 -->
    <div v-else-if="activeTab === 'memo'">
      <div class="mb-3 flex items-center justify-between">
        <h2 class="text-base font-semibold text-highlighted">
          情報
        </h2>
        <UButton icon="i-lucide-plus" size="sm" :disabled="!effectiveCustomerNo" @click="openAddMemo">
          新增
        </UButton>
      </div>

      <div class="overflow-x-auto rounded-lg border border-default">
        <UTable
          :data="memos"
          :columns="memoColumns"
          :ui="{ tr: clickableRowTr }"
          @select="(_e: Event, row: any) => openEditMemo(row.original)"
        >
          <template #memoDesc-cell="{ row }">
            <span class="whitespace-pre-line">{{ row.original.memoDesc }}</span>
          </template>
          <template #actions-cell="{ row }">
            <div class="flex gap-1" @click.stop>
              <UButton size="xs" color="primary" variant="outline" @click="openEditMemo(row.original)">
                編輯
              </UButton>
              <UButton size="xs" color="error" variant="outline" @click="onDeleteMemo(row.original)">
                刪除
              </UButton>
            </div>
          </template>
          <template #empty>
            <p class="py-12 text-center text-sm text-muted">
              這個客戶還沒有情報
            </p>
          </template>
        </UTable>
      </div>
    </div>

    <!-- 訂單 -->
    <div v-else-if="activeTab === 'order'">
      <div class="mb-3 flex items-center justify-between">
        <h2 class="text-base font-semibold text-highlighted">
          未完成訂單（幣別：NTD）
        </h2>
        <p class="text-sm text-muted">
          總金額 {{ formatAmount(orderTotalAmount) }}
        </p>
      </div>

      <div class="overflow-x-auto rounded-lg border border-default">
        <UTable :data="unfinOrders" :columns="orderColumns" :ui="{ td: 'whitespace-nowrap' }">
          <template #empty>
            <p class="py-12 text-center text-sm text-muted">
              這個客戶沒有未完成訂單
            </p>
          </template>
        </UTable>
      </div>
    </div>

    <!-- 銷售 -->
    <div v-else-if="activeTab === 'sales'">
      <h2 class="mb-3 text-base font-semibold text-highlighted">
        銷售（幣別：NTD，數量 / 金額）
      </h2>

      <div class="overflow-x-auto rounded-lg border border-default">
        <table class="w-full text-sm">
          <thead class="bg-elevated/60">
            <tr>
              <th class="px-3 py-2 text-left font-medium">
                年度
              </th>
              <th v-for="m in 12" :key="m" class="px-3 py-2 text-right font-medium whitespace-nowrap">
                {{ m }} 月
              </th>
              <th class="px-3 py-2 text-right font-medium whitespace-nowrap">
                年度合計
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="year in salesYears"
              :key="year.year"
              class="border-t border-default"
              :class="year.isTotal ? 'font-medium bg-elevated/30' : ''"
            >
              <td class="px-3 py-2 whitespace-nowrap">
                {{ year.year }}
              </td>
              <td v-for="(month, i) in year.months" :key="i" class="px-3 py-2 text-right whitespace-nowrap">
                <span v-if="month.qty === null" class="text-dimmed">-</span>
                <span v-else>{{ formatAmount(month.qty) }} / {{ formatAmount(month.amt) }}</span>
              </td>
              <td class="px-3 py-2 text-right whitespace-nowrap">
                <span v-if="year.sumQty === null" class="text-dimmed">-</span>
                <span v-else>{{ formatAmount(year.sumQty) }} / {{ formatAmount(year.sumAmt) }}</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- 信用額度 -->
    <div v-else-if="activeTab === 'credit'">
      <div class="mb-3 flex items-center justify-between">
        <h2 class="text-base font-semibold text-highlighted">
          信用額度
        </h2>
        <p v-if="creditCurrency" class="text-sm text-muted">
          幣別：{{ creditCurrency }}
        </p>
      </div>

      <div class="overflow-x-auto rounded-lg border border-default">
        <UTable :data="credits" :columns="creditColumns" :ui="{ td: 'whitespace-nowrap text-right' }">
          <template #empty>
            <p class="py-12 text-center text-sm text-muted">
              查無信用額度資料
            </p>
          </template>
        </UTable>
      </div>
    </div>

    <!-- 議題 -->
    <div v-else>
      <h2 class="mb-3 text-base font-semibold text-highlighted">
        議題
      </h2>

      <div class="overflow-x-auto rounded-lg border border-default">
        <UTable
          :data="workProcesses"
          :columns="issueColumns"
          :ui="{ tr: clickableRowTr }"
          @select="(_e: Event, row: any) => openIssue(row.original)"
        >
          <template #empty>
            <p class="py-12 text-center text-sm text-muted">
              這個客戶沒有關聯的議題
            </p>
          </template>
        </UTable>
      </div>
    </div>

    <!-- 新增／編輯情報 -->
    <UModal v-model:open="memoModalOpen" title="編輯情報" :ui="{ content: 'max-w-2xl' }">
      <template #body>
        <div class="flex flex-col gap-4">
          <UFormField label="類別" size="sm">
            <UInput v-model="memoForm.memoType" placeholder="輸入類別" class="w-full" />
          </UFormField>
          <UFormField label="內容" size="sm">
            <UTextarea v-model="memoForm.memoDesc" :rows="6" placeholder="輸入情報內容" class="w-full" />
          </UFormField>
        </div>
      </template>

      <template #footer>
        <div class="flex w-full justify-end gap-2">
          <UButton color="neutral" variant="outline" @click="memoModalOpen = false">
            取消
          </UButton>
          <UButton :loading="memoSaving" @click="onSaveMemo">
            儲存
          </UButton>
        </div>
      </template>
    </UModal>
  </div>
</template>
