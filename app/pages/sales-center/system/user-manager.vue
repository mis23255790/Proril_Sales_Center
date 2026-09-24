<script setup lang="ts">
/**
 * 人員管理。對應 1.0 系統設定 / 人員管理（Views/System/UserManager.cshtml）。
 *
 * 左邊一進來就列出全部帳號（GetAllUserList，可用工號／姓名篩選），點一列在右邊編輯。
 * 新增：按「新增人員」開空白表單（自己填工號），工號已存在就擋下來。
 * 1.0 是先輸入工號查詢、查不到直接變新增模式，打錯工號很容易順手建出錯的帳號，2.0 拆開。
 *
 * 1.0 的「管理人員」開關改成指派角色（RBAC）：系統管理員就是 superAdmin 角色，
 * 只有 superAdmin 自己能指派／移除（後端 SetUserRoles 也擋）。
 * 「全體使用者」角色所有人自動擁有，不出現在選單裡。
 */
import { getPaginationRowModel } from '@tanstack/vue-table'
import type { TableColumn } from '@nuxt/ui'
import ConfirmDialog from '~/components/common/ConfirmDialog.vue'
import type { RoleListItem, UserListItem, UserSetting } from '~/types/system'

useSeoMeta({ title: '人員管理 · 系統管理 · PRORIL 業務中心' })

const PAGE_KEY = PERMISSION_KEYS.system.userManager

const api = useSystemSettingApi()
const toast = useToast()
const overlay = useOverlay()
const { breadcrumbFor, appPath, canAccess, loadUserFunctions } = useAppNavigation()
const { loadPermissions, isSuperAdmin } = usePermission()
const { pagination } = useTablePagination(20)
const table = useTemplateRef('table')

const loading = ref(false)
const saving = ref(false)
/** 切換帳號時只讓編輯區變淡，不蓋整頁遮罩（見權限管理同名變數）。 */
const userLoading = ref(false)
const users = ref<UserListItem[]>([])
const roles = ref<RoleListItem[]>([])

// ------------------------------------------------------------------ 列表

const keyword = ref('')
const statusFilter = ref<'all' | 'enabled' | 'disabled' | 'locked'>('all')
const statusOptions = [
  { label: '全部狀態', value: 'all' },
  { label: '啟用中', value: 'enabled' },
  { label: '已停用', value: 'disabled' },
  { label: '已鎖定', value: 'locked' }
]

const visibleUsers = computed(() => {
  const kw = keyword.value.trim().toLowerCase()
  return users.value.filter((u) => {
    if (statusFilter.value === 'enabled' && !u.isEnable) return false
    if (statusFilter.value === 'disabled' && u.isEnable) return false
    if (statusFilter.value === 'locked' && !u.isLocked) return false
    if (!kw) return true
    return u.account.trim().toLowerCase().includes(kw) || (u.userName ?? '').toLowerCase().includes(kw)
  })
})

watch([keyword, statusFilter], () => {
  pagination.value.pageIndex = 0
})

const columns: TableColumn<UserListItem>[] = [
  { accessorKey: 'account', header: '工號' },
  { accessorKey: 'userName', header: '姓名' },
  { id: 'status', header: '狀態' }
]

// ------------------------------------------------------------------ 編輯

/** 'edit' = 編輯某個帳號；'new' = 按了「新增人員」。 */
const mode = ref<'none' | 'edit' | 'new'>('none')
/** 目前編輯中的帳號（編輯模式）。 */
const currentAccount = ref('')
const locked = ref(false)

const form = reactive({
  /** 只有新增模式用；編輯模式的帳號是 currentAccount。 */
  account: '',
  userName: '',
  isEnable: true,
  roleIds: [] as number[]
})
/** 讀進來時的角色，存檔時比對有沒有改，沒改就不打 SetUserRoles。 */
const originalRoleIds = ref<number[]>([])

/**
 * 可指派的角色（不含 everyone）。superAdmin 只有 superAdmin 能動：
 * 其他人看得到這個選項但不能勾／取消。
 */
