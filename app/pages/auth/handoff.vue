<script setup lang="ts">
/**
 * 從 Manufacturing Center 轉入的身分交接頁（**過渡用**）。
 *
 * 正式登入流程是業務中心自己對 PRORIL 通行證走 OAuth（見 utils/ssoAuth.ts）。
 * 這頁留著是為了相容 Manufacturing Center 目前的「帶 ticket 導頁過來」做法：
 * 使用者在那邊完成登入後，導頁過來時網址帶 ticket（/auth/handoff?ticket=xxx），
 * 這裡拿 ticket 換 Sales Center 自己的 token。
 * 等 Manufacturing Center 改成只放連結、不帶票證之後，這頁連同 server/api/auth/handoff.post.ts、
 * server/utils/verifyHandoffTicket.ts、NUXT_MFG_HANDOFF_SECRET 一起移除。
 */
definePageMeta({
  layout: false
})

const route = useRoute()
const config = useRuntimeConfig()
const status = ref<'loading' | 'error'>('loading')
const errorMessage = ref('')

onMounted(async () => {
  const ticket = route.query.ticket as string | undefined

  if (!ticket) {
    status.value = 'error'
    errorMessage.value = '缺少票證，請從製造中心重新進入'
    return
  }

  try {
    const result = await $fetch<{ status: boolean, token?: string | null, message?: string | null }>('/api/auth/handoff', {
      method: 'POST',
      body: { ticket }
    })

    if (!result.status || !result.token) {
      status.value = 'error'
      errorMessage.value = result.message || '身分驗證失敗'
      return
    }

    setAuthToken(result.token)
    await navigateTo('/sales-center')
  } catch (err: any) {
    console.log('handoff failed -->', err)
    status.value = 'error'
    errorMessage.value = err?.data?.statusMessage || err?.message || '身分驗證失敗'
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
        <UButton v-if="config.public.oauthClientId" class="mt-4" to="/login">
          透過 PRORIL 通行證登入
        </UButton>
        <UButton v-else-if="config.public.mfgCenterUrl" class="mt-4" :to="config.public.mfgCenterUrl" external>
          回製造中心重新進入
        </UButton>
      </template>
    </div>
  </div>
</template>
