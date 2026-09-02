<script setup lang="ts">
import { getPaginationRowModel } from '@tanstack/vue-table'
import type { TableColumn } from '@nuxt/ui'
import type { SalesIssueRow, WorkPhrase } from '~/types/salesIssue'
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

/** 後端可以過濾的條件。改這些要重新查詢。 */
const filters = reactive({
  category: '',
  customer: '',
  caption: '',
  content: ''
})

/**
 * 前端才過濾的條件。
 *
 * 編輯期間：GetSOPList_Edit 雖然收 startDate / endDate，但後端那段
 * 過濾邏輯整段被註解掉了，傳上去等於沒作用 —— 所以改成在前端對
 * 最後修改時間過濾，使用者看到的行為才跟欄位名稱一致。
 */
const localFilters = reactive({
  keyword: '',
  startDate: '',
  endDate: ''
})

const activeTab = ref<'ongoing' | 'finished' | 'all'>('ongoing')

const load = async () => {
  loading.value = true
  try {
    const res = await api.getIssueList(filters)
    // 查無資料時後端回 isSuccess: false + 說明訊息，不是錯誤，不要跳 toast。
    rows.value = res?.isSuccess ? (res.body ?? []).map(toIssueRow) : []
  } catch (err) {
    console.log('issues load failed -->', err)
    rows.value = []
  } finally {
    loading.value = false
  }
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

onMounted(() => {
  load()
  loadCategories()
})

const categoryOptions = computed(() => [
  { label: '全部類別', value: '' },
  ...categories.value.map(c => ({ label: c.phraseName, value: c.phraseName }))
])

const resetFilters = () => {
  filters.category = ''
  filters.customer = ''
  filters.caption = ''
  filters.content = ''
  localFilters.keyword = ''
  localFilters.startDate = ''
  localFilters.endDate = ''
  load()
}

const activeFilterCount = computed(() =>
  [filters.category, filters.customer, filters.caption, filters.content,
    localFilters.keyword, localFilters.startDate, localFilters.endDate]
    .filter(Boolean).length
)

/** 用「最後修改時間」比對，沒有的話退回建立時間。 */
const rowTime = (row: SalesIssueRow) => row.lastModiTime || row.modiTime || row.createTime || ''

const dateFiltered = computed(() => {
  const keyword = localFilters.keyword.trim().toLowerCase()

  return rows.value.filter((row) => {
    const date = toDateString(rowTime(row))
    if (localFilters.startDate && date && date < localFilters.startDate) return false
    if (localFilters.endDate && date && date > localFilters.endDate) return false

    if (!keyword) return true
    const haystack = [
      row.wpno, row.sopTitle, row.descript, row.userName,
      row.lastModifierName, ...row.categories, ...row.customers
    ].join(' ').toLowerCase()
    return haystack.includes(keyword)
  })
})

const ongoing = computed(() => dateFiltered.value.filter(r => !r.finFlag))
const finished = computed(() => dateFiltered.value.filter(r => r.finFlag))

const visibleRows = computed(() => {
  if (activeTab.value === 'ongoing') return ongoing.value
  if (activeTab.value === 'finished') return finished.value
  return dateFiltered.value
})

const tabItems = computed(() => [
  { label: '進行中', value: 'ongoing', icon: 'i-lucide-circle-dot', count: ongoing.value.length },
  { label: '結案', value: 'finished', icon: 'i-lucide-circle-check', count: finished.value.length },
  { label: '全部', value: 'all', icon: 'i-lucide-list', count: dateFiltered.value.length }
])

// 換頁籤時回到第一頁，否則在第 3 頁切到只有 1 頁的頁籤會看到空白表格。
watch(activeTab, () => {
  pagination.value.pageIndex = 0
})

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

    <UBreadcrumb :items="breadcrumbFor(appPath('sales-issue/issues'))" class="mb-4" />

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
            v-model="filters.category"
            :items="categoryOptions"
            value-key="value"
            label-key="label"
            placeholder="全部類別"
            class="w-full"
            @update:model-value="load"
          />
        </UFormField>

        <UFormField label="客戶別" size="sm">
          <UInput v-model="filters.customer" placeholder="客戶簡稱關鍵字" class="w-full" @keyup.enter="load" />
        </UFormField>

        <UFormField label="標題 / 大綱關鍵字" size="sm">
          <UInput v-model="filters.caption" placeholder="議題主題或內容說明" class="w-full" @keyup.enter="load" />
        </UFormField>

        <UFormField label="內文關鍵字" size="sm">
          <UInput v-model="filters.content" placeholder="進度內文" class="w-full" @keyup.enter="load" />
        </UFormField>

        <UFormField label="最後修改（起）" size="sm">
          <UInput v-model="localFilters.startDate" type="date" class="w-full" />
        </UFormField>

        <UFormField label="最後修改（迄）" size="sm">
          <UInput v-model="localFilters.endDate" type="date" class="w-full" />
        </UFormField>

        <UFormField label="快速搜尋" size="sm" class="xl:col-span-2">
          <UInput
            v-model="localFilters.keyword"
            icon="i-lucide-search"
            placeholder="在目前結果中搜尋編號 / 主題 / 進度 / 人員"
            class="w-full"
          />
        </UFormField>
      </div>

      <div class="mt-3 flex items-center justify-between gap-2">
        <p class="text-xs text-muted">
          類別、客戶別、關鍵字會重新向後端查詢；日期與快速搜尋只篩選目前結果。
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
          <UButton icon="i-lucide-search" size="sm" :loading="loading" @click="load">
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
        @click="activeTab = tab.value as typeof activeTab"
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
        v-model:pagination="pagination"
        v-model:sorting="sorting"
        :pagination-options="{ getPaginationRowModel: getPaginationRowModel() }"
        :data="visibleRows"
        :columns="columns"
        :loading="loading"
        :ui="{ tr: 'cursor-pointer', td: 'align-top whitespace-normal' }"
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

      <TablePaginationBar :table="table" />
    </div>
  </div>
</template>
