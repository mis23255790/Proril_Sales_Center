<script setup lang="ts">
/**
 * 議題內文編輯器。
 *
 * 取代舊系統的 Summernote（jQuery 外掛，2.0 沒有 jQuery）。
 * 刻意不引第三方編輯器套件：DB 裡既有的內文就是一堆帶 inline style 的
 * HTML（table / span / font-family: Times New Roman），用 contenteditable +
 * execCommand 產出的結構跟舊資料同一種，新舊內容混在一起也不會走樣。
 *
 * execCommand 雖然標記為 deprecated，但所有主流瀏覽器都還支援，
 * 而且是唯一不用自建 selection model 就能就地編輯的做法。
 */

const props = withDefaults(defineProps<{
  modelValue?: string
  minHeight?: string
  placeholder?: string
  disabled?: boolean
}>(), {
  modelValue: '',
  minHeight: '360px',
  placeholder: '輸入內容...',
  disabled: false
})

const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

const toast = useToast()
const editorRef = ref<HTMLDivElement | null>(null)
const showSource = ref(false)
const sourceText = ref('')
const isEmpty = ref(true)

/** 舊資料的預設字體，保持一致才不會同一則進度裡兩種字。 */
const DEFAULT_FONT = 'Times New Roman'

const FONT_SIZES = [
  { label: '小 12', value: '12px' },
  { label: '內文 16', value: '16px' },
  { label: '中 20', value: '20px' },
  { label: '大 24', value: '24px' },
  { label: '標題 32', value: '32px' }
]

const TEXT_COLORS = [
  '#000000', '#374151', '#dc2626', '#ea580c', '#e26a23',
  '#ca8a04', '#16a34a', '#0891b2', '#2563eb', '#7c3aed'
]

const HIGHLIGHT_COLORS = ['#fef08a', '#bbf7d0', '#bfdbfe', '#fecaca', '#e9d5ff', 'transparent']

const syncEmpty = () => {
  const html = editorRef.value?.innerHTML ?? ''
  isEmpty.value = html.replace(/<br\s*\/?>|&nbsp;|\s/gi, '').replace(/<[^>]*>/g, '') === ''
}

const emitChange = () => {
  try {
    if (!editorRef.value) return
    syncEmpty()
    emit('update:modelValue', isEmpty.value ? '' : editorRef.value.innerHTML)
  } catch (err) {
    console.log('RichTextEditor emitChange failed -->', err)
  }
}

/** 外部塞值時才覆寫 DOM，否則每次打字都會重設游標。 */
const setContent = (html: string) => {
  try {
    if (!editorRef.value) return
    if (editorRef.value.innerHTML === (html || '')) return
    editorRef.value.innerHTML = html || ''
    // 舊內文常帶 line-height: 0.3 會疊字，載進來就先清掉，
    // 編輯畫面才會跟 IssueContentView 看起來一樣。
    fixLegacyLineHeight(editorRef.value)
    syncEmpty()
  } catch (err) {
    console.log('RichTextEditor setContent failed -->', err)
  }
}

watch(() => props.modelValue, value => setContent(value ?? ''))

onMounted(() => {
  try {
    setContent(props.modelValue ?? '')
    // 讓 Enter 產生 <br> 而不是新的 <div>，跟舊 Summernote 的輸出一致。
    document.execCommand('defaultParagraphSeparator', false, 'br')
  } catch (err) {
    console.log('RichTextEditor onMounted failed -->', err)
  }
})

const exec = (command: string, value?: string) => {
  try {
    if (props.disabled) return
    editorRef.value?.focus()
    document.execCommand(command, false, value)
    emitChange()
  } catch (err) {
    console.log(`RichTextEditor exec ${command} failed -->`, err)
  }
}

/**
 * 字級。
 *
 * execCommand('fontSize') 只吃 1~7 這種古董尺寸，所以改成包 span
 * 直接寫 style。有選取範圍才動，沒選取就當作沒按。
 */
