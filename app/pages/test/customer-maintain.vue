<script setup lang="ts">
import { getPaginationRowModel } from '@tanstack/vue-table'
import type { TableColumn } from '@nuxt/ui'
import type { MCustomer } from '~/types/test'

const { apiFetch } = useApi()
const toast = useToast()
const { pagination } = useTablePagination()
const table = useTemplateRef('table')

const loading = ref(false)
const importing = ref(false)
const customers = ref<MCustomer[]>([])
const search = ref('')

const fetchCustomers = async () => {
  loading.value = true
  try {
    customers.value = await apiFetch<MCustomer[]>('/CustomerApi/GetCustomerList') ?? []
  } catch {
    customers.value = []
  } finally {
    loading.value = false
  }
}

onMounted(fetchCustomers)

const filtered = computed(() => {
  if (!search.value) return customers.value
  const kw = search.value.toLowerCase()
  return customers.value.filter(c =>
    c.customerNo?.toLowerCase().includes(kw)
    || c.longName?.toLowerCase().includes(kw)
    || c.shortName?.toLowerCase().includes(kw)
  )
})

watch(search, () => { pagination.value.pageIndex = 0 })

const detailOpen = ref(false)
const selected = ref<MCustomer | null>(null)

const openDetail = (row: MCustomer) => {
  selected.value = row
  detailOpen.value = true
}

const copyEmail = async (email?: string) => {
  if (!email) return
  await navigator.clipboard.writeText(email)
  toast.add({ title: '信箱已複製', color: 'success' })
}

const runImport = async () => {
  importing.value = true
  try {
    await apiFetch<boolean>('/ErpImportApi/ImportAllCustomer')
    toast.add({ title: 'ERP 客戶資料匯入完成', color: 'success' })
    await fetchCustomers()
  } finally {
    importing.value = false
  }
}

const columns: TableColumn<MCustomer>[] = [
  { accessorKey: 'customerNo', header: '代碼' },
  { accessorKey: 'longName', header: '名稱' },
  { accessorKey: 'shortName', header: '簡稱' }
]
</script>

<template>
  <div>
    <FullPageLoading :show="loading" />

    <UBreadcrumb :items="[{ label: '首頁', to: '/', icon: 'i-lucide-house' }, { label: '測試系統', icon: 'i-lucide-flask-conical' }, { label: '資料管理' }, { label: '客戶資料維護' }]" class="mb-4" />

    <h1 class="mb-4 text-2xl font-bold text-highlighted">
      客戶資料維護
    </h1>

    <div class="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center">
      <UInput v-model="search" icon="i-lucide-search" placeholder="搜尋代碼/名稱..." class="w-56" />
      <UButton icon="i-lucide-refresh-cw" color="neutral" variant="outline" :loading="importing" class="sm:ml-auto" @click="runImport">
        手動匯入 ERP 資料
      </UButton>
    </div>

    <div class="overflow-hidden rounded-lg border border-default">
      <UTable
        ref="table"
        v-model:pagination="pagination"
        :pagination-options="{ getPaginationRowModel: getPaginationRowModel() }"
        :data="filtered"
        :columns="columns"
        :loading="loading"
        :ui="{ tr: 'cursor-pointer' }"
        @select="(_e: Event, row: any) => openDetail(row.original)"
      />
      <TablePaginationBar :table="table" />
    </div>

    <USlideover v-model:open="detailOpen" title="客戶詳細資料" :description="selected?.customerNo">
      <template #body>
        <div v-if="selected" class="space-y-6">
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <UFormField label="客戶編號">
              <UInput :model-value="selected.customerNo" disabled />
            </UFormField>
            <UFormField label="客戶名稱">
              <UInput :model-value="selected.longName" disabled />
            </UFormField>
            <UFormField label="客戶簡稱">
              <UInput :model-value="selected.shortName" disabled />
            </UFormField>
            <UFormField label="出貨港">
              <UInput :model-value="selected.ship" disabled />
            </UFormField>
            <UFormField label="運輸方式">
              <UInput :model-value="selected.transport" disabled />
            </UFormField>
            <UFormField label="聯絡人">
              <UInput :model-value="selected.contactName" disabled />
            </UFormField>
            <UFormField label="聯絡電話">
              <UInput :model-value="selected.contactPhone" disabled />
            </UFormField>
            <UFormField label="聯絡 E-Mail">
              <div class="flex gap-2">
                <UInput :model-value="selected.contactEmail" disabled class="flex-1" />
                <UButton icon="i-lucide-mail" variant="outline" color="neutral" :to="`mailto:${selected.contactEmail}`" />
                <UButton icon="i-lucide-copy" variant="outline" color="neutral" @click="copyEmail(selected.contactEmail)" />
              </div>
            </UFormField>
          </div>

          <USeparator />

          <TestMemoPanel :link-type="2" :link-number="selected.customerNo" />
        </div>
      </template>
    </USlideover>
  </div>
</template>
