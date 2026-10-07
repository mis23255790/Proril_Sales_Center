<script setup lang="ts">
import type { TableColumn } from '@nuxt/ui'
import type { CustomerWithErp, ErpCustomer } from '~/types/customer'
import { POTENTIAL_CUSTOM_OPTIONS } from '~/types/customer'

definePageMeta({ title: '客戶檢索' })

useSeoMeta({ title: '客戶檢索 · PRORIL 業務中心' })

/** 查詢條件區塊展開／收合（見 useFiltersOpen） */
const filtersOpen = useFiltersOpen('customer')

const api = useCustomerApi()
const toast = useToast()
const { breadcrumbFor, appPath } = useAppNavigation()

const customers = ref<CustomerWithErp[]>([])
const erpCustomers = ref<ErpCustomer[]>([])
const userList = ref<{ account: string, userName: string }[]>([])

const filters = reactive({
  customerNo: '',
  erpCustomerNo: ''
})

/**
 * USelectMenu（Reka UI Combobox）不允許 item 的 value 是空字串（保留給「清空選取」），
 * 用這兩個哨兵值代表「全部」，實際存到 filters.* 的還是空字串，
 * 透過下面的 customerNoSelectValue / erpCustomerNoSelectValue 轉換。
 */
const ALL_CUSTOMER = '__all_customer__'
const ALL_ERP_CUSTOMER = '__all_erp_customer__'

const customerOptions = computed(() => [
  { label: '-- 選擇內網客戶 --', value: ALL_CUSTOMER },
  ...customers.value.map(c => ({
    label: `${c.customerNo}-${c.shortName ?? ''}`,
    value: c.customerNo ?? ''
  }))
])

const erpCustomerOptions = computed(() => [
  { label: '-- 選擇ERP客戶 --', value: ALL_ERP_CUSTOMER },
  ...erpCustomers.value.map(e => ({
    label: `${(e.ma001 ?? '').trim()}-${(e.ma002 ?? '').trim()}`,
    value: (e.ma001 ?? '').trim()
  }))
])

const customerNoSelectValue = computed({
  get: () => filters.customerNo || ALL_CUSTOMER,
  set: (v: string) => { filters.customerNo = v === ALL_CUSTOMER ? '' : v }
})

const erpCustomerNoSelectValue = computed({
  get: () => filters.erpCustomerNo || ALL_ERP_CUSTOMER,
  set: (v: string) => { filters.erpCustomerNo = v === ALL_ERP_CUSTOMER ? '' : v }
})

const salesOptions = computed(() => userList.value.map(u => ({ label: u.userName, value: u.account })))

/**
 * 內網客戶／ERP 客戶兩支 API 各自載入、各自回來就更新各自的表格，
 * 不再用 Promise.all 等兩支都回來。畫面不整頁遮罩，等待中仍可再按查詢，
 * 所以各自帶序號，晚回來的舊回應直接丟掉。
 */
const loadingInternal = ref(false)
const loadingErp = ref(false)
const loading = computed(() => loadingInternal.value || loadingErp.value)
// 不整頁遮罩，改用整頁 wait cursor 提示載入中。
useWaitCursor(loading)

let internalSeq = 0
let erpSeq = 0

const loadInternal = async () => {
  const seq = ++internalSeq
  loadingInternal.value = true
  try {
    const res = await api.getCustomers(filters.customerNo, filters.erpCustomerNo)
    if (seq !== internalSeq) return
    // isSuccess: false 不一定是錯誤，查無資料時也是這樣回，當空清單處理。
    customers.value = res?.isSuccess ? (res.body ?? []) : []
  } catch (err) {
    console.log('customer loadInternal failed -->', err)
    if (seq !== internalSeq) return
    customers.value = []
    toast.add({ title: '內網客戶查詢失敗', color: 'error' })
  } finally {
    if (seq === internalSeq) loadingInternal.value = false
  }
}