const applyFontSize = (size: string) => {
  try {
    if (props.disabled) return
    const selection = window.getSelection()
    if (!selection || selection.isCollapsed || !selection.rangeCount) {
      toast.add({ title: '請先選取要調整的文字', color: 'warning' })
      return
    }
    const range = selection.getRangeAt(0)
    const span = document.createElement('span')
    span.style.fontSize = size
    span.style.fontFamily = DEFAULT_FONT
    span.appendChild(range.extractContents())
    range.insertNode(span)
    selection.removeAllRanges()
    emitChange()
  } catch (err) {
    console.log('RichTextEditor applyFontSize failed -->', err)
  }
}

const applyColor = (color: string) => exec('foreColor', color)
const applyHighlight = (color: string) => exec('hiliteColor', color)

const insertLink = () => {
  try {
    const url = window.prompt('連結網址')
    if (!url) return
    exec('createLink', url)
  } catch (err) {
    console.log('RichTextEditor insertLink failed -->', err)
  }
}

const fileInput = ref<HTMLInputElement | null>(null)

/**
 * 圖片一律轉 base64 內嵌。
 *
 * 舊系統也是這樣存（SaveDetail 的註解寫 "base64 <img> string is OK"），
 * 所以內文不需要另一套圖片檔案管理。代價是大圖會讓 ProcessContent 變很肥。
 */
const onPickImage = async (event: Event) => {
  try {
    const input = event.target as HTMLInputElement
    const file = input.files?.[0]
    if (!file) return

    if (file.size > 2 * 1024 * 1024) {
      toast.add({ title: '圖片請小於 2MB', description: '過大的圖片會讓內文存檔變慢', color: 'warning' })
      input.value = ''
      return
    }

    const dataUrl = await new Promise<string>((resolve, reject) => {
      const reader = new FileReader()
      reader.onload = () => resolve(String(reader.result))
      reader.onerror = reject
      reader.readAsDataURL(file)
    })

    exec('insertHTML', `<img src="${dataUrl}" style="max-width:100%;height:auto;" />`)
    input.value = ''
  } catch (err) {
    console.log('RichTextEditor onPickImage failed -->', err)
    toast.add({ title: '插入圖片失敗', color: 'error' })
  }
}

const insertTable = (rows: number, cols: number) => {
  try {
    const cell = '<td style="border:1px solid #94a3b8;padding:6px;min-width:60px;">&nbsp;</td>'
    const body = Array.from({ length: rows }, () => `<tr>${cell.repeat(cols)}</tr>`).join('')
    exec('insertHTML', `<table style="border-collapse:collapse;width:100%;">${body}</table><p><br></p>`)
  } catch (err) {
    console.log('RichTextEditor insertTable failed -->', err)
  }
}

/**
 * 貼上一律洗一遍。
 *
 * 從 Word / Outlook 貼過來會夾帶 <style>、class、事件屬性，
 * 洗掉才不會把整頁的樣式污染掉 —— 這是舊系統 summernote onPaste 想做但沒做乾淨的事。
 */
const onPaste = (event: ClipboardEvent) => {
  try {
    if (props.disabled) return
    const html = event.clipboardData?.getData('text/html')
    if (!html) return

    event.preventDefault()
    const doc = new DOMParser().parseFromString(html, 'text/html')
    doc.querySelectorAll('script, style, meta, link').forEach(el => el.remove())
    doc.querySelectorAll('*').forEach((el) => {
      el.removeAttribute('class')
      el.removeAttribute('id')
      for (const attr of Array.from(el.attributes)) {
        if (attr.name.startsWith('on')) el.removeAttribute(attr.name)
      }
    })
    exec('insertHTML', doc.body.innerHTML)
  } catch (err) {
    console.log('RichTextEditor onPaste failed -->', err)
  }
}

const toggleSource = () => {
  try {
    if (showSource.value) {
      setContent(sourceText.value)
      emitChange()
    } else {
      sourceText.value = editorRef.value?.innerHTML ?? ''
    }
    showSource.value = !showSource.value
  } catch (err) {
    console.log('RichTextEditor toggleSource failed -->', err)
  }
}
</script>

