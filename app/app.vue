<script setup lang="ts">
import { zh_tw } from '@nuxt/ui/locale'

useHead({
  htmlAttrs: {
    lang: 'zh-Hant'
  }
})

useSeoMeta({
  title: 'PRORIL 業務中心',
  description: 'PRORIL 業務中心 2.0 — 業務議題與客戶往來管理'
})
</script>

<template>
  <UApp :locale="zh_tw">
    <NuxtLoadingIndicator color="var(--ui-primary)" />
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </UApp>
</template>