const loadErp = async () => {
  const seq = ++erpSeq
  loadingErp.value = true
  try {
    const res = await api.getErpCustomers(filters.erpCustomerNo)
    if (seq !== erpSeq) return
    erpCustomers.value = res?.isSuccess ? (res.body ?? []) : []
  } catch (err) {
    console.log('customer loadErp failed -->', err)
    if (seq !== erpSeq) return
    erpCustomers.value = []
    toast.add({ title: 'ERP 客戶查詢失敗', color: 'error' })
  } finally {
    if (seq === erpSeq) loadingErp.value = false
  }
}

const load = () => {
  loadInternal()
  loadErp()
}

const loadUserList = async () => {
  try {
    const res = await api.getUserList()
    userList.value = res?.isSuccess ? (res.body ?? []) : []
  } catch (err) {
    console.log('customer loadUserList failed -->', err)
    userList.value = []
  }
}

onMounted(() => {
  loadUserList()
  load()
})

const onClickReset = () => {
  filters.customerNo = ''
  filters.erpCustomerNo = ''
  load()
}

// ---------------------------------------------------------------- 頁籤

const activeTab = ref<'internal' | 'erp'>('internal')

const tabItems = [
  { label: '內網客戶', value: 'internal', icon: 'i-lucide-building-2' },
  { label: 'ERP客戶', value: 'erp', icon: 'i-lucide-database' }
] as const

// ---------------------------------------------------------------- 欄位定義

const internalColumns: TableColumn<CustomerWithErp>[] = [
  { accessorKey: 'customerNo', header: '內網客戶代碼' },
  { accessorKey: 'erpcustomerNo', header: 'ERP客戶代碼' },
  { accessorKey: 'erpCustomLongName', header: 'ERP全名' },
  { accessorKey: 'shortName', header: '內網名稱' },
  { accessorKey: 'longName', header: '內網全名' },
  { accessorKey: 'contactName', header: '聯絡人' },
  { accessorKey: 'contactTel1', header: '聯絡電話' },
  { accessorKey: 'salesName', header: '業務名稱' },
  {
    accessorKey: 'potentialCustom',
    header: '潛在客戶',
    cell: ({ row }) => (row.original.potentialCustom === 'Y' ? '是' : '否')
  },
  { id: 'actions', header: '功能' }
]

const erpColumns: TableColumn<ErpCustomer>[] = [
  { accessorKey: 'erpsource', header: '來源' },
  { accessorKey: 'ma001', header: 'ERP客戶代碼' },
  { accessorKey: 'ma002', header: '名稱' },
  { accessorKey: 'ma003', header: '全名' },
  { accessorKey: 'ma005', header: '聯絡人' },
  { accessorKey: 'ma006', header: '聯絡電話' },
  { accessorKey: 'erpheadCustomer', header: '母公司' },
  {
    accessorKey: 'customerNo',
    header: '內網客戶代碼',
    cell: ({ row }) => row.original.customerNo || '（尚未建立）'
  },
  { id: 'actions', header: '功能' }
]

// ---------------------------------------------------------------- 編輯 modal

/**
 * 表單只用得到會編輯的欄位，且一律是字串（不是 null），UInput 的 model-value 才吃得下；
 * 存檔時整包丟給 CustomerRecord（沒編輯到的欄位如 id/aStatus 本來就不用送）。
 */
type CustomerForm = {
  customerNo: string
  erpcustomerNo: string
  shortName: string
  longName: string
  contactName: string
  contactTel1: string
  contactTel2: string
  contactFax: string
  contactEmail: string
  addr1: string
  addr2: string
  salesNo: string
  salesName: string
  potentialCustom: string
}

const modalOpen = ref(false)
const saving = ref(false)
const form = ref<CustomerForm>(blankCustomer())

function blankCustomer(): CustomerForm {
  return {
    customerNo: '',
    erpcustomerNo: '',
    shortName: '',
    longName: '',
    contactName: '',
    contactTel1: '',
    contactTel2: '',
    contactFax: '',
    contactEmail: '',
    addr1: '',
    addr2: '',
    salesNo: '',
    salesName: '',
    potentialCustom: 'N'
  }
}

