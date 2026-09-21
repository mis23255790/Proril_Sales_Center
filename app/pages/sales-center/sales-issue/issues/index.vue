<script setup lang="ts">
import type { TableColumn } from '@nuxt/ui'
import type { CrmCustomer, SalesIssueListSummary, SalesIssueRow, WorkPhrase } from '~/types/salesIssue'
import { PHRASE_TYPE } from '~/types/salesIssue'
import ConfirmDialog from '~/components/common/ConfirmDialog.vue'

definePageMeta({ title: '議題維護' })

useSeoMeta({ title: '議題維護 · PRORIL 業務中心' })

const api = useSalesIssueApi()
const toast = useToast()
const overlay = useOverlay()
const { breadcrumbFor, appPath } = useAppNavigation()
const { pagination } = useTablePagination(20)
const table = useTemplateRef('table')

const loading = ref(false)
const rows = ref<SalesIssueRow[]>([])
const categories = ref<WorkPhrase[]>([])
const customers = ref<CrmCustomer[]>([])

const EMPTY_SUMMARY: SalesIssueListSummary = { totalCount: 0, ongoingCount: 0, finishedCount: 0, allCount: 0 }
/** 三個狀態頁籤的筆數 + 目前頁籤篩選後的總筆數，後端算好放在 body2。 */
const summary = ref<SalesIssueListSummary>({ ...EMPTY_SUMMARY })

/**
 * 查詢條件，全部都是後端過濾（含日期區間與快速搜尋，2026-09-18 起改回後端做，
 * 分頁才有正確的基準——分頁跟「只篩前端目前結果」是互斥的）。改這些要重新查詢並跳回第一頁。
 */
const filters = reactive({
  category: '',
  customer: '',
  caption: '',
  content: '',
  keyword: '',
  startDate: '',
  endDate: ''
})

const activeTab = ref<'ongoing' | 'finished' | 'all'>('ongoing')

/** 送出目前的篩選條件、頁籤、分頁狀態，實際打 API 的唯一入口。 */
const load = async () => {
  loading.value = true
  try {
    const res = await api.getIssueList({
      ...filters,
      tab: activeTab.value,
      pageIndex: pagination.value.pageIndex,
      // ALL_PAGE_SIZE 是前端「全部」選項的哨兵值，後端用 pageSize <= 0 代表不分頁
      pageSize: pagination.value.pageSize >= ALL_PAGE_SIZE ? 0 : pagination.value.pageSize
    })
    // 查無資料時後端回 isSuccess: false + 說明訊息，不是錯誤，不要跳 toast。
    rows.value = res?.isSuccess ? (res.body ?? []).map(toIssueRow) : []
    summary.value = res?.body2 ?? { ...EMPTY_SUMMARY }
  } catch (err) {
    console.log('issues load failed -->', err)
    rows.value = []
    summary.value = { ...EMPTY_SUMMARY }
  } finally {
    loading.value = false
  }
}

/** 篩選條件變更：跳回第一頁再查詢。分頁列自己翻頁則不會經過這裡，見 onPaginationUpdate。 */
const search = () => {
  pagination.value.pageIndex = 0
  load()
}

