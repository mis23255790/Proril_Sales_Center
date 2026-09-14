<script setup lang="ts">
defineProps<{
  collapsed?: boolean
}>()
</script>

<template>
  <img
    v-if="collapsed"
    src="/images/logo_proril_mark.png"
    alt="PRORIL"
    class="h-10 w-10 object-contain shrink-0"
  >
  <img
    v-else
    src="/images/logo_proril_long.png"
    alt="PRORIL 業務中心"
    class="h-10 w-auto object-contain shrink-0"
  >
</template>