/** CustomerWithErp／ErpCustomer（可能有 null 欄位）轉成表單用的純字串版本。 */
function toForm(record: Partial<Record<keyof CustomerForm, string | null | undefined>>): CustomerForm {
  const blank = blankCustomer()
  const result = { ...blank }
  for (const key of Object.keys(blank) as (keyof CustomerForm)[]) {
    const value = record[key]
    if (value !== null && value !== undefined) result[key] = value
  }
  return result
}

/** 目前選到的 ERP 客戶（依 form.erpcustomerNo 對照），modal 裡唯讀顯示 ERP 端資料參考用。 */
const linkedErpCustomer = computed(() =>
  erpCustomers.value.find(e => (e.ma001 ?? '').trim() === (form.value.erpcustomerNo ?? '').trim()) ?? null
)

const onErpCustomerChange = (erpNo: string) => {
  form.value.erpcustomerNo = erpNo
}

const onSalesChange = (account: string) => {
  form.value.salesNo = account
  form.value.salesName = userList.value.find(u => u.account === account)?.userName ?? ''
}

const openAddModal = () => {
  form.value = blankCustomer()
  modalOpen.value = true
}

/** 從 ERP 客戶頁籤建立/編輯客戶：已連結客戶就帶入既有資料，否則以 ERP 資料當起始值。 */
const openFromErp = (row: ErpCustomer) => {
  if (row.customerNo) {
    const existing = customers.value.find(c => (c.customerNo ?? '').trim() === row.customerNo.trim())
    form.value = existing ? toForm(existing) : blankCustomer()
  } else {
    form.value = toForm({
      erpcustomerNo: (row.ma001 ?? '').trim(),
      shortName: row.ma002 ?? '',
      longName: row.ma003 ?? '',
      contactName: row.ma005 ?? '',
      contactTel1: row.ma006 ?? '',
      potentialCustom: 'N'
    })
  }
  modalOpen.value = true
}

const openEditModal = (row: CustomerWithErp) => {
  form.value = toForm(row)
  modalOpen.value = true
}

/**
 * 客戶相關資訊（1.0 的 Mix/CustomerRelated）。整列點擊就是進這裡，編輯留在功能欄按鈕。
 *
 * 兩個客編都帶：內網客編給情報／議題用，ERP 客編給訂單／銷售／信用額度用，
 * 那一頁分得很清楚，不能只帶一個。從 ERP 客戶頁籤點進來時內網客編可能是空的，
 * 那一頁會自己用 ERP 客編反查。
 */
const openRelated = (customerNo?: string | null, erpCustomerNo?: string | null) =>
  navigateTo({
    path: appPath('sales-search/customer-related'),
    query: {
      customer: (customerNo ?? '').trim(),
      erpCustomerNo: (erpCustomerNo ?? '').trim()
    }
  })

