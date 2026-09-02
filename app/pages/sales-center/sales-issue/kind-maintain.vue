<script setup lang="ts">
/**
 * 議題關鍵字（類別）維護。
 *
 * 對應舊系統 WorkProcess/KindMaintain。資料表是 M_WorkProcessPhrase，
 * 用 phraseType 分群：01 搜尋片語 / 02 流程類別 / 03 職能主題。
 */
import { getPaginationRowModel } from '@tanstack/vue-table'
import type { TableColumn } from '@nuxt/ui'
import type { WorkPhrase } from '~/types/salesIssue'
import { PHRASE_TYPE } from '~/types/salesIssue'

useSeoMeta({ title: '類別維護 · 業務議題 · PRORIL 業務中心' })

const api = useSalesIssueApi()
const toast = useToast()
const { breadcrumbFor, appPath } = useAppNavigation()
const { pagination } = useTablePagination(20)
const table = useTemplateRef('table')

/**
 * 分類清單。
 *
 * 後端沒有回傳 M_WorkProcessType 的 API（舊畫面是 Razor 直接讀 DB），
 * 所以這裡寫死。要新增分類請先在 DB 建 type，再回來補這張表。
 */
const PHRASE_TYPES: { code: string, name: string }[] = [
  { code: PHRASE_TYPE.PHRASE, name: '搜尋片語' },
  { code: PHRASE_TYPE.CATEGORY, name: '流程類別' },
  { code: PHRASE_TYPE.JOB, name: '職能主題' }
]

const activeType = ref<string>(PHRASE_TYPE.CATEGORY)
const loading = ref(false)
const saving = ref(false)
const phrases = ref<WorkPhrase[]>([])
const keyword = ref('')

const load = async () => {
  loading.value = true
  try {
    const res = await api.getPhrases(activeType.value)
    // 查無資料時後端回 isSuccess: false，不是錯誤。
    phrases.value = res?.isSuccess ? (res.body ?? []) : []
  } catch (err) {
    console.log('kind-maintain load failed -->', err)
    phrases.value = []
  } finally {
    loading.value = false
  }
}

onMounted(load)
watch(activeType, () => {
  pagination.value.pageIndex = 0
  load()
})

const visibleRows = computed(() => {
  const q = keyword.value.trim().toLowerCase()
  if (!q) return phrases.value
  return phrases.value.filter(p =>
    `${p.phraseCode} ${p.phraseName} ${p.principal ?? ''}`.toLowerCase().includes(q)
  )
})

const columns: TableColumn<WorkPhrase>[] = [
  { accessorKey: 'phraseCode', header: '編號' },
  { accessorKey: 'phraseName', header: '名稱' },
  { accessorKey: 'principal', header: '負責人員' },
  { accessorKey: 'pubFlag', header: '開放使用' },
  { id: 'actions', header: '功能' }
]

// ------------------------------------------------------------------ 編輯

const editorOpen = ref(false)
const isNewPhrase = ref(true)

const form = reactive({
  phraseType: PHRASE_TYPE.CATEGORY as string,
  phraseCode: '',
  phraseName: '',
  principal: '',
  potentialCustom: '',
  pubFlag: true
})

/**
 * 下一個編號。
 *
 * 後端 SaveKindData 是用 (phraseType, phraseCode) 判斷新增或更新，
 * 撞號會直接覆蓋掉別人的資料，所以新增時先算出目前最大值 + 1。
 * 編號是字串欄位，但實際內容都是數字，補到兩碼跟既有資料一致。
 */
const nextCode = computed(() => {
  const max = phrases.value.reduce((acc, p) => {
    const n = Number.parseInt(p.phraseCode, 10)
    return Number.isNaN(n) ? acc : Math.max(acc, n)
  }, 0)
  return String(max + 1).padStart(2, '0')
})

const openCreate = () => {
  isNewPhrase.value = true
  form.phraseType = activeType.value
  form.phraseCode = nextCode.value
  form.phraseName = ''
  form.principal = ''
  form.potentialCustom = ''
  form.pubFlag = true
  editorOpen.value = true
}

const openEdit = (row: WorkPhrase) => {
  isNewPhrase.value = false
  form.phraseType = row.phraseType
  form.phraseCode = row.phraseCode
  form.phraseName = row.phraseName
  form.principal = row.principal ?? ''
  form.potentialCustom = row.potentialCustom ?? ''
  form.pubFlag = row.pubFlag ?? false
  editorOpen.value = true
}

