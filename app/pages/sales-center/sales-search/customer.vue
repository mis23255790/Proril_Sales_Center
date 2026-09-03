<script setup lang="ts">
import type { TableColumn } from '@nuxt/ui'
import type { CustomerWithErp, ErpCustomer } from '~/types/customer'
import { POTENTIAL_CUSTOM_OPTIONS } from '~/types/customer'

definePageMeta({ title: '客戶維護' })

useSeoMeta({ title: '客戶維護 · PRORIL 業務中心' })

const api = useCustomerApi()
const toast = useToast()
const { breadcrumbFor, appPath } = useAppNavigation()

const loading = ref(false)
const customers = ref<CustomerWithErp[]>([])
const erpCustomers = ref<ErpCustomer[]>([])
const userList = ref<{ account: string, userName: string }[]>([])

const filters = reactive({
  customerNo: '',
  erpCustomerNo: ''
})

const customerOptions = computed(() => [
  { label: '-- 選擇內網客戶 --', value: '' },
  ...customers.value.map(c => ({
    label: `${c.customerNo}-${c.shortName ?? ''}`,
    value: c.customerNo ?? ''
  }))
])

const erpCustomerOptions = computed(() => [
  { label: '-- 選擇ERP客戶 --', value: '' },
  ...erpCustomers.value.map(e => ({
    label: `${(e.ma001 ?? '').trim()}-${(e.ma002 ?? '').trim()}`,
    value: (e.ma001 ?? '').trim()
  }))
])

const salesOptions = computed(() => userList.value.map(u => ({ label: u.userName, value: u.account })))

const load = async () => {
  loading.value = true
  try {
    const [customerRes, erpRes] = await Promise.all([
      api.getCustomers(filters.customerNo, filters.erpCustomerNo),
      api.getErpCustomers(filters.erpCustomerNo)
    ])

    // isSuccess: false 不一定是錯誤，查無資料時也是這樣回，當空清單處理。
    customers.value = customerRes?.isSuccess ? (customerRes.body ?? []) : []
    erpCustomers.value = erpRes?.isSuccess ? (erpRes.body ?? []) : []
  } catch (err) {
    console.log('customer load failed -->', err)
    customers.value = []
    erpCustomers.value = []
    toast.add({ title: '查詢失敗', color: 'error' })
  } finally {
    loading.value = false
  }
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
  <div>
    <FullPageLoading :show="loading" />

    <UBreadcrumb :items="breadcrumbFor(appPath('sales-search/customer'))" class="mb-4" />

    <div class="mb-5 flex flex-wrap items-start justify-between gap-3">
      <div>
        <h1 class="text-2xl font-bold text-highlighted">
          客戶維護
        </h1>
        <p class="mt-1 text-sm text-muted">
          查詢內網客戶與 ERP 客戶，並可新增或編輯內網客戶資料、設定 ERP 客戶代碼對應。
        </p>
      </div>
      <UButton icon="i-lucide-user-plus" @click="openAddModal">
        新增客戶
      </UButton>
    </div>

    <!-- 查詢條件 -->
    <div class="mb-4 rounded-lg border border-default bg-elevated/40 p-4">
      <div class="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-4">
        <UFormField label="內網客戶代碼" size="sm">
          <USelectMenu
            v-model="filters.customerNo"
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
            v-model="filters.erpCustomerNo"
            :items="erpCustomerOptions"
            value-key="value"
            label-key="label"
            searchable
            placeholder="-- 選擇ERP客戶 --"
            class="w-full"
          />
        </UFormField>
      </div>

      <div class="mt-3 flex items-center justify-end gap-2">
        <UButton icon="i-lucide-rotate-cw" color="neutral" variant="outline" size="sm" @click="onClickReset">
          重設
        </UButton>
        <UButton icon="i-lucide-search" size="sm" :loading="loading" @click="load">
          查詢
        </UButton>
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
        v-if="activeTab === 'internal'"
        :data="customers"
        :columns="internalColumns"
        :loading="loading"
        :ui="{ td: 'whitespace-nowrap' }"
      >
        <template #actions-cell="{ row }">
          <UButton size="xs" color="primary" variant="outline" @click="openEditModal(row.original)">
            編輯
          </UButton>
        </template>
        <template #empty>
          <p class="py-12 text-center text-sm text-muted">
            沒有符合條件的內網客戶
          </p>
        </template>
      </UTable>

      <UTable
        v-else
        :data="erpCustomers"
        :columns="erpColumns"
        :loading="loading"
        :ui="{ td: 'whitespace-nowrap' }"
      >
        <template #actions-cell="{ row }">
          <UButton size="xs" color="primary" variant="outline" @click="openFromErp(row.original)">
            {{ row.original.customerNo ? '編輯' : '建立客戶' }}
          </UButton>
        </template>
        <template #empty>
          <p class="py-12 text-center text-sm text-muted">
            沒有符合條件的 ERP 客戶
          </p>
        </template>
      </UTable>
    </div>

    <!-- 新增／編輯客戶 -->
    <UModal v-model:open="modalOpen" title="編輯客戶資訊" :ui="{ content: 'max-w-3xl' }">
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
            <p>聯絡人：{{ linkedErpCustomer.ma005 }}　電話：{{ linkedErpCustomer.ma006 }}</p>
            <p>地址：{{ linkedErpCustomer.ma023 }} {{ linkedErpCustomer.ma024 }}</p>
          </div>

          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <UFormField label="客戶名稱" size="sm">
              <UInput v-model="form.shortName" placeholder="輸入客戶名稱" class="w-full" />
            </UFormField>
            <UFormField label="全名" size="sm">
              <UInput v-model="form.longName" placeholder="輸入全名" class="w-full" />
            </UFormField>
            <UFormField label="聯絡人" size="sm">
              <UInput v-model="form.contactName" placeholder="輸入聯絡人" class="w-full" />
            </UFormField>
            <UFormField label="EMail" size="sm">
              <UInput v-model="form.contactEmail" type="email" placeholder="輸入EMail" class="w-full" />
            </UFormField>
            <UFormField label="聯絡電話-1" size="sm">
              <UInput v-model="form.contactTel1" placeholder="輸入聯絡電話-1" class="w-full" />
            </UFormField>
            <UFormField label="聯絡電話-2" size="sm">
              <UInput v-model="form.contactTel2" placeholder="輸入聯絡電話-2" class="w-full" />
            </UFormField>
            <UFormField label="傳真" size="sm">
              <UInput v-model="form.contactFax" placeholder="輸入傳真" class="w-full" />
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
              <UInput v-model="form.addr1" placeholder="輸入地址-1" class="w-full" />
            </UFormField>
            <UFormField label="地址-2" size="sm">
              <UInput v-model="form.addr2" placeholder="輸入地址-2" class="w-full" />
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
