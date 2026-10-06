<script setup lang="ts">
/**
 * 格式匯入。對應 1.0 系統設定 / 格式匯入（Views/System/ImportXlsFormat.cshtml）。
 *
 * 上傳 Excel 範本，寫進 CMN_XlsFileFormat；銷貨檢索／未完成訂單／訂單資料檢核的匯出
 * 有版型就套版型（表頭、欄寬、樣式、數字格式、凍結窗格），沒有就用預設版面。
 *
 * 與 1.0 的差異：
 *   - 功能從「整份 M_Function 挑 FunctionNo」改成只列真的會讀版型的匯出，
 *     FunctionSubNo 的自由輸入改成「有金額權限／無金額權限」兩個選項。
 *   - 1.0 有「匯入」「匯入Cmn table」兩個按鈕分別寫 PUR／CMN 兩張表，2.0 只有一張。
 *   - 1.0 的「Y起始值／Y結束值」從來沒送到後端，拿掉。
 *   - 多了目前版型清單、下載目前版型、刪除（退回預設版面）。
 */
import type { TableColumn } from '@nuxt/ui'
import ConfirmDialog from '~/components/common/ConfirmDialog.vue'
import type { XlsFormatListItem, XlsFormatSheetSummary, XlsFormatSubNo, XlsFormatTarget } from '~/types/xlsFormat'

useSeoMeta({ title: '格式匯入 · 系統管理 · PRORIL 業務中心' })

const PAGE_KEY = PERMISSION_KEYS.system.importXlsFormat
const MAX_MB = 5

const api = useXlsFormatApi()
const toast = useToast()
const overlay = useOverlay()
const { canAccess, loadUserFunctions } = useAppNavigation()

const loading = ref(false)
const importing = ref(false)
/** 正在下載／刪除的那一列（`${key}|${subNo}`），按鈕顯示 loading。 */
const busyRow = ref('')

const targets = ref<XlsFormatTarget[]>([])
const subNos = ref<XlsFormatSubNo[]>([])
const formats = ref<XlsFormatListItem[]>([])

// ------------------------------------------------------------------ 匯入

const form = reactive({
  permissionKey: '',
  functionSubNo: '0'
})
const file = ref<File | null>(null)
const fileInput = useTemplateRef<HTMLInputElement>('fileInput')

/** 最近一次匯入的結果（分頁清單 + 後端提示），換功能或換檔就清掉。 */
const lastResult = ref<{ sheets: XlsFormatSheetSummary[], message: string } | null>(null)

const targetOptions = computed(() => targets.value.map(t => ({ label: t.label, value: t.permissionKey })))
const subNoOptions = computed(() => subNos.value.map(s => ({ label: s.label, value: s.value })))
const selectedTarget = computed(() => targets.value.find(t => t.permissionKey === form.permissionKey))

const labelOf = (key: string, subNo: string) => {
  const target = targets.value.find(t => t.permissionKey === key)?.label ?? key
  const sub = subNos.value.find(s => s.value === subNo)?.label ?? subNo
  return `${target}（${sub}）`
}

const existing = computed(() =>
  formats.value.find(f => f.permissionKey === form.permissionKey && f.functionSubNo === form.functionSubNo)
)

watch(() => [form.permissionKey, form.functionSubNo], () => {
  lastResult.value = null
})

const pickFile = () => fileInput.value?.click()

const onPickFile = (e: Event) => {
  const input = e.target as HTMLInputElement
  const picked = input.files?.[0] ?? null
  input.value = ''
  lastResult.value = null
  if (!picked) return

  if (!picked.name.toLowerCase().endsWith('.xlsx')) {
    toast.add({ title: '只接受 .xlsx 檔', description: '舊版 .xls 請先用 Excel 另存新檔。', color: 'warning' })
    return
  }
  if (picked.size > MAX_MB * 1024 * 1024) {
    toast.add({ title: `檔案超過 ${MAX_MB} MB`, description: '範本只需要保留表頭列。', color: 'warning' })
    return
  }
  file.value = picked
}

const confirmModal = overlay.create(ConfirmDialog)

const doImport = async () => {
  if (!form.permissionKey) {
    toast.add({ title: '請先選擇功能', color: 'warning' })
    return
  }
  if (!file.value) {
    toast.add({ title: '請先選擇範本檔', color: 'warning' })
    return
  }

  const name = labelOf(form.permissionKey, form.functionSubNo)
  const confirmed = await confirmModal.open({
    title: '匯入版型',
    description: existing.value
      ? `${name} 已經有版型，匯入後會整份換成「${file.value.name}」，確定？`
      : `將「${file.value.name}」匯入為 ${name} 的版型，確定？`,
    confirmLabel: '匯入'
  }).result
  if (!confirmed) return

  importing.value = true
  try {
    const res = await api.importFormat(file.value, form.permissionKey, form.functionSubNo)
    if (!res?.isSuccess) {
      toast.add({ title: '匯入失敗', description: res?.message ?? undefined, color: 'error' })
      return
    }
    lastResult.value = { sheets: res.body ?? [], message: res.message ?? '' }
    toast.add({ title: `${name} 版型已匯入`, color: 'success' })
    file.value = null
    await loadFormats()
  } catch (err) {
    console.log('import xls format failed -->', err)
  } finally {
    importing.value = false
  }
}

