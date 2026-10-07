<script setup lang="ts">
/**
 * 稽核紀錄（系統管理 / 系統設定 / 稽核紀錄，PAGE system.auditLog）。2.0 新功能，1.0 沒有。
 *
 * 查 SYS_AuditLog：登入成功／失敗、人員管理、權限管理的異動（寫入點見 api/Services/AuditLogService.cs）。
 * 唯讀；後端分頁、新到舊；時間是台灣時間（後端轉好）。點一列看完整內容。
 */
import { h, resolveComponent } from 'vue'
import type { TableColumn } from '@nuxt/ui'
import type { AuditLogRow, AuditLogTarget } from '~/types/auditLog'
import type { UserListItem } from '~/types/system'

useSeoMeta({ title: '稽核紀錄 · 系統管理 · PRORIL 業務中心' })

/** 查詢條件區塊展開／收合（見 useFiltersOpen） */
const filtersOpen = useFiltersOpen('audit-log')

const PAGE_KEY = PERMISSION_KEYS.system.auditLog

const api = useAuditLogApi()
const systemApi = useSystemSettingApi()
const toast = useToast()
const { canAccess, loadUserFunctions } = useAppNavigation()
const { pagination } = useTablePagination(50)
const table = useTemplateRef('table')

const loading = ref(false)
// 不整頁遮罩，改用整頁 wait cursor 提示載入中（比照查詢畫面）。
useWaitCursor(loading)

/** 預設查最近 7 天（含今天）。 */
const DEFAULT_DAYS = 6
const dateDaysAgo = (days: number) => toDateString(new Date(Date.now() - days * 24 * 60 * 60 * 1000))

const filters = reactive({
  startDate: dateDaysAgo(DEFAULT_DAYS),
  endDate: toDateString(new Date()),
  account: '',
  action: '',
  target: '',
  keyword: ''
})

/** USelect／USelectMenu 不允許空字串 value，用哨兵值代表「全部」。 */
const ALL = '__all__'
const allValue = (key: 'account' | 'action' | 'target') => computed({
  get: () => filters[key] || ALL,
  set: (v: string) => { filters[key] = v === ALL ? '' : v }
})
const accountValue = allValue('account')
const actionValue = allValue('action')
const targetValue = allValue('target')

const users = ref<UserListItem[]>([])
const targets = ref<AuditLogTarget[]>([])

const accountOptions = computed(() => [
  { label: '全部帳號', value: ALL },
  ...users.value.map(u => ({ label: `${u.account.trim()} ${u.userName ?? ''}`, value: u.account.trim() }))
])
const actionOptions = [
  { label: '全部動作', value: ALL },
  ...Object.entries(AUDIT_ACTIONS).map(([value, a]) => ({ label: a.label, value }))
]
const targetOptions = computed(() => [
  { label: '全部功能', value: ALL },
  ...targets.value.map(t => ({ label: t.label, value: t.value }))
])

/** 權限 key → 名稱，內容裡的權限增減顯示名稱用（含停用節點）。 */
const permissionLabels = ref(new Map<string, string>())
const permissionLabel = (key: string) => permissionLabels.value.get(key) ?? key

const loadOptions = async () => {
  try {
    const [userRes, targetRes, permRes] = await Promise.all([
      systemApi.getAllUserList(),
      api.getTargets(),
      systemApi.getPermissions(true)
    ])
    users.value = userRes?.isSuccess ? (userRes.body ?? []) : []
    targets.value = targetRes?.isSuccess ? (targetRes.body ?? []) : []
    permissionLabels.value = new Map((permRes?.body ?? []).map(p => [p.permissionKey, p.label]))
  } catch (err) {
    console.log('audit-log loadOptions failed -->', err)
  }
}

// ---------------------------------------------------------------- 查詢

const rows = ref<AuditLogRow[]>([])
const totalCount = ref(0)

/** 每次 load 遞增；回來時不是最新一次就丟掉，避免慢的舊回應蓋掉新結果。 */
let loadSeq = 0

