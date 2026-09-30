<script setup lang="ts">
/**
 * PRORIL 通行證登入完成後導回的頁面（NUXT_PUBLIC_OAUTH_REDIRECT_URI 要指到這裡）。
 *
 * 流程：比對 state -> 拿 code + nonce 打 /api/auth/sso（server 端換 token、驗 id_token、換內部 JWT）
 * -> server 端寫 httpOnly cookie -> 導回登入前要去的頁面（沒有就回業務中心首頁）。
 *
 * 這是正式登入流程（見 utils/ssoAuth.ts），Manufacturing Center 的 /auth/handoff 只是過渡。
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

  const sso = consumeSsoState(state)
  if (!sso) {
    status.value = 'error'
    errorMessage.value = 'state 比對失敗，可能是逾時或被重放的連結，請重新登入'
    return
  }

  try {
    const result = await $fetch<{ status: boolean, message?: string | null }>('/api/auth/sso', {
      method: 'POST',
      body: { code, nonce: sso.nonce }
    })

    // token 已由 server 端寫進 httpOnly cookie，這裡只看成功與否
    if (!result.status) {
      status.value = 'error'
      errorMessage.value = result.message || 'SSO 登入失敗'
      return
    }

    await navigateTo(sso.returnTo)
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
