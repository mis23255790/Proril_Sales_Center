<script setup lang="ts">
/**
 * 新增／編輯一則議題進度（D_WorkProcessDetail）。
 *
 * 一則進度 = 標題（慣例放日期）+ 內文 HTML + 一組附件。
 * 附件走的是舊系統那套「解壓到 temp → 改 → 壓回去」的流程，
 * 細節見 useIssueAttachments()。
 */
import type { IssueAttachment, SalesIssueDetail } from '~/types/salesIssue'

const props = defineProps<{
  wpno: string
  issueTitle?: string | null
  /** null = 新增一則 */
  detail: SalesIssueDetail | null
  /** 新增時要用的 sno */
  nextSno: number
}>()

const open = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ saved: [] }>()

const api = useSalesIssueApi()
const attachments = useIssueAttachments()
const toast = useToast()

const saving = ref(false)
const loadingContent = ref(false)
const caption = ref('')
const content = ref('')
const files = ref<IssueAttachment[]>([])
/** 這次新選、還沒上傳到 temp 的檔案。 */
const pendingFiles = ref<File[]>([])
/** 這次被移除、原本在 zip 裡的檔名。 */
const removedFiles = ref<string[]>([])
const fileInput = ref<HTMLInputElement | null>(null)

const isNew = computed(() => !props.detail)
const sno = computed(() => (props.detail ? Number.parseInt(props.detail.sno, 10) : props.nextSno))

const attachmentsDirty = computed(() => pendingFiles.value.length > 0 || removedFiles.value.length > 0)

const reset = () => {
  caption.value = toDateString(new Date())
  content.value = ''
  files.value = []
  pendingFiles.value = []
  removedFiles.value = []
}

/**
 * 開窗時才載入內文。
 *
 * GetSOPDetail（列表）為了效能刻意不帶 processContent，
 * 所以編輯時一定要另外呼叫 GetEditorText，否則會把內文存成空的。
 */
const loadForEdit = async () => {
  const detail = props.detail
  if (!detail) {
    reset()
    return
  }

  caption.value = detail.processCaption ?? ''
  files.value = attachments.parseAttachments(detail.uploadFile, detail.renameFile)
  pendingFiles.value = []
  removedFiles.value = []
  content.value = ''

  loadingContent.value = true
  try {
    // GetEditorText 回的是整個 detail 物件，內文在 processContent，不是 body 本身。
    const res = await api.getDetailContent(props.wpno, detail.sno)
    content.value = (res?.isSuccess ? res.body?.processContent : null) ?? detail.processContent ?? ''
  } catch (err) {
    console.log('IssueProgressModal loadForEdit failed -->', err)
    content.value = detail.processContent ?? ''
  } finally {
    loadingContent.value = false
  }

  // 先把既有附件解壓到 temp，等一下要重新壓縮時才有東西可壓。
  await attachments.prepareTemp(props.wpno, detail.sno)
}

watch(open, (value) => {
  if (value) loadForEdit()
})