const selectTab = (value: 'ongoing' | 'finished' | 'all') => {
  activeTab.value = value
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

const loadCategories = async () => {
  try {
    const res = await api.getPhrases(PHRASE_TYPE.CATEGORY)
    categories.value = res?.isSuccess ? (res.body ?? []) : []
  } catch (err) {
    console.log('issues loadCategories failed -->', err)
    categories.value = []
  }
}

/** 客戶別下拉的選項來源，跟議題編輯頁同一支 CRM 客戶清單（api.getCustomers）。 */
const loadCustomers = async () => {
  try {
    const res = await api.getCustomers()
    customers.value = res?.isSuccess ? (res.body ?? []) : []
  } catch (err) {
    console.log('issues loadCustomers failed -->', err)
    customers.value = []
  }
}

onMounted(() => {
  load()
  loadCategories()
  loadCustomers()
})

/**
 * USelectMenu（Reka UI Combobox）不允許 item 的 value 是空字串（保留給「清空選取」），
 * 用這個哨兵值代表「全部類別」，實際存到 filters.category 的還是空字串，
 * 透過下面的 categorySelectValue 轉換。
 */
const ALL_CATEGORY = '__all_category__'

const categoryOptions = computed(() => [
  { label: '全部類別', value: ALL_CATEGORY },
  ...categories.value.map(c => ({ label: c.phraseName, value: c.phraseName }))
])

const categorySelectValue = computed({
  get: () => filters.category || ALL_CATEGORY,
  set: (v: string) => { filters.category = v === ALL_CATEGORY ? '' : v }
})

/**
 * 客戶別選項同樣用哨兵值代表「全部客戶」，實際送給後端的還是 shortName——
 * GetSOPList_Edit 的 type3_phrase_name 是拿去 Contains 比對 CustomerName（= CRM ShortName），
 * 不是比對舊版 phraseType 03 職能主題，見 docs/modules/SalesIssue/logic.md。
 */
const ALL_CUSTOMER = '__all_customer__'

const customerOptions = computed(() => [
  { label: '全部客戶', value: ALL_CUSTOMER },
  ...customers.value
    .filter(c => (c.shortName ?? '').trim())
    .map(c => ({ label: `${(c.shortName ?? '').trim()}(${String(c.customerNo ?? '').trim()})`, value: (c.shortName ?? '').trim() }))
])

const customerSelectValue = computed({
  get: () => filters.customer || ALL_CUSTOMER,
  set: (v: string) => { filters.customer = v === ALL_CUSTOMER ? '' : v }
})

const resetFilters = () => {
  filters.category = ''
  filters.customer = ''
  filters.caption = ''
  filters.content = ''
  filters.keyword = ''
  filters.startDate = ''
  filters.endDate = ''
  search()
}

const activeFilterCount = computed(() =>
  [filters.category, filters.customer, filters.caption, filters.content,
    filters.keyword, filters.startDate, filters.endDate]
    .filter(Boolean).length
)

/** 用「最後修改時間」比對，沒有的話退回建立時間，純顯示格式化用（篩選已經是後端做的）。 */
const rowTime = (row: SalesIssueRow) => row.lastModiTime || row.modiTime || row.createTime || ''

const tabItems = computed(() => [
  { label: '進行中', value: 'ongoing', icon: 'i-lucide-circle-dot', count: summary.value.ongoingCount },
  { label: '結案', value: 'finished', icon: 'i-lucide-circle-check', count: summary.value.finishedCount },
  { label: '全部', value: 'all', icon: 'i-lucide-list', count: summary.value.allCount }
])

/**
 * 表頭排序只在「目前這一頁」的資料內排序，不是全體資料排序 —— 後端已經把資料切頁，
 * 前端拿不到其他頁的內容可以排。要做到全體排序得讓後端也收排序欄位，目前先不做。
 */
const sorting = ref([{ id: 'lastModiTime', desc: true }])

/**
 * 欄寬。
 *
 * Nuxt UI 的 UTable 預設在 `td` 上掛 `whitespace-nowrap`，長標題不會換行，
 * 會直接溢出去蓋掉右邊的欄位（議題主題動輒幾十個字）。
 * 所以下面兩件事要一起做，少一件都沒用：
 *   1. UTable 的 `:ui.td` 覆寫成 `whitespace-normal`，讓它可以換行
 *   2. 每欄用 `meta.class.td/th` 給一個 max-w，否則 table-layout: auto
 *      會讓內容自己決定寬度，換行也不會發生
 * 內層再配 line-clamp 限制行數，避免某一列高到誇張。
 */
const cellWidth = (className: string) => ({ class: { td: className, th: className } })

const columns: TableColumn<SalesIssueRow>[] = [
  { accessorKey: 'sopTitle', header: '議題', meta: cellWidth('max-w-[22rem] min-w-[14rem]') },
  { accessorKey: 'customers', header: '客戶別', enableSorting: false, meta: cellWidth('max-w-[10rem]') },
  { accessorKey: 'categories', header: '類別', enableSorting: false, meta: cellWidth('max-w-[9rem]') },
  { accessorKey: 'descript', header: '最新進度', enableSorting: false, meta: cellWidth('max-w-[18rem]') },
  { accessorKey: 'lastModifierName', header: '最後修改', meta: cellWidth('max-w-[8rem]') },
  { accessorKey: 'lastModiTime', header: '修改時間' },
  { accessorKey: 'createDate', header: '建立日期' },
  { id: 'actions', header: '功能', enableSorting: false }
]

const openIssue = (row: SalesIssueRow) => navigateTo(appPath(`sales-issue/issues/${padWpno(row.wpno)}`))

const createIssue = () => navigateTo(appPath('sales-issue/issues/new'))

const confirmModal = overlay.create(ConfirmDialog)

const removeIssue = async (row: SalesIssueRow) => {
  try {
    const confirmed = await confirmModal.open({
      title: '刪除議題',
      description: `確定要刪除「${row.sopTitle || row.wpno}」？刪除後不會出現在列表，但資料仍保留在資料庫。`,
      confirmLabel: '刪除',
      confirmColor: 'error'
    }).result

    if (!confirmed) return

    const res = await api.disableIssue(row.wpno)
    if (!res?.isSuccess) {
      toast.add({ title: '刪除失敗', description: res?.message ?? '', color: 'error' })
      return
    }
    toast.add({ title: '已刪除', color: 'success' })
    await load()
  } catch (err) {
    console.log('issues removeIssue failed -->', err)
    toast.add({ title: '刪除失敗', color: 'error' })
  }
}
</script>

<template>
  <div>
    <FullPageLoading :show="loading" />

    <UBreadcrumb v-if="false" :items="breadcrumbFor(appPath('sales-issue/issues'))" class="mb-4" />

    <div class="mb-5 flex flex-wrap items-start justify-between gap-3">
      <div>
        <h1 class="text-2xl font-bold text-highlighted">
          議題維護
        </h1>
        <p class="mt-1 text-sm text-muted">
          追蹤各客戶的業務議題、最新進度與相關附件。
        </p>
      </div>

      <div class="flex items-center gap-2">
        <UButton icon="i-lucide-rotate-cw" color="neutral" variant="outline" :loading="loading" @click="load">
          重新整理
        </UButton>
        <UButton icon="i-lucide-plus" @click="createIssue">
          新增議題
        </UButton>
      </div>
    </div>

    <!-- 查詢條件 -->
    <div class="mb-4 rounded-lg border border-default bg-elevated/40 p-4">
      <div class="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-4">
        <UFormField label="類別" size="sm">
          <USelectMenu
            v-model="categorySelectValue"
            :items="categoryOptions"
            value-key="value"
            label-key="label"
            placeholder="全部類別"
            class="w-full"
            @update:model-value="search"
          />
        </UFormField>

        <UFormField label="客戶別" size="sm">
          <USelectMenu
            v-model="customerSelectValue"
            :items="customerOptions"
            value-key="value"
            label-key="label"
            placeholder="全部客戶"
            class="w-full"
            @update:model-value="search"
          />
        </UFormField>

        <UFormField label="標題 / 大綱關鍵字" size="sm">
          <UInput v-model="filters.caption" placeholder="議題主題或內容說明" class="w-full" @keyup.enter="search" />
        </UFormField>

        <UFormField label="內文關鍵字" size="sm">
          <UInput v-model="filters.content" placeholder="進度內文" class="w-full" @keyup.enter="search" />
        </UFormField>

        <UFormField label="最後修改（起）" size="sm">
          <UInput v-model="filters.startDate" type="date" class="w-full" @change="search" />
        </UFormField>

        <UFormField label="最後修改（迄）" size="sm">
          <UInput v-model="filters.endDate" type="date" class="w-full" @change="search" />
        </UFormField>

        <UFormField label="快速搜尋" size="sm" class="xl:col-span-2">
          <UInput
            v-model="filters.keyword"
            icon="i-lucide-search"
            placeholder="搜尋編號 / 主題 / 進度 / 人員 / 類別 / 客戶別"
            class="w-full"
            @keyup.enter="search"
          />
        </UFormField>
      </div>

      <div class="mt-3 flex items-center justify-between gap-2">
        <p class="text-xs text-muted">
          所有查詢條件都會重新向後端查詢；三個狀態頁籤的筆數也是後端算好的。
        </p>
        <div class="flex items-center gap-2">
          <UButton
            v-if="activeFilterCount > 0"
            icon="i-lucide-x"
            color="neutral"
            variant="ghost"
            size="sm"
            @click="resetFilters"
          >
            清除條件 ({{ activeFilterCount }})
          </UButton>
          <UButton icon="i-lucide-search" size="sm" :loading="loading" @click="search">
            查詢
          </UButton>
        </div>
      </div>
    </div>

    <!-- 狀態頁籤 -->
    <div class="mb-3 flex flex-wrap gap-2">
      <UButton
        v-for="tab in tabItems"
        :key="tab.value"
        :icon="tab.icon"
        :color="activeTab === tab.value ? 'primary' : 'neutral'"
        :variant="activeTab === tab.value ? 'solid' : 'outline'"
        size="sm"
        @click="selectTab(tab.value as typeof activeTab)"
      >
        {{ tab.label }}
        <UBadge :color="activeTab === tab.value ? 'neutral' : 'primary'" variant="subtle" size="sm">
          {{ tab.count }}
        </UBadge>
      </UButton>
    </div>

    <div class="overflow-hidden rounded-lg border border-default">
      <UTable
        ref="table"
        :pagination="pagination"
        v-model:sorting="sorting"
        :pagination-options="{ manualPagination: true, rowCount: summary.totalCount }"
        :data="rows"
        :columns="columns"
        :loading="loading"
        :ui="{ tr: clickableRowTr, td: 'align-top whitespace-normal' }"
        @update:pagination="onPaginationUpdate"
        @select="(_e: Event, row: any) => openIssue(row.original)"
      >
        <template #sopTitle-cell="{ row }">
          <div>
            <p class="line-clamp-2 break-words font-medium text-highlighted" :title="row.original.sopTitle || ''">
              {{ row.original.sopTitle || '（未命名議題）' }}
            </p>
            <p class="mt-0.5 flex items-center gap-2 text-xs text-muted">
              <span>#{{ padWpno(row.original.wpno) }}</span>
              <UBadge v-if="row.original.finFlag" color="success" variant="subtle" size="sm">
                結案
              </UBadge>
              <UBadge v-if="row.original.pubFlag" color="info" variant="subtle" size="sm">
                公開
              </UBadge>
            </p>
          </div>
        </template>

        <template #customers-cell="{ row }">
          <div class="flex flex-wrap gap-1">
            <UBadge v-for="name in row.original.customers" :key="name" color="primary" variant="subtle" size="sm">
              {{ name }}
            </UBadge>
            <span v-if="!row.original.customers.length" class="text-xs text-dimmed">—</span>
          </div>
        </template>

        <template #categories-cell="{ row }">
          <div class="flex flex-wrap gap-1">
            <UBadge v-for="name in row.original.categories" :key="name" color="neutral" variant="subtle" size="sm">
              {{ name }}
            </UBadge>
            <span v-if="!row.original.categories.length" class="text-xs text-dimmed">—</span>
          </div>
        </template>

        <template #descript-cell="{ row }">
          <p class="line-clamp-3 whitespace-pre-line break-words text-sm text-toned" :title="row.original.descript || ''">
            {{ row.original.descript || '—' }}
          </p>
        </template>

        <template #lastModifierName-cell="{ row }">
          <span class="text-sm">{{ row.original.lastModifierName || row.original.userName || '—' }}</span>
        </template>

        <template #lastModiTime-cell="{ row }">
          <span class="whitespace-nowrap text-sm text-muted">{{ toDateString(rowTime(row.original)) || '—' }}</span>
        </template>

        <template #createDate-cell="{ row }">
          <span class="whitespace-nowrap text-sm text-muted">{{ row.original.createDate || '—' }}</span>
        </template>

        <template #actions-cell="{ row }">
          <div class="flex items-center gap-1" @click.stop>
            <UButton
              icon="i-lucide-pencil"
              color="primary"
              variant="ghost"
              size="xs"
              title="編輯"
              @click="openIssue(row.original)"
            />
            <UButton
              icon="i-lucide-trash-2"
              color="error"
              variant="ghost"
              size="xs"
              title="刪除"
              @click="removeIssue(row.original)"
            />
          </div>
        </template>

        <template #empty>
          <div class="flex flex-col items-center gap-2 py-12 text-center">
            <UIcon name="i-lucide-inbox" class="size-8 text-dimmed" />
            <p class="font-medium text-highlighted">
              沒有符合條件的議題
            </p>
            <p class="text-sm text-muted">
              調整查詢條件，或直接新增一筆議題。
            </p>
          </div>
        </template>
      </UTable>

      <TablePaginationBar :table="table" :total="summary.totalCount" />
    </div>
  </div>
</template>
