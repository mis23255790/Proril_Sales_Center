<script setup lang="ts">
/**
 * 群組權限：維護各群組（部門）的預設功能範本（M_PermissionGroup）。
 *
 * 原本是權限管理頁裡的「群組預設功能編輯」彈窗，2.0 獨立成功能 0000103，
 * 權限是 system.groupPermission.view，可以跟權限管理分開授權。
 *
 * 這裡存的只是範本，不會改到任何人目前的權限——要在權限管理頁
 * 「群組預設功能套用」再按儲存才會寫進 M_Permission。
 *
 * 樹的組法與存檔規則在 app/utils/permissionTree.ts，跟權限管理共用。
 */
import type { DepartmentListItem, PermissionTreeNode } from '~/types/system'

useSeoMeta({ title: '群組權限 · 系統管理 · PRORIL 業務中心' })

const FUNCTION_NO = '0000103'

const api = useSystemSettingApi()
const toast = useToast()
const { canAccess, loadUserFunctions } = useAppNavigation()

const loading = ref(false)
const saving = ref(false)

const departments = ref<DepartmentListItem[]>([])
const depCode = ref('')

const tree = ref<PermissionTreeNode[]>([])
const selected = ref(new Set<string>())
const expanded = ref(new Set<string>())

const depOptions = computed(() =>
  departments.value.map(d => ({ label: `${d.depName} (${d.depCode})`, value: d.depCode.trim() }))
)

const loadMasters = async () => {
  loading.value = true
  try {
    const [systems, functions, actions, depList] = await Promise.all([
      api.getSystems(),
      api.getFunctions(),
      api.getPermissionDefs(),
      api.getDepartments()
    ])
    tree.value = buildPermissionTree(systems?.body ?? [], functions?.body ?? [], actions?.body ?? [])
    departments.value = depList?.body ?? []
  } catch (err) {
    console.log('group-permission load masters failed -->', err)
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  await loadUserFunctions()
  await loadMasters()
})

const loadDepFunctions = async () => {
  const value = depCode.value.trim()
  selected.value = new Set()
  if (!value) return

  loading.value = true
  try {
    const res = await api.getDepFunctions(value)
    const keys = selectedKeysFromDepFunctions(tree.value, res?.body ?? [])
    selected.value = keys
    for (const key of expandedKeysFor(tree.value, keys)) expanded.value.add(key)
  } catch (err) {
    console.log('load dep functions failed -->', err)
  } finally {
    loading.value = false
  }
}

watch(depCode, loadDepFunctions)

const toggleSelect = (key: string) => {
  if (selected.value.has(key)) selected.value.delete(key)
  else selected.value.add(key)
}

const toggleExpand = (key: string) => {
  if (expanded.value.has(key)) expanded.value.delete(key)
  else expanded.value.add(key)
}

const expandAll = () => {
  const walk = (nodes: PermissionTreeNode[]) => {
    for (const node of nodes) {
      if (node.children.length) expanded.value.add(node.key)
      walk(node.children)
    }
  }
  walk(tree.value)
}

const collapseAll = () => {
  expanded.value = new Set()
}

const selectedCount = computed(() => collectSelection(tree.value, selected.value).length)

const save = async () => {
  const value = depCode.value.trim()
  if (!value) {
    toast.add({ title: '未選擇群組', color: 'warning' })
    return
  }

  saving.value = true
  try {
    const res = await api.saveDepPermissionKeys(value, collectSelection(tree.value, selected.value))
    if (!res?.isSuccess) {
      toast.add({ title: '設定失敗', description: res?.message ?? undefined, color: 'error' })
      return
    }
    toast.add({ title: '設定成功', color: 'success' })
  } catch (err) {
    console.log('save dep permission keys failed -->', err)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div>
    <FullPageLoading :show="loading" />

    <div class="mb-5">
      <h1 class="text-2xl font-bold text-highlighted">
        群組權限
      </h1>
      <p class="mt-1 text-sm text-muted">
        維護各群組的預設功能範本。這裡存的是範本，不會改到任何人目前的權限；
        要到「權限管理」套用後按儲存才會生效。
      </p>
    </div>

    <UAlert
      v-if="!canAccess(FUNCTION_NO)"
      icon="i-lucide-shield-alert"
      color="warning"
      variant="subtle"
      title="沒有群組權限權限"
      description="請洽系統管理員在權限管理開啟「群組權限」。"
      class="mb-4"
    />

    <div class="mb-4 flex flex-wrap items-end gap-3">
      <UFormField label="群組">
        <USelectMenu
          v-model="depCode"
          :items="depOptions"
          value-key="value"
          placeholder="選擇群組"
          class="w-full sm:w-72"
        />
      </UFormField>
    </div>

    <USeparator label="預設功能" class="mb-4" />

    <div class="mb-3 flex flex-wrap items-center gap-2">
      <UButton size="xs" variant="ghost" icon="i-lucide-unfold-vertical" @click="expandAll">
        全部展開
      </UButton>
      <UButton size="xs" variant="ghost" icon="i-lucide-fold-vertical" @click="collapseAll">
        全部收合
      </UButton>
      <span v-if="depCode" class="text-xs text-muted">已選 {{ selectedCount }} 項</span>

      <UButton
        class="ml-auto"
        icon="i-lucide-save"
        :loading="saving"
        :disabled="!depCode"
        @click="save"
      >
        儲存
      </UButton>
    </div>

    <div class="max-w-3xl rounded-lg border border-default p-3">
      <p v-if="!depCode" class="py-8 text-center text-sm text-muted">
        請先選擇群組。
      </p>
      <PermissionTree
        v-else
        :nodes="tree"
        :selected="selected"
        :expanded="expanded"
        @toggle-select="toggleSelect"
        @toggle-expand="toggleExpand"
      />
    </div>
  </div>
</template>
