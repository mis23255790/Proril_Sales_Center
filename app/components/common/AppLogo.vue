<script setup lang="ts">
defineProps<{
  collapsed?: boolean
}>()
</script>

<template>
  <img
    v-if="collapsed"
    src="/images/logo_proril.png"
    alt="PRORIL"
    class="h-8 w-8 object-contain shrink-0"
  >
  <img
    v-else
    src="/images/logo_proril_long.png"
    alt="PRORIL 業務中心"
    class="h-8 w-auto object-contain shrink-0"
  >
</template>
