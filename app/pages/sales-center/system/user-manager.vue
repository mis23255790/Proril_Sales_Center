<script setup lang="ts">
/**
 * 人員管理。對應 1.0 系統設定 / 人員管理（Views/System/UserManager.cshtml）。
 *
 * 流程跟 1.0 一樣：先輸入／選一個工號按查詢，查到就是「編輯模式」，
 * 查不到就是「新增模式」。差別是 1.0 靠 `res == undefined` 判斷，
 * 2.0 是 isSuccess = true 但 body = null（見 MainApi/GetUserSetting）。
 */
import ConfirmDialog from '~/components/common/ConfirmDialog.vue'
import type { UserListItem, UserSetting } from '~/types/system'

useSeoMeta({ title: '人員管理 · 系統管理 · PRORIL 業務中心' })

const FUNCTION_NO = '0000102'

const api = useSystemSettingApi()
const toast = useToast()
const overlay = useOverlay()
const { breadcrumbFor, appPath, canAccess, loadUserFunctions } = useAppNavigation()

const loading = ref(false)
const saving = ref(false)
const users = ref<UserListItem[]>([])
const account = ref('')

/** null = 還沒查過；查過但查無帳號時是 'new'。 */
const mode = ref<'none' | 'edit' | 'new'>('none')
const queriedAccount = ref('')
const locked = ref(false)

const form = reactive({
  userName: '',
  isEnable: true,
  isAdmin: false
})

const accountOptions = computed(() =>
  users.value.map(u => ({
    label: `${u.userName || '(未命名)'} (${u.account})`,
    value: u.account.trim()
  }))
)

const loadUsers = async () => {
  try {
    const res = await api.getAllUserList()
    users.value = res?.isSuccess ? (res.body ?? []) : []
  } catch (err) {
    console.log('load user list failed -->', err)
    users.value = []
  }
}

onMounted(async () => {
  await loadUserFunctions()
  await loadUsers()
})

const applyUser = (user: UserSetting | null) => {
  if (user) {
    mode.value = 'edit'
    form.userName = user.userName
    form.isEnable = user.isEnable
    form.isAdmin = user.isAdmin
    locked.value = user.isLocked
  } else {
    mode.value = 'new'
    form.userName = ''
    form.isEnable = true
    form.isAdmin = false
    locked.value = false
  }
}

const query = async () => {
  const value = account.value.trim()
  if (!value) {
    toast.add({ title: '請先輸入帳號', color: 'warning' })
    return
  }

  loading.value = true
  try {
    const res = await api.getUserSetting(value)
    if (!res?.isSuccess) {
      mode.value = 'none'
      toast.add({ title: res?.message || '查詢失敗', color: 'error' })
      return
    }
    queriedAccount.value = value
    applyUser(res.body ?? null)
  } catch (err) {
    console.log('query user failed -->', err)
    mode.value = 'none'
  } finally {
    loading.value = false
  }
}

/** 查完之後又改了工號，先前查出來的內容就不算數，避免存到別人身上。 */
watch(account, () => {
  if (account.value.trim() !== queriedAccount.value) mode.value = 'none'
})

const runAction = async (
  label: string,
  action: () => Promise<{ isSuccess: boolean, message?: string | null }>,
  after: 'requery' | 'reset' = 'requery'
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
    if (after === 'reset') {
      mode.value = 'none'
      queriedAccount.value = ''
      account.value = ''
    } else {
      await query()
    }
  } catch (err) {
    console.log(`${label} failed -->`, err)
  } finally {
    saving.value = false
  }
}

const add = () => runAction('帳號新增',
  () => api.addUser(queriedAccount.value, form.userName, form.isEnable, form.isAdmin))

const save = () => runAction('帳號變更',
  () => api.updateUser(queriedAccount.value, form.userName, form.isEnable, form.isAdmin))

const reset = () => runAction('密碼重置', () => api.resetPassword(queriedAccount.value))

const unlock = () => runAction('解除鎖定', () => api.unlockUser(queriedAccount.value))

const confirmModal = overlay.create(ConfirmDialog)

const remove = async () => {
  const confirmed = await confirmModal.open({
    title: '刪除帳號',
    description: `確定要刪除帳號 ${queriedAccount.value}？連同他的功能權限會一起刪除，無法復原。`,
    confirmLabel: '刪除',
    confirmColor: 'error'
  }).result
  if (!confirmed) return

  await runAction('帳號刪除', () => api.deleteUser(queriedAccount.value), 'reset')
}
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
        新增／停用帳號、設定管理員、重置密碼與解除鎖定。新帳號與重置後的初始密碼都等於帳號本身，並強制下次登入改密碼。
      </p>
    </div>

    <UAlert
      v-if="!canAccess(FUNCTION_NO)"
      icon="i-lucide-shield-alert"
      color="warning"
      variant="subtle"
      title="沒有人員管理權限"
      description="請洽系統管理員在權限管理開啟「人員管理」。"
      class="mb-4"
    />

    <div class="max-w-2xl space-y-5">
      <UFormField label="工號">
        <div class="flex flex-wrap gap-2">
          <UInputMenu
            v-model="account"
            :items="accountOptions"
            value-key="value"
            placeholder="輸入或選擇工號"
            class="w-full sm:w-80"
            :create-item="{ position: 'top' }"
            @create="(value: string) => { account = value }"
          />
          <UButton icon="i-lucide-search" variant="outline" :loading="loading" @click="query">
            查詢
          </UButton>
        </div>
      </UFormField>

      <template v-if="mode !== 'none'">
        <USeparator label="帳號設定" />

        <UAlert
          v-if="mode === 'new'"
          icon="i-lucide-user-plus"
          color="info"
          variant="subtle"
          :title="`查無帳號 ${queriedAccount}`"
          description="填好姓名與設定後按「新增帳號」建立。"
        />

        <UFormField label="姓名">
          <UInput v-model="form.userName" class="w-full sm:w-80" />
        </UFormField>

        <div class="flex flex-wrap items-center gap-6">
          <USwitch v-model="form.isEnable" label="帳號啟用" />
          <USwitch v-model="form.isAdmin" label="管理人員" />
          <UBadge v-if="locked" color="error" variant="subtle" icon="i-lucide-lock">
            已鎖定
          </UBadge>
        </div>

        <div class="flex flex-wrap gap-2">
          <UButton v-if="mode === 'new'" icon="i-lucide-plus" :loading="saving" @click="add">
            新增帳號
          </UButton>

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
      </template>
    </div>
  </div>
</template>
