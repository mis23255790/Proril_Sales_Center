<script setup lang="ts">
import { zh_tw } from '@nuxt/ui/locale'

// 環境變數留空時 runtimeConfig 會被蓋成空字串，這裡再補一次預設值
const favicon = useRuntimeConfig().public.favicon || '/favicon.svg'
const faviconType = favicon.endsWith('.svg') ? 'image/svg+xml' : favicon.endsWith('.png') ? 'image/png' : 'image/jpeg'

useHead({
  htmlAttrs: {
    lang: 'zh-Hant'
  },
  link: [{ rel: 'icon', type: faviconType, href: favicon }]
})

useSeoMeta({
  title: 'PRORIL 業務中心',
  description: 'PRORIL 業務中心 2.0 — 業務議題與客戶往來管理'
})
</script>

<template>
  <UApp :locale="zh_tw">
    <NuxtLoadingIndicator color="var(--ui-primary)" />
    <DevWatermark />
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </UApp>
</template>