const onPickFiles = (event: Event) => {
  try {
    const input = event.target as HTMLInputElement
    const picked = Array.from(input.files ?? [])
    const invalid = picked.find(f => /[#\\/:*?"<>|]/.test(f.name))
    if (invalid) {
      toast.add({ title: '檔名不合法', description: '不可包含 # \\ / : * ? " < > |', color: 'warning' })
      input.value = ''
      return
    }

    for (const file of picked) {
      if (files.value.some(f => f.uploadFile === file.name)) {
        toast.add({ title: `檔案已存在：${file.name}`, color: 'warning' })
        continue
      }
      files.value.push({ uploadFile: file.name, pending: true })
      pendingFiles.value.push(file)
    }
    input.value = ''
  } catch (err) {
    console.log('IssueProgressModal onPickFiles failed -->', err)
  }
}

const removeFile = (name: string) => {
  files.value = files.value.filter(f => f.uploadFile !== name)
  const pendingIndex = pendingFiles.value.findIndex(f => f.name === name)
  if (pendingIndex >= 0) {
    pendingFiles.value.splice(pendingIndex, 1)
  } else {
    removedFiles.value.push(name)
  }
}

const downloadFile = async (name: string) => {
  try {
    await attachments.download(props.wpno, sno.value, name)
  } catch (err) {
    console.log('IssueProgressModal downloadFile failed -->', err)
    toast.add({ title: '下載失敗', description: String(err), color: 'error' })
  }
}

const save = async () => {
  if (!caption.value.trim()) {
    toast.add({ title: '請填寫標題', description: '標題通常放這則進度的日期', color: 'warning' })
    return
  }

  saving.value = true
  try {
    const currentSno = sno.value

    // 1. 先把標題與內文寫進 D_WorkProcessDetail（新增時這一步才會建出資料列）。
    const saveRes = await api.saveDetail({
      wpno: props.wpno,
      sno: currentSno,
      processCaption: caption.value.trim(),
      processContent: content.value,
      uploadFile: files.value.filter(f => !f.pending).map(f => f.uploadFile).join(';'),
      renameFile: files.value.filter(f => !f.pending).map(f => f.renameFile ?? '').join(';')
    })

    if (!saveRes?.isSuccess) {
      toast.add({ title: '存檔失敗', description: saveRes?.message ?? '', color: 'error' })
      return
    }

    // 2. 附件有異動才動 zip —— 沒事不要重壓，重壓會重編 renameFile。
    if (attachmentsDirty.value) {
      if (isNew.value) {
        // 新的一則進度在步驟 1 之前沒有 temp 目錄，補建一次（順便清掉上一次的殘留）。
        await attachments.prepareTemp(props.wpno, currentSno)
      }

      for (const file of pendingFiles.value) {
        const uploadRes = await attachments.uploadTemp(props.wpno, currentSno, file)
        if (!uploadRes?.isSuccess) {
          toast.add({ title: `上傳失敗：${file.name}`, description: uploadRes?.message ?? '', color: 'error' })
          return
        }
      }

      for (const name of removedFiles.value) {
        await attachments.deleteTemp(props.wpno, currentSno, name)
      }

      // 重壓需要這則進度的 id，向後端要一次最新的。
      const detailRes = await api.getDetail(props.wpno, currentSno)
      const detailId = detailRes?.body?.id ?? 0
      await attachments.commit(props.wpno, currentSno, detailId, files.value.map(f => f.uploadFile))
    }

    toast.add({ title: '進度已儲存', color: 'success' })
    open.value = false
    emit('saved')
  } catch (err) {
    console.log('IssueProgressModal save failed -->', err)
    toast.add({ title: '存檔失敗', color: 'error' })
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <UModal
    v-model:open="open"
    :title="isNew ? '新增進度' : `編輯進度 #${sno}`"
    :description="issueTitle || undefined"
    :dismissible="false"
    :ui="{ content: 'max-w-5xl' }"
  >
    <template #body>
      <div class="flex flex-col gap-4">
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <UFormField label="標題" hint="慣例放這則進度的日期" class="sm:col-span-2">
            <UInput v-model="caption" placeholder="例如 2026-09-02 客戶回覆" class="w-full" />
          </UFormField>
          <UFormField label="快速帶入日期">
            <UInput type="date" class="w-full" @update:model-value="(v: unknown) => { if (v) caption = String(v) }" />
          </UFormField>
        </div>

        <UFormField label="內容">
          <div v-if="loadingContent" class="h-40 animate-pulse rounded-lg bg-elevated" />
          <RichTextEditor v-else v-model="content" min-height="320px" placeholder="輸入這次的進度內容..." />
        </UFormField>

        <UFormField label="附件表單">
          <div class="rounded-lg border border-default p-3">
            <div v-if="files.length" class="mb-3 flex flex-col gap-2">
              <div
                v-for="file in files"
                :key="file.uploadFile"
                class="flex items-center gap-2 rounded-md bg-elevated/60 px-3 py-2"
              >
                <UIcon name="i-lucide-paperclip" class="size-4 shrink-0 text-muted" />
                <span class="min-w-0 flex-1 truncate text-sm">{{ file.uploadFile }}</span>
                <UBadge v-if="file.pending" color="warning" variant="subtle" size="sm">
                  待儲存
                </UBadge>
                <UButton
                  v-if="!file.pending"
                  icon="i-lucide-download"
                  color="neutral"
                  variant="ghost"
                  size="xs"
                  title="下載"
                  @click="downloadFile(file.uploadFile)"
                />
                <UButton
                  icon="i-lucide-x"
                  color="error"
                  variant="ghost"
                  size="xs"
                  title="移除"
                  @click="removeFile(file.uploadFile)"
                />
              </div>
            </div>
            <p v-else class="mb-3 text-sm text-muted">
              尚未加入附件。
            </p>

            <UButton icon="i-lucide-plus" color="neutral" variant="outline" size="sm" @click="fileInput?.click()">
              選擇檔案
            </UButton>
            <input ref="fileInput" type="file" multiple class="hidden" @change="onPickFiles">
          </div>
        </UFormField>
      </div>
    </template>

    <template #footer>
      <div class="flex w-full items-center justify-between gap-2">
        <p class="text-xs text-muted">
          {{ attachmentsDirty ? '附件有異動，儲存時會重新壓縮。' : '' }}
        </p>
        <div class="flex gap-2">
          <UButton color="neutral" variant="outline" :disabled="saving" @click="open = false">
            取消
          </UButton>
          <UButton icon="i-lucide-save" :loading="saving" @click="save">
            儲存進度
          </UButton>
        </div>
      </div>
    </template>
  </UModal>
</template>
