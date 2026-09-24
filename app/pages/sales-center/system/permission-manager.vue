<script setup lang="ts">
/**
 * 權限管理（角色制，RBAC）。取代 1.0 系統設定 / 權限管理的「逐人勾權限」。
 *
 * 左邊是角色清單，點一列進編輯：
 *   - 基本資料：代碼、名稱、說明
 *   - 權限：樹上勾這個角色可用的功能與細項（存到 RBAC_RolePermission）
 *   - 成員：哪些帳號掛這個角色（存到 RBAC_RoleUser）
 * 一個人的有效權限 = 他所有角色的聯集 ∪ everyone，不做個人例外。
 *
 * 系統角色兩個：superAdmin（全放行，不用勾樹）、everyone（所有人自動擁有，不用設成員），
 * 都不能刪、不能改代碼。superAdmin 的成員只有 superAdmin 自己能改（後端也擋）。
 * 樹來自 RBAC_Permission 單一表（模組 → 分組 → 頁面 → 細項），組法與存檔規則在
 * app/utils/permissionTree.ts；勾細項會連帶開所屬頁面、分組與模組，後端也會再補。
 */
import type { TableColumn } from '@nuxt/ui'
import ConfirmDialog from '~/components/common/ConfirmDialog.vue'
import type { PermissionTreeNode, RoleListItem, UserListItem } from '~/types/system'

useSeoMeta({ title: '權限管理 · 系統管理 · PRORIL 業務中心' })

const PAGE_KEY = PERMISSION_KEYS.system.permissionManager

const api = useSystemSettingApi()
const toast = useToast()
const overlay = useOverlay()
const { breadcrumbFor, appPath, canAccess, loadUserFunctions } = useAppNavigation()
const { loadPermissions, isSuperAdmin } = usePermission()

const loading = ref(false)
const saving = ref(false)
/**
 * 切換角色時只讓編輯區變淡、不蓋整頁遮罩：GetRole 通常一兩百毫秒就回來，
 * 用 FullPageLoading 會整頁閃一下。
 */
const roleLoading = ref(false)

const roles = ref<RoleListItem[]>([])
const users = ref<UserListItem[]>([])

/** 權限樹（RBAC_Permission 單一樹）只載一次，換角色時只重打「這個角色有哪些權限」。 */
const tree = ref<PermissionTreeNode[]>([])
const selected = ref(new Set<string>())
const expanded = ref(new Set<string>())

/** 0 = 新增中；null = 還沒選。 */
const editingId = ref<number | null>(null)
const form = reactive({
  roleCode: '',
  roleName: '',
  description: '',
  isSystem: false,
  isSuperAdmin: false,
  isDefault: false
})
const members = ref<string[]>([])
/** 載入時的成員，存檔時比對有沒有改，沒改就不打 SetRoleMembers（superAdmin 成員只有 superAdmin 能動）。 */
const originalMembers = ref<string[]>([])

const userOptions = computed(() =>
  users.value.map(u => ({
    label: `${u.userName || '(未命名)'} (${u.account.trim()})${u.isEnable ? '' : ' [停用]'}`,
    value: u.account.trim()
  }))
)
const userNameOf = (account: string) =>
  users.value.find(u => u.account.trim() === account.trim())?.userName || ''

const columns: TableColumn<RoleListItem>[] = [
  { accessorKey: 'roleName', header: '角色' },
  { accessorKey: 'permissionCount', header: '權限', meta: { class: { td: 'text-right tabular-nums', th: 'text-right' } } },
  { accessorKey: 'memberCount', header: '成員', meta: { class: { td: 'text-right tabular-nums', th: 'text-right' } } }
]

const loadRoles = async () => {
  const res = await api.getRoleList()
  roles.value = res?.isSuccess ? (res.body ?? []) : []
}

