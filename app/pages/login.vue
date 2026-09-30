<script setup lang="ts">
/**
 * 登入頁。不做帳密表單，實際登入畫面在 PRORIL 通行證那邊。
 *
 * - 有設 NUXT_PUBLIC_OAUTH_CLIENT_ID（正式流程）：進來就自動導去通行證授權，
 *   通行證有 session 的話會直接帶 code 回 /auth/callback，使用者幾乎看不到這頁。
 *   `?logged_out=1`（登出後）不自動導，避免一登出又立刻被登回去——
 *   通行證目前沒有 end_session 端點，登出只清得掉本站 token，通行證的 session 還在。
 * - 沒設 Client ID（過渡期）：退回舊做法，請使用者從 Manufacturing Center 進入，
 *   由那邊帶 handoff 票證過來（見 pages/auth/handoff.vue）。
 */
definePageMeta({
  layout: false
})

useSeoMeta({ title: '登入 - PRORIL 業務中心' })

const route = useRoute()
const config = useRuntimeConfig()
const oauthReady = computed(() => !!config.public.oauthClientId)
const mfgCenterUrl = computed(() => config.public.mfgCenterUrl)

const redirecting = ref(false)

const goToSso = () => {
  redirecting.value = true
  window.location.href = buildAuthorizeUrl(route.query.redirect)
}

onMounted(() => {
  if (oauthReady.value && route.query.logged_out !== '1') {
    goToSso()
  }
})
</script>

<template>
  <div
    class="min-h-screen flex items-center justify-center bg-navy-950 bg-cover bg-center px-4"
    style="background-image: url('/images/login.png')"
  >
    <div class="w-full max-w-sm">
      <div class="rounded-2xl bg-white p-8 shadow-xl">
        <div class="flex flex-col items-center gap-6">
          <AppLogo />

          <h1 class="text-xl font-bold text-navy-900">
            業務中心
          </h1>

          <template v-if="oauthReady">
            <UButton
              block
              size="lg"
              icon="i-lucide-circle-check"
              class="rounded-full"
              :loading="redirecting"
              @click="goToSso"
            >
              透過 PRORIL 通行證登入
            </UButton>

            <p v-if="route.query.logged_out === '1'" class="text-center text-xs text-navy-500">
              已登出業務中心
            </p>
          </template>

          <template v-else-if="mfgCenterUrl">
            <UButton
              block
              size="lg"
              icon="i-lucide-log-in"
              class="rounded-full"
              :to="mfgCenterUrl"
              external
            >
              從製造中心進入
            </UButton>
          </template>

          <p v-else class="text-center text-xs text-red-600">
            尚未設定 NUXT_PUBLIC_OAUTH_CLIENT_ID 或 NUXT_PUBLIC_MFG_CENTER_URL，無法登入
          </p>
        </div>
      </div>

      <p class="mt-6 text-center text-xs text-white/40">
        © {{ new Date().getFullYear() }} PRORIL 業務中心
      </p>
    </div>
  </div>
</template>