const load = async () => {
  const seq = ++loadSeq
  loading.value = true
  try {
    const res = await api.getAuditLogs({
      startDate: toCompactDate(filters.startDate),
      endDate: toCompactDate(filters.endDate),
      account: filters.account,
      action: filters.action,
      target: filters.target,
      keyword: filters.keyword.trim(),
      pageIndex: pagination.value.pageIndex,
      pageSize: pagination.value.pageSize >= ALL_PAGE_SIZE ? 0 : pagination.value.pageSize
    })
    if (seq !== loadSeq) return
    rows.value = res?.isSuccess ? (res.body ?? []) : []
    totalCount.value = res?.body2?.totalCount ?? 0
    if (res && !res.isSuccess && res.message) {
      toast.add({ title: '查詢失敗', description: res.message, color: 'error' })
    }
  } catch (err) {
    console.log('audit-log load failed -->', err)
    if (seq !== loadSeq) return
    rows.value = []
    totalCount.value = 0
    toast.add({ title: '查詢失敗', color: 'error' })
  } finally {
    if (seq === loadSeq) loading.value = false
  }
}

const search = () => {
  pagination.value.pageIndex = 0
  load()
}

const onClickReset = () => {
  filters.startDate = dateDaysAgo(DEFAULT_DAYS)
  filters.endDate = toDateString(new Date())
  filters.account = ''
  filters.action = ''
  filters.target = ''
  filters.keyword = ''
  search()
}

/** 分頁列（翻頁、切每頁筆數）的唯一入口，比照訂單資料檢核。 */
const onPaginationUpdate = (value?: { pageIndex: number, pageSize: number }) => {
  if (!value) return
  const sizeChanged = value.pageSize !== pagination.value.pageSize
  pagination.value = sizeChanged ? { pageIndex: 0, pageSize: value.pageSize } : value
  load()
}

onMounted(async () => {
  await loadUserFunctions()
  if (!canAccess(PAGE_KEY)) return
  loadOptions()
  load()
})

// ---------------------------------------------------------------- 表格

const detailText = (row: AuditLogRow) => auditDetailLines(row.action, row.detail, permissionLabel).join('；')

const columns: TableColumn<AuditLogRow>[] = [
  { accessorKey: 'logTime', header: '時間' },
  {
    id: 'account',
    header: '帳號',
    cell: ({ row }) => h('span', {}, [
      row.original.account ?? '',
      row.original.userName ? h('span', { class: 'ms-1 text-muted' }, row.original.userName) : null
    ])
  },
  {
    id: 'action',
    header: '動作',
    cell: ({ row }) => h(resolveComponent('UBadge'), {
      color: AUDIT_ACTIONS[row.original.action]?.color ?? 'neutral',
      variant: 'subtle'
    }, () => auditActionLabel(row.original.action))
  },
  { accessorKey: 'targetLabel', header: '功能' },
  { accessorKey: 'targetId', header: '對象' },
  {
    id: 'detail',
    header: '內容',
    meta: { class: { td: 'max-w-md' } },
    cell: ({ row }) => h('span', { class: 'block truncate', title: detailText(row.original) }, detailText(row.original))
  },
  { accessorKey: 'clientIp', header: 'IP' }
]

// ---------------------------------------------------------------- 明細

const detailOpen = ref(false)
const current = ref<AuditLogRow | null>(null)

const openDetail = (row: AuditLogRow) => {
  current.value = row
  detailOpen.value = true
}

const currentLines = computed(() =>
  current.value ? auditDetailLines(current.value.action, current.value.detail, permissionLabel) : [])

const currentJson = computed(() => {
  if (!current.value?.detail) return ''
  try {
    return JSON.stringify(JSON.parse(current.value.detail), null, 2)
  } catch {
    return current.value.detail
  }
})
</script>

