<script setup lang="ts">
/**
 * PRORIL 通行證登入完成後導回的頁面（NUXT_PUBLIC_OAUTH_REDIRECT_URI 要指到這裡）。
 *
 * 流程：比對 state -> 拿 code 打 /api/auth/sso（server 端換 token + 換內部 JWT）
 * -> 存 proril-token -> 導回業務中心。
 *
 * 現況：Manufacturing Center 已定案為唯一入口，正式流程走 /auth/handoff，
 * 這條路只留給本機開發／備用，見 pages/login.vue 的說明。
 */
definePageMeta({
  layout: false
})

const route = useRoute()
const status = ref<'loading' | 'error'>('loading')
const errorMessage = ref('')

onMounted(async () => {
  const code = route.query.code as string | undefined
  const state = route.query.state as string | undefined
  const ssoError = route.query.error as string | undefined

  if (ssoError) {
    status.value = 'error'
    errorMessage.value = (route.query.error_description as string) || `PRORIL 通行證回傳錯誤：${ssoError}`
    return
  }

  if (!code || !state) {
    status.value = 'error'
    errorMessage.value = '缺少授權碼或 state，請重新登入'
    return
  }

  if (!consumeSsoState(state)) {
    status.value = 'error'
    errorMessage.value = 'state 比對失敗，可能是逾時或被重放的連結，請重新登入'
    return
  }

  try {
    const result = await $fetch<{ status: boolean, token?: string | null, message?: string | null }>('/api/auth/sso', {
      method: 'POST',
      body: { code }
    })

    if (!result.status || !result.token) {
      status.value = 'error'
      errorMessage.value = result.message || 'SSO 登入失敗'
      return
    }

    localStorage.setItem('proril-token', result.token)
    await navigateTo('/sales-center')
  } catch (err: any) {
    console.log('SSO callback failed -->', err)
    status.value = 'error'
    errorMessage.value = err?.data?.statusMessage || err?.message || 'SSO 登入失敗'
  }
})
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-navy-950 px-4">
    <div class="w-full max-w-sm rounded-lg bg-white p-8 text-center shadow-lg">
      <template v-if="status === 'loading'">
        <p class="text-navy-900">
          登入中，請稍候...
        </p>
      </template>
      <template v-else>
        <p class="text-red-600">
          {{ errorMessage }}
        </p>
        <UButton class="mt-4" to="/login">
          重新登入
        </UButton>
      </template>
    </div>
  </div>
</template>
