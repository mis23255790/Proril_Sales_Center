import type { MemoItem } from '~/types/test'

export const useMemo = (linkType: number, linkNumber: Ref<string> | ComputedRef<string>) => {
  const { apiFetch } = useApi()
  const memos = ref<MemoItem[]>([])
  const loading = ref(false)
  const saving = ref(false)

  const fetchMemos = async () => {
    if (!linkNumber.value) {
      memos.value = []
      return
    }
    loading.value = true
    try {
      memos.value = await apiFetch<MemoItem[]>('/MemoApi/GetMemoList', {
        params: { linkType, linkNumber: linkNumber.value }
      }) ?? []
    } finally {
      loading.value = false
    }
  }

  const addMemo = async (content: string) => {
    if (!content.trim() || !linkNumber.value) return
    saving.value = true
    try {
      await apiFetch<boolean>('/MemoApi/AddMemo', {
        params: { linkType, linkNumber: linkNumber.value, content }
      })
      await fetchMemos()
    } finally {
      saving.value = false
    }
  }

  const removeMemo = async (index: number) => {
    await apiFetch<boolean>('/MemoApi/AbandonedMemo', { params: { index } })
    await fetchMemos()
  }

  return { memos, loading, saving, fetchMemos, addMemo, removeMemo }
}
