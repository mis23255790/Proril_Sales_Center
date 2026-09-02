<script setup lang="ts">
/**
 * 站台根目錄轉到業務中心。
 *
 * 所有功能都掛在 /sales-center 底下（業務中心 / 模組 / 功能，比照 1.0 的層級），
 * 這支只是讓直接開 http://host/ 的人不會看到 404。
 *
 * definePageMeta 是編譯期巨集，不能引用 useAppNavigation() 的 APP_BASE，
 * 所以這裡是唯一一處要跟著手動改的路徑。
 */
definePageMeta({
  redirect: '/sales-center'
})
</script>

<template>
  <div />
</template>
