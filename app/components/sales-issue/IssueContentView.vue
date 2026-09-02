<script setup lang="ts">
/**
 * 顯示議題內文（DB 存的是帶 inline style 的 HTML）。
 *
 * 內容是內部人員在編輯器裡打的，但仍然過一次消毒：
 * 這些 HTML 有不少是從 Outlook / Word 貼進來的，夾帶 <script> 或
 * on* 事件屬性並非不可能，而 v-html 不會幫你擋。
 */
const props = withDefaults(defineProps<{
  html?: string | null
  emptyText?: string
}>(), {
  html: '',
  emptyText: '（無內容）'
})

const sanitized = computed(() => {
  try {
    const raw = props.html ?? ''
    if (!raw.trim()) return ''
    if (import.meta.server) return ''

    const doc = new DOMParser().parseFromString(raw, 'text/html')
    doc.querySelectorAll('script, style, iframe, object, embed, link, meta').forEach(el => el.remove())
    doc.querySelectorAll('*').forEach((el) => {
      for (const attr of Array.from(el.attributes)) {
        const name = attr.name.toLowerCase()
        if (name.startsWith('on')) el.removeAttribute(attr.name)
        if ((name === 'href' || name === 'src') && attr.value.trim().toLowerCase().startsWith('javascript:')) {
          el.removeAttribute(attr.name)
        }
      }
    })
    doc.querySelectorAll('a').forEach((el) => {
      el.setAttribute('target', '_blank')
      el.setAttribute('rel', 'noopener noreferrer')
    })
    fixLegacyLineHeight(doc.body)
    return doc.body.innerHTML
  } catch (err) {
    console.log('IssueContentView sanitize failed -->', err)
    return ''
  }
})
</script>

<template>
  <div>
    <ClientOnly>
      <div v-if="sanitized" class="issue-content" v-html="sanitized" />
      <p v-else class="text-sm text-gray-400">
        {{ emptyText }}
      </p>
      <template #fallback>
        <div class="h-16 animate-pulse rounded bg-gray-100" />
      </template>
    </ClientOnly>
  </div>
</template>

<style scoped>
/* 與 RichTextEditor 的 .issue-editor-body 保持同一組規則。 */
.issue-content {
  font-family: 'Times New Roman', 'Noto Sans TC', serif;
  font-size: 16px;
  line-height: 1.5;
  color: #111827;
  word-break: break-word;
  overflow-x: auto;
}

.issue-content :deep(table) {
  border-collapse: collapse;
  max-width: 100%;
}

.issue-content :deep(td),
.issue-content :deep(th) {
  border: 1px solid #94a3b8;
  padding: 6px;
}

.issue-content :deep(img) {
  max-width: 100%;
  height: auto;
}

.issue-content :deep(ul) {
  list-style: disc;
  padding-left: 1.5rem;
}

.issue-content :deep(ol) {
  list-style: decimal;
  padding-left: 1.5rem;
}

.issue-content :deep(a) {
  color: #2563eb;
  text-decoration: underline;
}
</style>