<template>
  <div class="overflow-hidden rounded-lg border border-default">
    <!--
      工具列。
      整塊擋掉 mousedown 的預設行為：不擋的話，按下按鈕的瞬間焦點會離開
      contenteditable、選取範圍被收掉，execCommand 就變成對空選取下指令
      （症狀：選了字按粗體完全沒反應）。
    -->
    <div
      class="flex flex-wrap items-center gap-1 border-b border-default bg-elevated/50 px-2 py-1.5"
      @mousedown.prevent
    >
      <UButton icon="i-lucide-undo-2" color="neutral" variant="ghost" size="xs" :disabled="disabled" title="復原" @click="exec('undo')" />
      <UButton icon="i-lucide-redo-2" color="neutral" variant="ghost" size="xs" :disabled="disabled" title="重做" @click="exec('redo')" />

      <div class="mx-1 h-5 w-px bg-accented" />

      <UButton icon="i-lucide-bold" color="neutral" variant="ghost" size="xs" :disabled="disabled" title="粗體" @click="exec('bold')" />
      <UButton icon="i-lucide-italic" color="neutral" variant="ghost" size="xs" :disabled="disabled" title="斜體" @click="exec('italic')" />
      <UButton icon="i-lucide-underline" color="neutral" variant="ghost" size="xs" :disabled="disabled" title="底線" @click="exec('underline')" />
      <UButton icon="i-lucide-strikethrough" color="neutral" variant="ghost" size="xs" :disabled="disabled" title="刪除線" @click="exec('strikeThrough')" />

      <div class="mx-1 h-5 w-px bg-accented" />

      <UPopover>
        <UButton icon="i-lucide-type" color="neutral" variant="ghost" size="xs" :disabled="disabled" title="字級" trailing-icon="i-lucide-chevron-down" />
        <template #content>
          <div class="flex w-40 flex-col p-1">
            <button
              v-for="size in FONT_SIZES"
              :key="size.value"
              type="button"
              class="rounded px-2 py-1.5 text-left text-sm hover:bg-elevated"
              @click="applyFontSize(size.value)"
            >
              {{ size.label }}
            </button>
          </div>
        </template>
      </UPopover>

      <UPopover>
        <UButton icon="i-lucide-palette" color="neutral" variant="ghost" size="xs" :disabled="disabled" title="文字顏色" />
        <template #content>
          <div class="grid grid-cols-5 gap-1 p-2">
            <button
              v-for="color in TEXT_COLORS"
              :key="color"
              type="button"
              class="size-6 rounded border border-default"
              :style="{ backgroundColor: color }"
              @click="applyColor(color)"
            />
          </div>
        </template>
      </UPopover>

      <UPopover>
        <UButton icon="i-lucide-highlighter" color="neutral" variant="ghost" size="xs" :disabled="disabled" title="螢光筆" />
        <template #content>
          <div class="grid grid-cols-3 gap-1 p-2">
            <button
              v-for="color in HIGHLIGHT_COLORS"
              :key="color"
              type="button"
              class="size-6 rounded border border-default"
              :style="{ backgroundColor: color }"
              @click="applyHighlight(color)"
            />
          </div>
        </template>
      </UPopover>

      <div class="mx-1 h-5 w-px bg-accented" />

      <UButton icon="i-lucide-list" color="neutral" variant="ghost" size="xs" :disabled="disabled" title="項目符號" @click="exec('insertUnorderedList')" />
      <UButton icon="i-lucide-list-ordered" color="neutral" variant="ghost" size="xs" :disabled="disabled" title="編號清單" @click="exec('insertOrderedList')" />
      <UButton icon="i-lucide-align-left" color="neutral" variant="ghost" size="xs" :disabled="disabled" title="靠左" @click="exec('justifyLeft')" />
      <UButton icon="i-lucide-align-center" color="neutral" variant="ghost" size="xs" :disabled="disabled" title="置中" @click="exec('justifyCenter')" />

      <div class="mx-1 h-5 w-px bg-accented" />

      <UButton icon="i-lucide-link" color="neutral" variant="ghost" size="xs" :disabled="disabled" title="插入連結" @click="insertLink" />
      <UButton icon="i-lucide-image" color="neutral" variant="ghost" size="xs" :disabled="disabled" title="插入圖片" @click="fileInput?.click()" />

      <UPopover>
        <UButton icon="i-lucide-table" color="neutral" variant="ghost" size="xs" :disabled="disabled" title="插入表格" />
        <template #content>
          <div class="flex w-44 flex-col p-1">
            <button type="button" class="rounded px-2 py-1.5 text-left text-sm hover:bg-elevated" @click="insertTable(2, 2)">
              2 × 2
            </button>
            <button type="button" class="rounded px-2 py-1.5 text-left text-sm hover:bg-elevated" @click="insertTable(3, 3)">
              3 × 3
            </button>
            <button type="button" class="rounded px-2 py-1.5 text-left text-sm hover:bg-elevated" @click="insertTable(5, 4)">
              5 列 × 4 欄
            </button>
          </div>
        </template>
      </UPopover>

      <UButton icon="i-lucide-minus" color="neutral" variant="ghost" size="xs" :disabled="disabled" title="分隔線" @click="exec('insertHorizontalRule')" />
      <UButton icon="i-lucide-eraser" color="neutral" variant="ghost" size="xs" :disabled="disabled" title="清除格式" @click="exec('removeFormat')" />

      <div class="ml-auto">
        <UButton
          :icon="showSource ? 'i-lucide-eye' : 'i-lucide-code'"
          color="neutral"
          variant="ghost"
          size="xs"
          :disabled="disabled"
          :title="showSource ? '回到編輯畫面' : '檢視 HTML 原始碼'"
          @click="toggleSource"
        />
      </div>

      <input ref="fileInput" type="file" accept="image/*" class="hidden" @change="onPickImage">
    </div>

    <!-- 編輯區 -->
    <textarea
      v-if="showSource"
      v-model="sourceText"
      class="block w-full resize-y bg-white p-4 font-mono text-xs text-gray-900 outline-none"
      :style="{ minHeight }"
      spellcheck="false"
    />
    <div v-else class="relative">
      <p
        v-if="isEmpty"
        class="pointer-events-none absolute left-4 top-4 text-sm text-gray-400"
      >
        {{ placeholder }}
      </p>
      <div
        ref="editorRef"
        class="issue-editor-body block w-full overflow-y-auto bg-white p-4 text-gray-900 outline-none"
        :style="{ minHeight, maxHeight: '58vh' }"
        :contenteditable="!disabled"
        @input="emitChange"
        @blur="emitChange"
        @paste="onPaste"
      />
    </div>
  </div>
</template>

<style scoped>
/*
 * 內文樣式跟「檢視」用的 .issue-content 必須一致，
 * 否則編輯時看到的排版跟存完在列表上看到的不一樣。
 */
.issue-editor-body {
  font-family: 'Times New Roman', 'Noto Sans TC', serif;
  font-size: 16px;
  line-height: 1.5;
  word-break: break-word;
}

.issue-editor-body :deep(table) {
  border-collapse: collapse;
  max-width: 100%;
}

.issue-editor-body :deep(td),
.issue-editor-body :deep(th) {
  border: 1px solid #94a3b8;
  padding: 6px;
}

.issue-editor-body :deep(img) {
  max-width: 100%;
  height: auto;
}

.issue-editor-body :deep(ul) {
  list-style: disc;
  padding-left: 1.5rem;
}

.issue-editor-body :deep(ol) {
  list-style: decimal;
  padding-left: 1.5rem;
}

.issue-editor-body :deep(a) {
  color: #2563eb;
  text-decoration: underline;
}
</style>
