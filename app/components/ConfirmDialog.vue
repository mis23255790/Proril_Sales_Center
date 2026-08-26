<script setup lang="ts">
withDefaults(defineProps<{
  title?: string
  description?: string
  confirmLabel?: string
  confirmColor?: 'primary' | 'error' | 'warning' | 'neutral'
}>(), {
  title: '確認',
  confirmLabel: '確認',
  confirmColor: 'primary'
})

const emit = defineEmits<{ close: [value: boolean] }>()
</script>

<template>
  <UModal :title="title" :description="description" :dismissible="false">
    <template #footer>
      <UButton color="neutral" variant="outline" label="取消" @click="emit('close', false)" />
      <UButton :color="confirmColor" :label="confirmLabel" @click="emit('close', true)" />
    </template>
  </UModal>
</template>