// ------------------------------------------------------------------ 目前的版型

const columns: TableColumn<XlsFormatListItem>[] = [
  { accessorKey: 'label', header: '功能' },
  { accessorKey: 'subNoLabel', header: '版型別' },
  { id: 'sheets', header: '分頁' },
  { id: 'updated', header: '最後匯入' },
  { id: 'actions', header: '' }
]

const rowKey = (row: XlsFormatListItem) => `${row.permissionKey}|${row.functionSubNo}`

const loadFormats = async () => {
  try {
    const res = await api.getList()
    formats.value = res?.isSuccess ? (res.body ?? []) : []
  } catch (err) {
    console.log('load xls format list failed -->', err)
    formats.value = []
  }
}

const loadTargets = async () => {
  try {
    const res = await api.getTargets()
    targets.value = res?.isSuccess ? (res.body ?? []) : []
    subNos.value = res?.isSuccess ? (res.body2 ?? []) : []
    if (!form.permissionKey && targets.value.length) form.permissionKey = targets.value[0]!.permissionKey
  } catch (err) {
    console.log('load xls format targets failed -->', err)
  }
}

onMounted(async () => {
  loading.value = true
  try {
    await loadUserFunctions()
    await Promise.all([loadTargets(), loadFormats()])
  } finally {
    loading.value = false
  }
})

const download = async (row: XlsFormatListItem) => {
  busyRow.value = rowKey(row)
  try {
    const res = await api.exportFormat(row.permissionKey, row.functionSubNo)
    if (!res?.isSuccess || !res.body) {
      toast.add({ title: '下載失敗', description: res?.message ?? '', color: 'error' })
      return
    }
    openExportDownload(res.body, 'format.xlsx')
  } catch (err) {
    console.log('export xls format failed -->', err)
  } finally {
    busyRow.value = ''
  }
}

const remove = async (row: XlsFormatListItem) => {
  const name = `${row.label}（${row.subNoLabel}）`
  const confirmed = await confirmModal.open({
    title: '刪除版型',
    description: `確定要刪除 ${name} 的版型？刪除後這支匯出會退回預設版面。`,
    confirmLabel: '刪除',
    confirmColor: 'error'
  }).result
  if (!confirmed) return

  busyRow.value = rowKey(row)
  try {
    const res = await api.deleteFormat(row.permissionKey, row.functionSubNo)
    if (!res?.isSuccess) {
      toast.add({ title: '刪除失敗', description: res?.message ?? undefined, color: 'error' })
      return
    }
    toast.add({ title: `${name} 版型已刪除`, color: 'success' })
    await loadFormats()
  } catch (err) {
    console.log('delete xls format failed -->', err)
  } finally {
    busyRow.value = ''
  }
}

/** 這一列的分頁有沒有對上目標功能的分頁清單（清單外的版型不會被匯出讀到）。 */
const isExpectedSheet = (row: XlsFormatListItem, wsName: string) =>
  targets.value.find(t => t.permissionKey === row.permissionKey)?.sheetNames.includes(wsName) ?? false
</script>