const save = async () => {
  if (!form.phraseName.trim()) {
    toast.add({ title: '請填寫名稱', color: 'warning' })
    return
  }
  if (!form.phraseCode.trim()) {
    toast.add({ title: '請填寫編號', color: 'warning' })
    return
  }
  if (isNewPhrase.value && phrases.value.some(p => p.phraseCode === form.phraseCode.trim())) {
    toast.add({ title: '編號重複', description: '這個編號已經有人用了，換一個。', color: 'warning' })
    return
  }

  saving.value = true
  try {
    const res = await api.savePhrase({
      phraseType: form.phraseType,
      phraseCode: form.phraseCode.trim(),
      phraseName: form.phraseName.trim(),
      pubFlag: form.pubFlag,
      principal: form.principal,
      potentialCustom: form.potentialCustom
    })

    if (!res?.isSuccess) {
      toast.add({ title: '存檔失敗', description: res?.message ?? '', color: 'error' })
      return
    }

    toast.add({ title: '已儲存', color: 'success' })
    editorOpen.value = false
    await load()
  } catch (err) {
    console.log('kind-maintain save failed -->', err)
    toast.add({ title: '存檔失敗', color: 'error' })
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div>
    <FullPageLoading :show="loading" />

    <UBreadcrumb :items="breadcrumbFor(appPath('sales-issue/kind-maintain'))" class="mb-4" />

    <div class="mb-5 flex flex-wrap items-start justify-between gap-3">
      <div>
        <h1 class="text-2xl font-bold text-highlighted">
          類別維護
        </h1>
        <p class="mt-1 text-sm text-muted">
          維護議題可以掛的關鍵字。「流程類別」就是議題畫面上的「類別」下拉。
        </p>
      </div>

      <UButton icon="i-lucide-plus" @click="openCreate">
        新增類別資料
      </UButton>
    </div>

    <div class="mb-3 flex flex-wrap items-center gap-2">
      <UButton
        v-for="type in PHRASE_TYPES"
        :key="type.code"
        :color="activeType === type.code ? 'primary' : 'neutral'"
        :variant="activeType === type.code ? 'solid' : 'outline'"
        size="sm"
        @click="activeType = type.code"
      >
        {{ type.name }}
      </UButton>

      <UInput
        v-model="keyword"
        icon="i-lucide-search"
        placeholder="搜尋編號或名稱"
        size="sm"
        class="ml-auto w-full sm:w-64"
      />
    </div>

    <div class="overflow-hidden rounded-lg border border-default">
      <UTable
        ref="table"
        v-model:pagination="pagination"
        :pagination-options="{ getPaginationRowModel: getPaginationRowModel() }"
        :data="visibleRows"
        :columns="columns"
        :loading="loading"
        :ui="{ tr: 'cursor-pointer' }"
        @select="(_e: Event, row: any) => openEdit(row.original)"
      >
        <template #principal-cell="{ row }">
          <span class="text-sm">{{ row.original.principal || '—' }}</span>
        </template>

        <template #pubFlag-cell="{ row }">
          <UBadge :color="row.original.pubFlag ? 'success' : 'neutral'" variant="subtle" size="sm">
            {{ row.original.pubFlag ? '開放' : '未開放' }}
          </UBadge>
        </template>

        <template #actions-cell="{ row }">
          <div @click.stop>
            <UButton icon="i-lucide-pencil" color="primary" variant="ghost" size="xs" title="編輯" @click="openEdit(row.original)" />
          </div>
        </template>

        <template #empty>
          <div class="flex flex-col items-center gap-2 py-12 text-center">
            <UIcon name="i-lucide-tags" class="size-8 text-dimmed" />
            <p class="font-medium text-highlighted">
              這個分類還沒有資料
            </p>
          </div>
        </template>
      </UTable>

      <TablePaginationBar :table="table" />
    </div>

    <UModal
      v-model:open="editorOpen"
      :title="isNewPhrase ? '新增類別資料' : '編輯類別資料'"
      :dismissible="false"
    >
      <template #body>
        <div class="flex flex-col gap-4">
          <UFormField label="維護項目">
            <USelectMenu
              v-model="form.phraseType"
              :items="PHRASE_TYPES.map(t => ({ label: t.name, value: t.code }))"
              value-key="value"
              label-key="label"
              class="w-full"
              :disabled="!isNewPhrase"
            />
          </UFormField>

          <UFormField label="編號" required :hint="isNewPhrase ? '系統已帶入下一個可用編號' : '編號不可修改'">
            <UInput v-model="form.phraseCode" class="w-full" :disabled="!isNewPhrase" />
          </UFormField>

          <UFormField label="名稱" required>
            <UInput v-model="form.phraseName" placeholder="顯示在議題畫面上的名稱" class="w-full" />
          </UFormField>

          <UFormField label="負責人員">
            <UInput v-model="form.principal" placeholder="選填" class="w-full" />
          </UFormField>

          <UCheckbox v-model="form.pubFlag" label="開放流程維護使用" description="關閉後不會出現在議題的類別下拉" />
        </div>
      </template>

      <template #footer>
        <div class="flex w-full justify-end gap-2">
          <UButton color="neutral" variant="outline" :disabled="saving" @click="editorOpen = false">
            取消
          </UButton>
          <UButton icon="i-lucide-save" :loading="saving" @click="save">
            儲存
          </UButton>
        </div>
      </template>
    </UModal>
  </div>
</template>
