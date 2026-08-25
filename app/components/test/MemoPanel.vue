<script setup lang="ts">
const props = defineProps<{
  linkType: number
  linkNumber: string
  readonly?: boolean
}>()

const linkNumberRef = computed(() => props.linkNumber)
const { memos, loading, saving, fetchMemos, addMemo, removeMemo } = useMemo(props.linkType, linkNumberRef)

const draft = ref('')

watch(linkNumberRef, () => fetchMemos(), { immediate: true })

const submit = async () => {
  await addMemo(draft.value)
  draft.value = ''
}
</script>

<template>
  <div class="space-y-3">
    <h3 class="text-sm font-semibold text-highlighted">
      備註
    </h3>

    <div v-if="loading" class="text-sm text-muted">
      載入中...
    </div>
    <div v-else-if="!memos.length" class="text-sm text-muted">
      尚無備註
    </div>
    <ul v-else class="max-h-48 space-y-2 overflow-y-auto">
      <li
        v-for="m in memos"
        :key="m.id"
        class="flex items-start justify-between gap-2 rounded-md bg-elevated px-3 py-2 text-sm"
      >
        <div class="min-w-0">
          <p class="whitespace-pre-wrap text-highlighted">
            {{ m.memo }}
          </p>
          <p class="mt-1 text-xs text-muted">
            {{ m.userName }} · {{ m.createTime }}
          </p>
        </div>
        <UButton
          v-if="!readonly"
          icon="i-lucide-x"
          size="xs"
          color="neutral"
          variant="ghost"
          @click="removeMemo(m.id)"
        />
      </li>
    </ul>

    <div v-if="!readonly" class="flex gap-2">
      <UTextarea v-model="draft" placeholder="輸入備註內容..." class="flex-1" :rows="1" autoresize />
      <UButton icon="i-lucide-send" :loading="saving" @click="submit" />
    </div>
  </div>
</template>