const roleOptions = computed(() =>
  roles.value
    .filter(r => !r.isDefault)
    .map(r => ({
      label: r.isSuperAdmin ? `${r.roleName}（全放行）` : r.roleName,
      value: r.id,
      disabled: r.isSuperAdmin && !isSuperAdmin.value
    }))
)
const roleNameOf = (id: number) => roles.value.find(r => r.id === id)?.roleName ?? `#${id}`
const sameIds = (a: number[], b: number[]) =>
  a.length === b.length && [...a].sort((x, y) => x - y).join(',') === [...b].sort((x, y) => x - y).join(',')

const loadUsers = async () => {
  try {
    const res = await api.getAllUserList()
    users.value = res?.isSuccess ? (res.body ?? []) : []
  } catch (err) {
    console.log('load user list failed -->', err)
    users.value = []
  }
}

const loadRoles = async () => {
  try {
    const res = await api.getRoleList()
    roles.value = res?.isSuccess ? (res.body ?? []) : []
  } catch (err) {
    console.log('load role list failed -->', err)
    roles.value = []
  }
}

onMounted(async () => {
  loading.value = true
  try {
    await loadUserFunctions()
    await Promise.all([loadUsers(), loadRoles()])
  } finally {
    loading.value = false
  }
})

const applyUser = (user: UserSetting) => {
  mode.value = 'edit'
  form.account = ''
  form.userName = user.userName
  form.isEnable = user.isEnable
  form.roleIds = [...(user.roleIds ?? [])]
  originalRoleIds.value = [...form.roleIds]
  locked.value = user.isLocked
}

/** 點列表的一列：讀這個帳號的設定進編輯區。 */
const openUser = async (accountValue: string) => {
  const value = accountValue.trim()
  if (!value) return

  userLoading.value = true
  try {
    const res = await api.getUserSetting(value)
    if (!res?.isSuccess) {
      toast.add({ title: res?.message || '讀取帳號失敗', color: 'error' })
      return
    }
    // 查無帳號時後端回 isSuccess = true 但 body = null（列表跟 DB 不同步，例如別人剛刪掉）
    if (!res.body) {
      toast.add({ title: `查無帳號 ${value}`, description: '可能已被刪除，列表已重新整理。', color: 'warning' })
      mode.value = 'none'
      await loadUsers()
      return
    }
    currentAccount.value = value
    applyUser(res.body)
  } catch (err) {
    console.log('open user failed -->', err)
  } finally {
    userLoading.value = false
  }
}

/** 「新增人員」：開一張空白表單。 */
const startNew = () => {
  currentAccount.value = ''
  form.account = ''
  form.userName = ''
  form.isEnable = true
  form.roleIds = []
  originalRoleIds.value = []
  locked.value = false
  mode.value = 'new'
}

const cancelNew = () => {
  mode.value = 'none'
}

/**
 * 動作完成後重載列表；after = 'reopen' 重讀該帳號（編輯區顯示最新狀態），
 * 'close' 收起編輯區（刪除之後）。
 */
const runAction = async (
  label: string,
  action: () => Promise<{ isSuccess: boolean, message?: string | null }>,
  after: 'reopen' | 'close' = 'reopen'
) => {
  saving.value = true
  try {
    const res = await action()
    if (!res?.isSuccess) {
      toast.add({ title: `${label}失敗`, description: res?.message ?? undefined, color: 'error' })
      return
    }
    toast.add({ title: `${label}完成`, color: 'success' })
    await loadUsers()
    if (after === 'close') {
      mode.value = 'none'
      currentAccount.value = ''
    } else {
      await openUser(currentAccount.value)
    }
  } catch (err) {
    console.log(`${label} failed -->`, err)
  } finally {
    saving.value = false
  }
}

