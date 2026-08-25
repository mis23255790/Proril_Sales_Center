<script setup lang="ts">
import { zh_tw } from '@nuxt/ui/locale'

useHead({
  htmlAttrs: {
    lang: 'zh-Hant'
  }
})

useSeoMeta({
  title: 'PRORIL 製造中心',
  description: 'PRORIL 製造中心 2.0 — 現場作業管理系統'
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