const onSave = async () => {
  if (!form.value.shortName?.trim() && !form.value.longName?.trim()) {
    toast.add({ title: '請至少輸入客戶名稱或全名', color: 'warning' })
    return
  }

  saving.value = true
  try {
    const res = await api.saveCustomer(form.value)
    if (!res?.isSuccess) {
      toast.add({ title: '存檔失敗', description: res?.message ?? '', color: 'error' })
      return
    }
    toast.add({ title: '資料已存檔', color: 'success' })
    modalOpen.value = false
    load()
  } catch (err) {
    console.log('customer onSave failed -->', err)
    toast.add({ title: '存檔失敗', color: 'error' })
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="flex min-h-0 flex-1 flex-col">
    <!--
      整頁撐滿右側面板（UDashboardPanel body 是 flex-col），表格吃掉剩下的高度、自己捲動，
      面板外框不出現捲軸。畫面太矮時表格至少保留 16rem，才退回由面板捲動。
    -->
    <!-- 不用 FullPageLoading 整頁遮罩：查詢條件與頁籤一開始就可操作，兩個表格各自等 API 回來才更新。 -->
    <UBreadcrumb v-if="false" :items="breadcrumbFor(appPath('sales-search/customer'))" class="mb-4" />

    <!-- 查詢條件 -->
    <!-- 重設／查詢跟欄位同一行（靠右、對齊輸入框），不另外佔一列；畫面窄時才換行 -->
    <div class="mb-4 flex flex-wrap items-end gap-3 rounded-lg border border-default bg-elevated/40 p-4">
      <FilterToggleButton v-model="filtersOpen" />
      <div v-show="filtersOpen" class="grid min-w-0 flex-1 grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-4">
        <UFormField label="內網客戶代碼" size="sm">
          <USelectMenu
            v-model="customerNoSelectValue"
            :items="customerOptions"
            value-key="value"
            label-key="label"
            searchable
            placeholder="-- 選擇內網客戶 --"
            class="w-full"
          />
        </UFormField>

        <UFormField label="ERP客戶代碼" size="sm">
          <USelectMenu
            v-model="erpCustomerNoSelectValue"
            :items="erpCustomerOptions"
            value-key="value"
            label-key="label"
            searchable
            placeholder="-- 選擇ERP客戶 --"
            class="w-full"
          />
        </UFormField>
      </div>

      <div class="ms-auto flex items-center gap-2">
        <UButton icon="i-lucide-rotate-cw" color="neutral" variant="outline" size="sm" @click="onClickReset">
          重設
        </UButton>
        <UButton icon="i-lucide-search" size="sm" :loading="loading" @click="load">
          查詢
        </UButton>
      </div>
    </div>

    <!-- 頁籤 + 新增客戶（頁面名稱在頂部導覽列，新增按鈕跟頁籤放同一行） -->
    <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
      <div class="flex flex-wrap gap-2">
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
      <UButton icon="i-lucide-user-plus" size="sm" @click="openAddModal">
        新增客戶
      </UButton>
    </div>

    <!--
      表頭 sticky：外層不能再包 overflow-x-auto（會變成另一個捲動容器讓 sticky 失效），
      改由 UTable 自己的根節點（預設 overflow-auto）捲動；高度由 flex-1 撐滿剩餘空間，不用固定 max-h。
    -->
    <div class="flex min-h-64 flex-1 flex-col overflow-hidden rounded-lg border border-default">
      <UTable
        v-if="activeTab === 'internal'"
        sticky
        class="min-h-0 flex-1"
        :data="customers"
        :columns="internalColumns"
        :loading="loadingInternal"
        :ui="{ tr: clickableRowTr, td: 'whitespace-nowrap' }"
        @select="(_e: Event, row: any) => openRelated(row.original.customerNo, row.original.erpcustomerNo)"
      >
        <template #actions-cell="{ row }">
          <div @click.stop>
            <UButton
              size="xs"
              color="primary"
              variant="outline"
              icon="i-lucide-square-pen"
              @click="openEditModal(row.original)"
            >
              編輯基本資料
            </UButton>
          </div>
        </template>
        <template #empty>
          <p class="py-12 text-center text-sm text-muted">
            沒有符合條件的內網客戶
          </p>
        </template>
      </UTable>

      <UTable
        v-else
        sticky
        class="min-h-0 flex-1"
        :data="erpCustomers"
        :columns="erpColumns"
        :loading="loadingErp"
        :ui="{ tr: clickableRowTr, td: 'whitespace-nowrap' }"
        @select="(_e: Event, row: any) => openRelated(row.original.customerNo, row.original.ma001)"
      >
        <template #actions-cell="{ row }">
          <div @click.stop>
            <UButton
              size="xs"
              color="primary"
              variant="outline"
              :icon="row.original.customerNo ? 'i-lucide-square-pen' : 'i-lucide-user-plus'"
              @click="openFromErp(row.original)"
            >
              {{ row.original.customerNo ? '編輯基本資料' : '建立內網客戶' }}
            </UButton>
          </div>
        </template>
        <template #empty>
          <p class="py-12 text-center text-sm text-muted">
            沒有符合條件的 ERP 客戶
          </p>
        </template>
      </UTable>
    </div>

    <!-- 新增／編輯客戶 -->
    <UModal v-model:open="modalOpen" title="客戶基本資料" :ui="{ content: 'max-w-3xl' }">
      <template #body>
        <div class="flex flex-col gap-4">
          <UFormField label="內網客戶代碼" size="sm">
            <UInput :model-value="form.customerNo || '（存檔後自動產生）'" readonly class="w-full" />
          </UFormField>

          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <UFormField label="ERP客戶代碼" size="sm">
              <USelectMenu
                :model-value="form.erpcustomerNo ?? ''"
                :items="erpCustomerOptions"
                value-key="value"
                label-key="label"
                searchable
                placeholder="-- 未關聯 ERP 客戶 --"
                class="w-full"
                @update:model-value="onErpCustomerChange"
              />
            </UFormField>

            <UFormField label="潛在客戶" size="sm">
              <USelectMenu
                v-model="form.potentialCustom"
                :items="POTENTIAL_CUSTOM_OPTIONS"
                value-key="value"
                label-key="label"
                class="w-full"
              />
            </UFormField>
          </div>

          <div v-if="linkedErpCustomer" class="rounded-lg border border-default bg-elevated/40 p-3 text-xs text-muted">
            <p class="mb-1 font-medium text-highlighted">
              ERP 資料參考（唯讀）
            </p>
            <p>{{ linkedErpCustomer.ma002 }} / {{ linkedErpCustomer.ma003 }}</p>
            <p>聯絡人：{{ linkedErpCustomer.ma005 }}&#x3000;電話：{{ linkedErpCustomer.ma006 }}</p>
            <p>地址：{{ linkedErpCustomer.ma023 }} {{ linkedErpCustomer.ma024 }}</p>
          </div>

          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <UFormField label="客戶名稱" size="sm">
              <ClearInput v-model="form.shortName" placeholder="輸入客戶名稱" class="w-full" />
            </UFormField>
            <UFormField label="全名" size="sm">
              <ClearInput v-model="form.longName" placeholder="輸入全名" class="w-full" />
            </UFormField>
            <UFormField label="聯絡人" size="sm">
              <ClearInput v-model="form.contactName" placeholder="輸入聯絡人" class="w-full" />
            </UFormField>
            <UFormField label="EMail" size="sm">
              <ClearInput v-model="form.contactEmail" type="email" placeholder="輸入EMail" class="w-full" />
            </UFormField>
            <UFormField label="聯絡電話-1" size="sm">
              <ClearInput v-model="form.contactTel1" placeholder="輸入聯絡電話-1" class="w-full" />
            </UFormField>
            <UFormField label="聯絡電話-2" size="sm">
              <ClearInput v-model="form.contactTel2" placeholder="輸入聯絡電話-2" class="w-full" />
            </UFormField>
            <UFormField label="傳真" size="sm">
              <ClearInput v-model="form.contactFax" placeholder="輸入傳真" class="w-full" />
            </UFormField>
            <UFormField label="業務負責人" size="sm">
              <USelectMenu
                :model-value="form.salesNo ?? ''"
                :items="salesOptions"
                value-key="value"
                label-key="label"
                searchable
                placeholder="-- 設定業務負責人 --"
                class="w-full"
                @update:model-value="onSalesChange"
              />
            </UFormField>
            <UFormField label="地址-1" size="sm">
              <ClearInput v-model="form.addr1" placeholder="輸入地址-1" class="w-full" />
            </UFormField>
            <UFormField label="地址-2" size="sm">
              <ClearInput v-model="form.addr2" placeholder="輸入地址-2" class="w-full" />
            </UFormField>
          </div>
        </div>
      </template>

      <template #footer>
        <div class="flex w-full justify-end gap-2">
          <UButton color="neutral" variant="outline" @click="modalOpen = false">
            取消
          </UButton>
          <UButton :loading="saving" @click="onSave">
            存檔
          </UButton>
        </div>
      </template>
    </UModal>
  </div>
</template>