const loadMasters = async () => {
  loading.value = true
  try {
    const [permissions, userList] = await Promise.all([
      // 連停用節點一起拿，樹上顯示成 disabled
      api.getPermissions(true),
      api.getAllUserList()
    ])
    tree.value = buildPermissionTree(permissions?.body ?? [])
    users.value = userList?.body ?? []
    await loadRoles()
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

const openRole = async (roleId: number) => {
  roleLoading.value = true
  try {
    const res = await api.getRole(roleId)
    if (!res?.isSuccess || !res.body) {
      toast.add({ title: res?.message || '讀取角色失敗', color: 'error' })
      return
    }
    const role = res.body
    editingId.value = role.id
    form.roleCode = role.roleCode
    form.roleName = role.roleName
    form.description = role.description ?? ''
    form.isSystem = role.isSystem
    form.isSuperAdmin = role.isSuperAdmin
    form.isDefault = role.isDefault
    members.value = role.members.map(a => a.trim())
    originalMembers.value = [...members.value]

    const keys = selectedKeysFromPermissionKeys(tree.value, role.permissionKeys)
    selected.value = keys
    // 有勾的節點就把它的祖先展開，不然要自己一層層點開才看得到勾了什麼
    expanded.value = expandedKeysFor(tree.value, keys)
  } catch (err) {
    console.log('open role failed -->', err)
  } finally {
    roleLoading.value = false
  }
}

const newRole = () => {
  editingId.value = 0
  form.roleCode = ''
  form.roleName = ''
  form.description = ''
  form.isSystem = false
  form.isSuperAdmin = false
  form.isDefault = false
  members.value = []
  originalMembers.value = []
  selected.value = new Set()
  expanded.value = new Set()
}

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

const removeMember = (account: string) => {
  members.value = members.value.filter(a => a !== account)
}

const sameMembers = (a: string[], b: string[]) =>
  a.length === b.length && [...a].sort().join(',') === [...b].sort().join(',')

/** superAdmin 的成員只有 superAdmin 能改，其他人看得到但不能動。 */
const membersReadonly = computed(() => form.isSuperAdmin && !isSuperAdmin.value)

const save = async () => {
  if (editingId.value === null) return
  if (!form.roleName.trim()) {
    toast.add({ title: '請輸入角色名稱', color: 'warning' })
    return
  }
  if (editingId.value === 0 && !form.roleCode.trim()) {
    toast.add({ title: '請輸入角色代碼', color: 'warning' })
    return
  }

  saving.value = true
  try {
    const res = await api.saveRole({
      roleId: editingId.value,
      roleCode: form.roleCode.trim(),
      roleName: form.roleName.trim(),
      description: form.description.trim(),
      permissionKeys: form.isSuperAdmin ? [] : collectSelection(tree.value, selected.value)
    })
    if (!res?.isSuccess || !res.body) {
      toast.add({ title: '角色儲存失敗', description: res?.message ?? undefined, color: 'error' })
      return
    }
    const roleId = res.body

    if (!form.isDefault && !sameMembers(members.value, originalMembers.value)) {
      const memberRes = await api.setRoleMembers(roleId, members.value)
      if (!memberRes?.isSuccess) {
        toast.add({ title: '角色已儲存，但成員設定失敗', description: memberRes?.message ?? undefined, color: 'error' })
        await loadRoles()
        await openRole(roleId)
        return
      }
    }

    toast.add({ title: '角色已儲存', color: 'success' })
    await loadRoles()
    await openRole(roleId)
    // 改到的可能是自己的角色，側欄與畫面權限一併重載
    await Promise.all([loadPermissions(true), loadUserFunctions(true)])
  } catch (err) {
    console.log('save role failed -->', err)
  } finally {
    saving.value = false
  }
}

const confirmModal = overlay.create(ConfirmDialog)

const remove = async () => {
  if (!editingId.value || form.isSystem) return
  const confirmed = await confirmModal.open({
    title: '刪除角色',
    description: `確定要刪除角色「${form.roleName}」？這個角色的權限與成員指派會一起刪除，成員會失去這個角色給的權限，無法復原。`,
    confirmLabel: '刪除',
    confirmColor: 'error'
  }).result
  if (!confirmed) return

  saving.value = true
  try {
    const res = await api.deleteRole(editingId.value)
    if (!res?.isSuccess) {
      toast.add({ title: '角色刪除失敗', description: res?.message ?? undefined, color: 'error' })
      return
    }
    toast.add({ title: '角色已刪除', color: 'success' })
    editingId.value = null
    await loadRoles()
    await Promise.all([loadPermissions(true), loadUserFunctions(true)])
  } catch (err) {
    console.log('delete role failed -->', err)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div>
    <FullPageLoading :show="loading" />

    <UBreadcrumb v-if="false" :items="breadcrumbFor(appPath('system/permission-manager'))" class="mb-4" />

    <div class="mb-5">
      <h1 class="text-2xl font-bold text-highlighted">
        權限管理
      </h1>
      <p class="mt-1 text-sm text-muted">
        以角色管理權限：每個角色勾選可用的功能與細項，再指派成員。一個人的權限是他所有角色的聯集，
        加上「全體使用者」角色。人員的角色也可以在人員管理指派。
      </p>
    </div>

    <UAlert
      v-if="!canAccess(PAGE_KEY)"
      icon="i-lucide-shield-alert"
      color="warning"
      variant="subtle"
      title="沒有權限管理權限"
      description="請洽系統管理員把「權限管理」加進你的角色。"
      class="mb-4"
    />

    <div class="grid gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(0,3fr)]">
      <!-- 角色清單 -->
      <section>
        <div class="mb-2 flex items-center justify-between">
          <h2 class="font-semibold text-highlighted">
            角色
          </h2>
          <UButton size="sm" icon="i-lucide-plus" @click="newRole">
            新增角色
          </UButton>
        </div>

        <UTable
          :data="roles"
          :columns="columns"
          :ui="{ tr: clickableRowTr }"
          class="rounded-lg border border-default"
          @select="(_e: Event, row: any) => openRole(row.original.id)"
        >
          <template #roleName-cell="{ row }">
            <div class="flex flex-wrap items-center gap-2" :class="{ 'font-semibold': row.original.id === editingId }">
              <span>{{ row.original.roleName }}</span>
              <UBadge v-if="row.original.isSuperAdmin" color="error" variant="subtle" size="sm">
                全放行
              </UBadge>
              <UBadge v-else-if="row.original.isDefault" color="info" variant="subtle" size="sm">
                所有人
              </UBadge>
            </div>
            <div class="font-mono text-xs text-muted">
              {{ row.original.roleCode }}
            </div>
          </template>
          <template #permissionCount-cell="{ row }">
            {{ row.original.isSuperAdmin ? '全部' : row.original.permissionCount }}
          </template>
          <template #memberCount-cell="{ row }">
            {{ row.original.isDefault ? '全部' : row.original.memberCount }}
          </template>
        </UTable>
      </section>

      <!-- 編輯區 -->
      <section
        class="transition-opacity duration-150"
        :class="{ 'pointer-events-none opacity-60': roleLoading }"
        :aria-busy="roleLoading"
      >
        <div v-if="editingId === null" class="rounded-lg border border-dashed border-default py-16 text-center text-sm text-muted">
          從左邊選一個角色編輯，或按「新增角色」。
        </div>

        <div v-else class="space-y-5">
          <div class="flex flex-wrap items-center gap-2">
            <h2 class="text-lg font-semibold text-highlighted">
              {{ editingId === 0 ? '新增角色' : form.roleName }}
            </h2>
            <UBadge v-if="form.isSystem" color="neutral" variant="subtle">
              系統角色
            </UBadge>
            <div class="ml-auto flex gap-2">
              <UButton
                v-if="editingId && !form.isSystem"
                icon="i-lucide-trash-2"
                color="error"
                variant="outline"
                :loading="saving"
                @click="remove"
              >
                刪除
              </UButton>
              <UButton icon="i-lucide-save" :loading="saving" @click="save">
                儲存
              </UButton>
            </div>
          </div>

          <div class="grid gap-4 sm:grid-cols-2">
            <UFormField label="角色代碼" hint="英文開頭，英數字、底線、連字號" required>
              <UInput
                v-model="form.roleCode"
                class="w-full font-mono"
                :disabled="form.isSystem"
                placeholder="例如 salesAssistant"
              />
            </UFormField>
            <UFormField label="角色名稱" required>
              <UInput v-model="form.roleName" class="w-full" placeholder="例如 業務助理" />
            </UFormField>
            <UFormField label="說明" class="sm:col-span-2">
              <UInput v-model="form.description" class="w-full" />
            </UFormField>
          </div>

          <!-- 成員 -->
          <div>
            <USeparator label="成員" class="mb-3" />
            <p v-if="form.isDefault" class="text-sm text-muted">
              所有啟用中的帳號都自動擁有這個角色，不需要設定成員。
            </p>
            <template v-else>
              <UAlert
                v-if="membersReadonly"
                icon="i-lucide-lock"
                color="neutral"
                variant="subtle"
                title="只有系統管理員能變更系統管理員的成員"
                class="mb-3"
              />
              <USelectMenu
                v-model="members"
                :items="userOptions"
                value-key="value"
                multiple
                placeholder="搜尋並加入成員"
                class="w-full"
                :disabled="membersReadonly"
              />
              <div v-if="members.length" class="mt-3 flex flex-wrap gap-2">
                <UBadge
                  v-for="m in members"
                  :key="m"
                  color="neutral"
                  variant="outline"
                  class="gap-1"
                >
                  {{ userNameOf(m) || '(未命名)' }} ({{ m }})
                  <UButton
                    v-if="!membersReadonly"
                    size="xs"
                    color="neutral"
                    variant="link"
                    icon="i-lucide-x"
                    class="p-0"
                    :aria-label="`移除 ${m}`"
                    @click="removeMember(m)"
                  />
                </UBadge>
              </div>
              <p v-else class="mt-2 text-sm text-muted">
                還沒有成員。
              </p>
            </template>
          </div>

          <!-- 權限 -->
          <div>
            <USeparator label="權限" class="mb-3" />
            <p v-if="form.isSuperAdmin" class="text-sm text-muted">
              系統管理員全部功能放行，不需要勾選權限。
            </p>
            <template v-else>
              <div class="mb-3 flex flex-wrap items-center gap-2">
                <UButton size="xs" variant="ghost" icon="i-lucide-unfold-vertical" @click="expandAll">
                  全部展開
                </UButton>
                <UButton size="xs" variant="ghost" icon="i-lucide-fold-vertical" @click="collapseAll">
                  全部收合
                </UButton>
                <span class="ml-auto text-xs text-muted">勾選細項會自動開啟所屬頁面</span>
              </div>
              <div class="rounded-lg border border-default p-3">
                <PermissionTree
                  :nodes="tree"
                  :selected="selected"
                  :expanded="expanded"
                  @toggle-select="toggleSelect"
                  @toggle-expand="toggleExpand"
                />
              </div>
            </template>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>
