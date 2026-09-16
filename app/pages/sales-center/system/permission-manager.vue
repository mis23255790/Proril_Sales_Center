<script setup lang="ts">
/**
 * 權限管理。對應 1.0 系統設定 / 權限管理（Views/System/PermissionManager.cshtml
 * + wwwroot/js/system/permission-manager*.js）。
 *
 * 三件事：
 *   1. 選一個人 → 樹上勾他可用的功能與細項 → 儲存（寫 M_Permission）
 *   2. 群組預設功能編輯 → 同一棵樹，存的是群組範本（寫 M_PermissionGroup）
 *   3. 群組預設功能套用 → 把群組範本勾進目前這個人的樹裡，**還要再按儲存**才生效
 *
 * 樹的組法與存檔規則在 app/utils/permissionTree.ts，兩棵樹共用。
 */
import type { DepartmentListItem, PermissionTreeNode, UserListItem } from '~/types/system'

useSeoMeta({ title: '權限管理 · 系統管理 · PRORIL 業務中心' })

const FUNCTION_NO = '0000101'

const api = useSystemSettingApi()
const toast = useToast()
const { breadcrumbFor, appPath, canAccess, loadUserFunctions } = useAppNavigation()

const loading = ref(false)
const saving = ref(false)

const users = ref<UserListItem[]>([])
const departments = ref<DepartmentListItem[]>([])
const account = ref('')
const depCode = ref('')

/** 三層主檔只載一次，換人時只重打「他有哪些權限」。 */
const tree = ref<PermissionTreeNode[]>([])
const selected = ref(new Set<string>())
const expanded = ref(new Set<string>())

const userOptions = computed(() =>
  users.value.map(u => ({ label: `${u.userName || '(未命名)'} (${u.account})`, value: u.account.trim() }))
)
const depOptions = computed(() =>
  departments.value.map(d => ({ label: `${d.depName} (${d.depCode})`, value: d.depCode.trim() }))
)

const loadMasters = async () => {
  loading.value = true
  try {
    const [systems, functions, linkTypes, userList, depList] = await Promise.all([
      api.getSystems(),
      api.getFunctions(),
      api.getLinkTypes(),
      api.getAllUserList(),
      api.getDepartments()
    ])
    tree.value = buildPermissionTree(
      systems?.body ?? [],
      functions?.body ?? [],
      linkTypes?.body ?? []
    )
    users.value = userList?.body ?? []
    departments.value = depList?.body ?? []
  } catch (err) {
    console.log('permission-manager load masters failed -->', err)
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  await loadUserFunctions()
  await loadMasters()
})

const loadUserPermissions = async () => {
  const value = account.value.trim()
  selected.value = new Set()
  if (!value) return

  loading.value = true
  try {
    const res = await api.getUserPermissions(value)
    const keys = selectedKeysFromPermissions(tree.value, res?.body ?? [])
    selected.value = keys
    // 有勾的節點就把它的祖先展開，不然使用者要自己一層層點開才看得到勾了什麼
    for (const key of expandedKeysFor(tree.value, keys)) expanded.value.add(key)
  } catch (err) {
    console.log('load user permissions failed -->', err)
  } finally {
    loading.value = false
  }
}

watch(account, loadUserPermissions)

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

const collapseAll = () => { expanded.value = new Set() }

const save = async () => {
  const value = account.value.trim()
  if (!value) {
    toast.add({ title: '未選擇人員', color: 'warning' })
    return
  }

  saving.value = true
  try {
    const { functionNos, linkTypes } = collectSelection(tree.value, selected.value)
    const res = await api.savePermissionTree(value, functionNos, linkTypes)
    if (!res?.isSuccess) {
      toast.add({ title: '設定失敗', description: res?.message ?? undefined, color: 'error' })
      return
    }
    toast.add({ title: '設定成功', color: 'success' })
  } catch (err) {
    console.log('save permission tree failed -->', err)
  } finally {
    saving.value = false
  }
}

// ------------------------------------------------------------------ 群組預設功能

/** 編輯用的第二棵樹，跟上面那棵共用節點資料但選取狀態分開。 */
const depEditorOpen = ref(false)
const depSelected = ref(new Set<string>())
const depExpanded = ref(new Set<string>())

const openDepEditor = async () => {
  if (!depCode.value.trim()) {
    toast.add({ title: '請先選擇群組', color: 'warning' })
    return
  }

  loading.value = true
  try {
    const res = await api.getDepFunctions(depCode.value.trim())
    const keys = selectedKeysFromDepFunctions(tree.value, res?.body ?? [])
    depSelected.value = keys
    depExpanded.value = expandedKeysFor(tree.value, keys)
    depEditorOpen.value = true
  } catch (err) {
    console.log('load dep functions failed -->', err)
  } finally {
    loading.value = false
  }
}

const saveDepFunctions = async () => {
  saving.value = true
  try {
    const { functionNos, linkTypes } = collectSelection(tree.value, depSelected.value)
    const res = await api.saveDepFunctions(depCode.value.trim(), functionNos, linkTypes)
    if (!res?.isSuccess) {
      toast.add({ title: '設定失敗', description: res?.message ?? undefined, color: 'error' })
      return
    }
    toast.add({ title: '設定成功', color: 'success' })
    depEditorOpen.value = false
  } catch (err) {
    console.log('save dep functions failed -->', err)
  } finally {
    saving.value = false
  }
}

/** 套用用的第三棵樹，跟編輯共用節點資料、選取狀態分開，介面跟編輯一致。 */
const applyOpen = ref(false)
const applySelected = ref(new Set<string>())
const applyExpanded = ref(new Set<string>())