<template>
  <div>
    <FullPageLoading :show="loading" />

    <UAlert
      v-if="!canAccess(PAGE_KEY)"
      icon="i-lucide-shield-alert"
      color="warning"
      variant="subtle"
      title="沒有格式匯入權限"
      description="請洽系統管理員把「格式匯入」加進你的角色。"
      class="mb-4"
    />

    <div class="grid gap-4 lg:grid-cols-5">
      <!-- 匯入 -->
      <UCard class="lg:col-span-3">
        <template #header>
          <h2 class="font-semibold text-highlighted">
            匯入輸出 Xls 範本
          </h2>
        </template>

        <div class="space-y-4">
          <div class="grid gap-4 sm:grid-cols-2">
            <UFormField label="功能" required>
              <USelect
                v-model="form.permissionKey"
                :items="targetOptions"
                value-key="value"
                placeholder="選擇功能"
                class="w-full"
              />
            </UFormField>
            <UFormField label="版型別" required hint="無金額權限的匯出少了金額欄">
              <USelect
                v-model="form.functionSubNo"
                :items="subNoOptions"
                value-key="value"
                class="w-full"
              />
            </UFormField>
          </div>

          <div v-if="selectedTarget" class="rounded-md bg-elevated/50 p-3 text-sm">
            <p class="mb-2 text-muted">
              範本的分頁要命名為：
            </p>
            <div class="flex flex-wrap gap-1.5">
              <UBadge
                v-for="name in selectedTarget.sheetNames"
                :key="name"
                color="neutral"
                variant="outline"
              >
                {{ name }}
              </UBadge>
            </div>
            <p v-if="selectedTarget.note" class="mt-2 text-muted">
              {{ selectedTarget.note }}
            </p>
            <p class="mt-2 text-muted">
              目前狀態：
              <span v-if="existing" class="text-highlighted">
                已有版型（{{ existing.sheets.map(s => s.wsName).join('、') }}，{{ toDateTimeString(existing.createTime) }} {{ existing.creator }}）
              </span>
              <span v-else>尚未匯入，使用預設版面</span>
            </p>
          </div>

          <UFormField label="範本檔" required :hint="`.xlsx，${MAX_MB} MB 以內`">
            <div class="flex flex-wrap items-center gap-2">
              <UButton icon="i-lucide-file-up" color="neutral" variant="outline" @click="pickFile">
                選擇檔案
              </UButton>
              <span class="min-w-0 truncate text-sm" :class="file ? 'text-highlighted' : 'text-muted'">
                {{ file?.name ?? '尚未選擇' }}
              </span>
            </div>
            <input
              ref="fileInput"
              type="file"
              accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
              class="hidden"
              @change="onPickFile"
            >
          </UFormField>

          <UButton
            icon="i-lucide-upload"
            :loading="importing"
            :disabled="!form.permissionKey || !file"
            @click="doImport"
          >
            匯入
          </UButton>

          <div v-if="lastResult" class="space-y-2">
            <div class="flex flex-wrap gap-1.5">
              <UBadge
                v-for="s in lastResult.sheets"
                :key="s.wsName"
                :color="s.recognized ? 'success' : 'neutral'"
                variant="subtle"
                :icon="s.recognized ? 'i-lucide-check' : 'i-lucide-minus'"
              >
                {{ s.wsName }}{{ s.recognized ? ` · ${s.rows} 列 × ${s.columns} 欄` : ' · 已略過' }}
              </UBadge>
            </div>
            <UAlert
              v-if="lastResult.message"
              icon="i-lucide-info"
              color="warning"
              variant="subtle"
              :description="lastResult.message"
            />
          </div>
        </div>
      </UCard>

      <!-- 範本規則 -->
      <UCard class="lg:col-span-2">
        <template #header>
          <h2 class="font-semibold text-highlighted">
            範本怎麼做
          </h2>
        </template>
        <ul class="list-disc space-y-2 pl-5 text-sm text-muted">
          <li>
            最簡單的做法：先到該功能<strong class="text-highlighted">匯出一次</strong> Excel，刪掉資料列、只留表頭，
            改好表頭文字、欄寬、顏色、數字格式後存檔匯入。
          </li>
          <li>
            <strong class="text-highlighted">欄位順序不能動</strong>：版型只管外觀，每一欄放什麼資料是程式固定的。
            表頭可以有好幾列，資料會從最後一列表頭的下一列開始。
          </li>
          <li>數字格式、欄寬、隱藏欄設在「整欄」上，才會套到資料列；只設在表頭格上的只影響表頭。</li>
          <li>凍結窗格會照範本；合併儲存格不支援。</li>
          <li>「有金額權限」與「無金額權限」是兩份版型，無金額權限的匯出少了金額相關欄位，欄位位置不同。</li>
          <li>改版型可以先在下方「下載」目前版型，改完再匯入；刪除版型後匯出會退回預設版面。</li>
        </ul>
      </UCard>
    </div>

    <!-- 目前的版型 -->
    <section class="mt-6">
      <h2 class="mb-2 font-semibold text-highlighted">
        目前的版型
      </h2>
      <div class="overflow-x-auto rounded-lg border border-default">
        <UTable :data="formats" :columns="columns">
          <template #label-cell="{ row }">
            <span class="font-medium text-highlighted">{{ row.original.label }}</span>
            <UBadge v-if="!row.original.isKnownTarget" color="warning" variant="subtle" size="sm" class="ml-2">
              已不支援
            </UBadge>
          </template>
          <template #sheets-cell="{ row }">
            <div class="flex flex-wrap gap-1">
              <UBadge
                v-for="s in row.original.sheets"
                :key="s.wsName"
                :color="isExpectedSheet(row.original, s.wsName) ? 'neutral' : 'warning'"
                variant="outline"
                size="sm"
              >
                {{ s.wsName }}
              </UBadge>
            </div>
          </template>
          <template #updated-cell="{ row }">
            <div class="text-sm">
              {{ toDateTimeString(row.original.createTime) }}
            </div>
            <div class="text-xs text-muted">
              {{ row.original.creator }}
            </div>
          </template>
          <template #actions-cell="{ row }">
            <div class="flex justify-end gap-1" @click.stop>
              <UButton
                icon="i-lucide-download"
                color="neutral"
                variant="ghost"
                size="sm"
                :loading="busyRow === rowKey(row.original)"
                @click="download(row.original)"
              >
                下載
              </UButton>
              <UButton
                icon="i-lucide-trash-2"
                color="error"
                variant="ghost"
                size="sm"
                :disabled="busyRow === rowKey(row.original)"
                @click="remove(row.original)"
              >
                刪除
              </UButton>
            </div>
          </template>
          <template #empty>
            <p class="py-6 text-center text-sm text-muted">
              尚未匯入任何版型，所有匯出都使用預設版面
            </p>
          </template>
        </UTable>
      </div>
    </section>
  </div>
</template>