/** 帳號本身存完再存角色；角色沒改就不打，免得非 superAdmin 碰到 superAdmin 的檢查。 */
const saveRoles = async () => {
  if (sameIds(form.roleIds, originalRoleIds.value)) return { isSuccess: true }
  const res = await api.setUserRoles(currentAccount.value, form.roleIds)
  if (!res?.isSuccess) return { isSuccess: false, message: `帳號已儲存，但角色設定失敗：${res?.message ?? ''}` }
  // 改到的可能是自己，畫面權限與側欄一併重載
  await Promise.all([loadPermissions(true), loadUserFunctions(true)])
  return res
}

/** 新增成功後切成該帳號的編輯模式。 */
const add = async () => {
  const value = form.account.trim()
  if (!value) {
    toast.add({ title: '請先輸入工號', color: 'warning' })
    return
  }
  if (users.value.some(u => u.account.trim() === value)) {
    toast.add({ title: `帳號 ${value} 已存在`, description: '請從列表點選該帳號編輯。', color: 'warning' })
    return
  }

  await runAction('帳號新增', async () => {
    const res = await api.addUser(value, form.userName, form.isEnable)
    if (!res?.isSuccess) return res
    currentAccount.value = value
    return saveRoles()
  })
}

const save = () => runAction('帳號變更', async () => {
  const res = await api.updateUser(currentAccount.value, form.userName, form.isEnable)
  return res?.isSuccess ? saveRoles() : res
})

const reset = () => runAction('密碼重置', () => api.resetPassword(currentAccount.value))

const unlock = () => runAction('解除鎖定', () => api.unlockUser(currentAccount.value))

const confirmModal = overlay.create(ConfirmDialog)

const remove = async () => {
  const confirmed = await confirmModal.open({
    title: '刪除帳號',
    description: `確定要刪除帳號 ${currentAccount.value}？連同他的角色指派會一起刪除，無法復原。`,
    confirmLabel: '刪除',
    confirmColor: 'error'
  }).result
  if (!confirmed) return

  await runAction('帳號刪除', () => api.deleteUser(currentAccount.value), 'close')
}

const isCurrentRow = (u: UserListItem) => mode.value === 'edit' && u.account.trim() === currentAccount.value
</script>

