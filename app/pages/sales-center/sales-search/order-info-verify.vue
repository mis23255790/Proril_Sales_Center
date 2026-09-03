<script setup lang="ts">
import { h, resolveComponent } from 'vue'
import type { TableColumn } from '@nuxt/ui'
import type { CopCheckRule, OrderInfoVerifyGroup } from '~/types/orderInfoVerify'
import { ORDER_INFO_VERIFY_AMOUNT_LINK_TYPE, ORDER_INFO_VERIFY_FUNCTION_NO } from '~/types/orderInfoVerify'
import type { SalesShippingCustomer } from '~/types/salesShipping'
import { chkBadgeColor, chkBadgeLabel, feFinChk, groupOrderInfoVerifyRows } from '~/utils/orderInfoVerify'

definePageMeta({ title: '訂單資料檢核' })

useSeoMeta({ title: '訂單資料檢核 · PRORIL 業務中心' })

const api = useOrderInfoVerifyApi()
const { checkLinkTypePermission } = usePermission()
const toast = useToast()
const { breadcrumbFor, appPath } = useAppNavigation()

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
    console.log('order-info-verify loadCustomers failed -->', err)
    customers.value = []
  }
}

const loadPermission = async () => {
  try {
    showAmount.value = await checkLinkTypePermission(ORDER_INFO_VERIFY_FUNCTION_NO, ORDER_INFO_VERIFY_AMOUNT_LINK_TYPE)
  } catch (err) {
    console.log('order-info-verify loadPermission failed -->', err)
    showAmount.value = false
  }
}

const groups = ref<OrderInfoVerifyGroup[]>([])

const notCheckedGroups = computed(() => groups.value.filter(g => g.confirmFlag !== 'Y'))
const checkedGroups = computed(() => groups.value.filter(g => g.confirmFlag === 'Y'))

const load = async () => {
  loading.value = true
  try {
    const res = await api.getPOCheckView({
      customerNo: filters.customerNo,
      orderType: filters.orderType.trim(),
      startDate: toCompactDate(filters.startDate),
      endDate: toCompactDate(filters.endDate)
    })
    groups.value = res?.isSuccess ? groupOrderInfoVerifyRows(res.body ?? []) : []
    if (res && !res.isSuccess && res.message) {
      toast.add({ title: '查無資料', description: res.message, color: 'warning' })
    }
  } catch (err) {
    console.log('order-info-verify load failed -->', err)
    groups.value = []
    toast.add({ title: '查詢失敗', color: 'error' })
  } finally {
    loading.value = false
  }
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

    <UBreadcrumb :items="breadcrumbFor(appPath('sales-search/order-info-verify'))" class="mb-4" />

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
          <UInput v-model="filters.orderType" placeholder="訂單單別" class="w-full" @keyup.enter="load" />
        </UFormField>

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
        <UButton icon="i-lucide-search" size="sm" :loading="loading" @click="load">
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
          @click="activeTab = 'notChecked'"
        >
          未確認訂單
        </UButton>
        <UButton
          icon="i-lucide-check-circle"
          :color="activeTab === 'checked' ? 'primary' : 'neutral'"
          :variant="activeTab === 'checked' ? 'solid' : 'outline'"
          size="sm"
          @click="activeTab = 'checked'"
        >
          已確認訂單
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
        :data="activeTab === 'notChecked' ? notCheckedGroups : checkedGroups"
        :columns="columns"
        :loading="loading"
        :ui="{ td: 'whitespace-nowrap' }"
      >
        <template #actions-cell="{ row }">
          <UButton size="xs" color="primary" variant="outline" @click="openDetail(row.original)">
            檢核結果
          </UButton>
        </template>
        <template #empty>
          <p class="py-12 text-center text-sm text-muted">
            沒有符合條件的訂單
          </p>
        </template>
      </UTable>
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