<template>
  <div class="flex min-h-0 flex-1 flex-col">
    <!--
      整頁撐滿右側面板，表格吃掉剩下的高度、自己捲動（表頭 sticky），比照查詢畫面。
    -->
    <UAlert
      v-if="!canAccess(PAGE_KEY)"
      icon="i-lucide-shield-alert"
      color="warning"
      variant="subtle"
      title="沒有稽核紀錄權限"
      description="請洽系統管理員把「稽核紀錄」加進你的角色。"
      class="mb-4"
    />

    <template v-else>
      <!-- 查詢條件 -->
      <div class="mb-4 rounded-lg border border-default bg-elevated/40 p-4">
        <!-- 操作列放在查詢區塊最上方，比照其他查詢畫面 -->
        <div class="flex items-center justify-between gap-2" :class="{ 'mb-3': filtersOpen }">
          <div class="flex items-center gap-2">
            <FilterToggleButton v-model="filtersOpen" />
            <p class="text-xs text-muted">
              保留一年；時間為台灣時間。
            </p>
          </div>
          <div class="flex items-center gap-2">
            <UButton icon="i-lucide-rotate-cw" color="neutral" variant="outline" size="sm" @click="onClickReset">
              重設
            </UButton>
            <UButton icon="i-lucide-search" size="sm" :loading="loading" @click="search">
              查詢
            </UButton>
          </div>
        </div>

        <div v-show="filtersOpen" class="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-5">
          <UFormField label="日期（起~迄）" size="sm" class="md:col-span-2">
            <div class="flex items-center gap-2">
              <UInput v-model="filters.startDate" type="date" class="w-full" />
              <span class="text-sm text-muted">至</span>
              <UInput v-model="filters.endDate" type="date" class="w-full" />
            </div>
          </UFormField>

          <UFormField label="帳號" size="sm" hint="修改者或對象">
            <USelectMenu
              v-model="accountValue"
              :items="accountOptions"
              value-key="value"
              label-key="label"
              class="w-full"
            />
          </UFormField>

          <UFormField label="動作" size="sm">
            <USelect v-model="actionValue" :items="actionOptions" value-key="value" class="w-full" />
          </UFormField>

          <UFormField label="功能" size="sm">
            <USelect v-model="targetValue" :items="targetOptions" value-key="value" class="w-full" />
          </UFormField>

          <UFormField label="關鍵字" size="sm" class="md:col-span-2" hint="比對對象與內容">
            <ClearInput
              v-model="filters.keyword"
              icon="i-lucide-search"
              placeholder="例如帳號、角色名稱、權限 key"
              class="w-full"
              @keyup.enter="search"
            />
          </UFormField>
        </div>
      </div>

      <!-- 外層不能用 overflow-x-auto（會讓 sticky 失效），由 UTable 根節點捲動 -->
      <div class="flex min-h-64 flex-1 flex-col overflow-hidden rounded-lg border border-default">
        <UTable
          ref="table"
          sticky
          class="min-h-0 flex-1"
          :pagination="pagination"
          :pagination-options="{ manualPagination: true, rowCount: totalCount }"
          :data="rows"
          :columns="columns"
          :loading="loading"
          :ui="{ tr: clickableRowTr, td: 'whitespace-nowrap' }"
          @update:pagination="onPaginationUpdate"
          @select="(_e: Event, row: any) => openDetail(row.original)"
        >
          <template #empty>
            <p class="py-12 text-center text-sm text-muted">
              沒有符合條件的稽核紀錄
            </p>
          </template>
        </UTable>

        <TablePaginationBar :table="table" :total="totalCount" />
      </div>
    </template>

    <UModal v-model:open="detailOpen" title="稽核紀錄" :ui="{ content: 'max-w-2xl' }">
      <template #body>
        <div v-if="current" class="flex flex-col gap-4 text-sm">
          <dl class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5">
            <dt class="text-muted">
              時間
            </dt>
            <dd>{{ current.logTime }}</dd>
            <dt class="text-muted">
              帳號
            </dt>
            <dd>{{ current.account }} <span class="text-muted">{{ current.userName }}</span></dd>
            <dt class="text-muted">
              動作
            </dt>
            <dd>
              <UBadge :color="AUDIT_ACTIONS[current.action]?.color ?? 'neutral'" variant="subtle">
                {{ auditActionLabel(current.action) }}
              </UBadge>
            </dd>
            <dt class="text-muted">
              功能
            </dt>
            <dd>{{ current.targetLabel }}</dd>
            <dt class="text-muted">
              對象
            </dt>
            <dd>{{ current.targetId }}</dd>
            <dt class="text-muted">
              IP
            </dt>
            <dd>{{ current.clientIp }}</dd>
          </dl>

          <div v-if="currentLines.length">
            <p class="mb-1 font-medium text-highlighted">
              內容
            </p>
            <ul class="list-inside list-disc space-y-0.5">
              <li v-for="(line, i) in currentLines" :key="i" class="break-all">
                {{ line }}
              </li>
            </ul>
          </div>

          <details v-if="currentJson">
            <summary class="cursor-pointer text-xs text-muted">
              原始資料（JSON）
            </summary>
            <pre class="mt-2 max-h-80 overflow-auto rounded-md bg-elevated p-3 text-xs">{{ currentJson }}</pre>
          </details>
        </div>
      </template>
    </UModal>
  </div>
</template>