<template>
  <div>
    <FullPageLoading :show="loading" />

    <UBreadcrumb v-if="false" :items="breadcrumbFor(appPath('system/user-manager'))" class="mb-4" />

    <div class="mb-5">
      <h1 class="text-2xl font-bold text-highlighted">
        人員管理
      </h1>
      <p class="mt-1 text-sm text-muted">
        新增／停用帳號、指派角色、重置密碼與解除鎖定。新帳號與重置後的初始密碼都等於帳號本身，並強制下次登入改密碼。
      </p>
    </div>

    <UAlert
      v-if="!canAccess(PAGE_KEY)"
      icon="i-lucide-shield-alert"
      color="warning"
      variant="subtle"
      title="沒有人員管理權限"
      description="請洽系統管理員把「人員管理」加進你的角色。"
      class="mb-4"
    />

    <div class="grid gap-6 lg:grid-cols-[minmax(0,3fr)_minmax(0,2fr)]">
      <!-- 帳號列表 -->
      <section>
        <div class="mb-2 flex flex-wrap items-center gap-2">
          <UInput
            v-model="keyword"
            icon="i-lucide-search"
            placeholder="搜尋工號或姓名"
            class="w-full sm:w-64"
          />
          <USelect
            v-model="statusFilter"
            :items="statusOptions"
            value-key="value"
            class="w-32"
          />
          <UButton icon="i-lucide-user-plus" class="ml-auto" :disabled="mode === 'new'" @click="startNew">
            新增人員
          </UButton>
        </div>

        <div class="overflow-hidden rounded-lg border border-default">
          <UTable
            ref="table"
            v-model:pagination="pagination"
            :pagination-options="{ getPaginationRowModel: getPaginationRowModel() }"
            :data="visibleUsers"
            :columns="columns"
            :ui="{ tr: clickableRowTr }"
            @select="(_e: Event, row: any) => openUser(row.original.account)"
          >
            <template #account-cell="{ row }">
              <span class="font-mono" :class="{ 'font-semibold text-highlighted': isCurrentRow(row.original) }">
                {{ row.original.account.trim() }}
              </span>
            </template>
            <template #userName-cell="{ row }">
              <span :class="{ 'font-semibold text-highlighted': isCurrentRow(row.original) }">
                {{ row.original.userName || '(未命名)' }}
              </span>
            </template>
            <template #status-cell="{ row }">
              <div class="flex flex-wrap gap-1">
                <UBadge v-if="!row.original.isEnable" color="neutral" variant="subtle" size="sm">
                  停用
                </UBadge>
                <UBadge v-if="row.original.isLocked" color="error" variant="subtle" size="sm" icon="i-lucide-lock">
                  鎖定
                </UBadge>
                <UBadge v-if="row.original.isAdmin" color="warning" variant="subtle" size="sm">
                  系統管理員
                </UBadge>
              </div>
            </template>
            <template #empty>
              <p class="py-6 text-center text-sm text-muted">
                {{ users.length ? '沒有符合條件的帳號' : '沒有帳號資料' }}
              </p>
            </template>
          </UTable>

          <TablePaginationBar :table="table" />
        </div>
      </section>

      <!-- 編輯區 -->
      <section
        class="transition-opacity duration-150"
        :class="{ 'pointer-events-none opacity-60': userLoading }"
        :aria-busy="userLoading"
      >
        <div v-if="mode === 'none'" class="rounded-lg border border-dashed border-default py-16 text-center text-sm text-muted">
          從左邊選一個帳號編輯，或按「新增人員」。
        </div>

        <div v-else class="space-y-5">
          <div class="flex flex-wrap items-center gap-2">
            <h2 class="text-lg font-semibold text-highlighted">
              {{ mode === 'new' ? '新增人員' : `${form.userName || '(未命名)'} (${currentAccount})` }}
            </h2>
            <UBadge v-if="locked" color="error" variant="subtle" icon="i-lucide-lock">
              已鎖定
            </UBadge>
          </div>

          <UFormField v-if="mode === 'new'" label="工號" required>
            <UInput v-model="form.account" placeholder="輸入新帳號的工號" class="w-full sm:w-80" />
          </UFormField>

          <UFormField label="姓名">
            <UInput v-model="form.userName" class="w-full sm:w-80" />
          </UFormField>

          <USwitch v-model="form.isEnable" label="帳號啟用" />

          <UFormField label="角色" hint="另外自動擁有「全體使用者」">
            <USelectMenu
              v-model="form.roleIds"
              :items="roleOptions"
              value-key="value"
              multiple
              placeholder="選擇角色"
              class="w-full sm:w-80"
            />
            <div v-if="form.roleIds.length" class="mt-2 flex flex-wrap gap-2">
              <UBadge v-for="id in form.roleIds" :key="id" color="neutral" variant="outline">
                {{ roleNameOf(id) }}
              </UBadge>
            </div>
          </UFormField>

          <div class="flex flex-wrap gap-2">
            <template v-if="mode === 'new'">
              <UButton icon="i-lucide-plus" :loading="saving" @click="add">
                新增帳號
              </UButton>
              <UButton color="neutral" variant="outline" :disabled="saving" @click="cancelNew">
                取消
              </UButton>
            </template>

            <template v-else>
              <UButton icon="i-lucide-save" :loading="saving" @click="save">
                儲存變更
              </UButton>
              <UButton icon="i-lucide-key-round" variant="outline" :loading="saving" @click="reset">
                密碼重置
              </UButton>
              <UButton
                v-if="locked"
                icon="i-lucide-unlock"
                color="warning"
                variant="outline"
                :loading="saving"
                @click="unlock"
              >
                解除鎖定
              </UButton>
              <UButton
                icon="i-lucide-trash-2"
                color="error"
                variant="outline"
                :loading="saving"
                @click="remove"
              >
                帳號刪除
              </UButton>
            </template>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>