const openApply = async () => {
  if (!depCode.value.trim()) {
    toast.add({ title: '請先選擇群組', color: 'warning' })
    return
  }
  if (!account.value.trim()) {
    toast.add({ title: '請先選擇人員', color: 'warning' })
    return
  }

  loading.value = true
  try {
    const res = await api.getDepFunctions(depCode.value.trim())
    const keys = selectedKeysFromDepFunctions(tree.value, res?.body ?? [])
    applySelected.value = keys
    applyExpanded.value = expandedKeysFor(tree.value, keys)
    applyOpen.value = true
  } catch (err) {
    console.log('load dep functions failed -->', err)
  } finally {
    loading.value = false
  }
}

/**
 * 套用只是把勾勾點上去，**不會存檔**——跟 1.0 一樣，套完還要按「儲存」。
 * 也不會取消掉他原本就有的權限，是聯集不是覆蓋。
 */
const applyDepFunctions = () => {
  for (const key of applySelected.value) selected.value.add(key)
  for (const key of expandedKeysFor(tree.value, applySelected.value)) expanded.value.add(key)
  applyOpen.value = false
  toast.add({ title: '已套用，記得按儲存', color: 'info' })
}
</script>

<template>
  <div>
    <FullPageLoading :show="loading" />

    <UBreadcrumb :items="breadcrumbFor(appPath('system/permission-manager'))" class="mb-4" />

    <div class="mb-5">
      <h1 class="text-2xl font-bold text-highlighted">
        權限管理
      </h1>
      <p class="mt-1 text-sm text-muted">
        逐人設定可用功能與細項權限。可以先用群組預設功能套進來再微調，套用後仍要按「儲存」才會寫入。
      </p>
    </div>

    <UAlert
      v-if="!canAccess(FUNCTION_NO)"
      icon="i-lucide-shield-alert"
      color="warning"
      variant="subtle"
      title="沒有權限管理權限"
      description="請洽系統管理員在權限管理開啟「權限管理」。"
      class="mb-4"
    />

    <div class="mb-4 flex flex-wrap items-end gap-3">
      <UFormField label="工號">
        <USelectMenu
          v-model="account"
          :items="userOptions"
          value-key="value"
          placeholder="選擇人員"
          class="w-full sm:w-72"
        />
      </UFormField>

      <UFormField label="套用群組">
        <USelectMenu
          v-model="depCode"
          :items="depOptions"
          value-key="value"
          placeholder="選擇群組"
          class="w-full sm:w-72"
        />
      </UFormField>

      <div class="flex flex-wrap gap-2">
        <UButton variant="outline" icon="i-lucide-pencil" @click="openDepEditor">
          群組預設功能編輯
        </UButton>
        <UButton variant="outline" icon="i-lucide-copy-plus" @click="openApply">
          群組預設功能套用
        </UButton>
      </div>
    </div>

    <USeparator label="權限列表" class="mb-4" />

    <div class="mb-3 flex flex-wrap items-center gap-2">
      <UButton size="xs" variant="ghost" icon="i-lucide-unfold-vertical" @click="expandAll">
        全部展開
      </UButton>
      <UButton size="xs" variant="ghost" icon="i-lucide-fold-vertical" @click="collapseAll">
        全部收合
      </UButton>

      <UButton
        class="ml-auto"
        icon="i-lucide-save"
        :loading="saving"
        :disabled="!account"
        @click="save"
      >
        儲存
      </UButton>
    </div>

    <div class="max-w-3xl rounded-lg border border-default p-3">
      <p v-if="!account" class="py-8 text-center text-sm text-muted">
        請先選擇人員。
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

    <!-- 群組預設功能編輯 -->
    <UModal v-model:open="depEditorOpen" title="群組預設功能編輯" :ui="{ content: 'max-w-3xl' }">
      <template #body>
        <p class="mb-3 text-sm text-muted">
          這裡存的是群組範本，不會改到任何人目前的權限。
        </p>
        <div class="max-h-[60vh] overflow-y-auto rounded-lg border border-default p-3">
          <PermissionTree
            :nodes="tree"
            :selected="depSelected"
            :expanded="depExpanded"
            @toggle-select="(key: string) => depSelected.has(key) ? depSelected.delete(key) : depSelected.add(key)"
            @toggle-expand="(key: string) => depExpanded.has(key) ? depExpanded.delete(key) : depExpanded.add(key)"
          />
        </div>
      </template>

      <template #footer>
        <UButton color="neutral" variant="outline" @click="depEditorOpen = false">
          取消
        </UButton>
        <UButton :loading="saving" @click="saveDepFunctions">
          存檔
        </UButton>
      </template>
    </UModal>

    <!-- 群組預設功能套用 -->
    <UModal v-model:open="applyOpen" title="群組預設功能套用" :ui="{ content: 'max-w-3xl' }">
      <template #body>
        <p class="mb-3 text-sm text-muted">
          預設帶入該群組的預設功能，可再微調。套用是聯集，不會取消目前這個人原本就有的權限。
        </p>
        <div class="max-h-[60vh] overflow-y-auto rounded-lg border border-default p-3">
          <PermissionTree
            :nodes="tree"
            :selected="applySelected"
            :expanded="applyExpanded"
            @toggle-select="(key: string) => applySelected.has(key) ? applySelected.delete(key) : applySelected.add(key)"
            @toggle-expand="(key: string) => applyExpanded.has(key) ? applyExpanded.delete(key) : applyExpanded.add(key)"
          />
        </div>
      </template>

      <template #footer>
        <UButton color="neutral" variant="outline" @click="applyOpen = false">
          取消
        </UButton>
        <UButton @click="applyDepFunctions">
          套用
        </UButton>
      </template>
    </UModal>
  </div>
</template>
