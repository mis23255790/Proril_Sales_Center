<script setup lang="ts">
defineProps<{
  show: boolean
}>()
</script>

<template>
  <Transition
    enter-active-class="transition-opacity duration-150"
    leave-active-class="transition-opacity duration-150"
    enter-from-class="opacity-0"
    leave-to-class="opacity-0"
  >
    <div v-if="show" class="fixed inset-0 z-[100] flex items-center justify-center bg-default/80 backdrop-blur-sm">
      <div class="flex flex-col items-center gap-3">
        <UIcon name="i-lucide-loader-2" class="size-10 animate-spin text-primary" />
        <p class="text-sm text-muted">
          載入中...
        </p>
      </div>
    </div>
  </Transition>
</template>
