<script setup lang="ts">
/**
 * SSO 登入頁。
 *
 * 只負責一件事：把使用者導去 PRORIL 通行證授權網址。實際登入畫面在通行證那邊，
 * 這裡不做帳密表單。換 token、寫入 proril-token 是 /auth/callback 的事。
 *
 * 現況：Manufacturing Center 已定案為 Proril2 家族唯一直接對統一入口網做 OAuth 的入口，
 * 正式流程走 /auth/handoff（見該檔案），使用者理論上不會再從這頁登入。
 * 這裡先保留當作本機開發／備用管道，之後如果確定不需要了再整批移除
 * （login.vue、auth/callback.vue、utils/ssoAuth.ts、server/api/auth/sso.post.ts 一起）。
 */
definePageMeta({
  layout: false
})

useSeoMeta({ title: '登入 - PRORIL 業務中心' })

const config = useRuntimeConfig()
const clientNotReady = computed(() => !config.public.oauthClientId)

const redirecting = ref(false)

const goToSso = () => {
  redirecting.value = true
  window.location.href = buildAuthorizeUrl()
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-navy-950 px-4">
    <div class="w-full max-w-sm">
      <div class="rounded-2xl bg-white p-8 shadow-xl">
        <div class="flex flex-col items-center gap-6">
          <AppLogo />

          <h1 class="text-xl font-bold text-navy-900">
            業務中心
          </h1>

          <UButton
            block
            size="lg"
            icon="i-lucide-circle-check"
            class="rounded-full"
            :loading="redirecting"
            :disabled="clientNotReady"
            @click="goToSso"
          >
            透過 PRORIL 通行證登入
          </UButton>

          <p v-if="clientNotReady" class="text-center text-xs text-red-600">
            尚未設定 NUXT_PUBLIC_OAUTH_CLIENT_ID，SSO 尚未可用
          </p>
        </div>
      </div>

      <p class="mt-6 text-center text-xs text-white/40">
        © {{ new Date().getFullYear() }} PRORIL 業務中心
      </p>
    </div>
  </div>
</template>
