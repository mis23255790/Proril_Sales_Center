<script setup lang="ts">
/**
 * 導覽卡片。業務中心首頁（列模組）與模組首頁（列功能）共用同一個外觀，
 * 逐層下鑽時視覺才不會跳。
 */
defineProps<{
  to: string
  icon: string
  title: string
  /** 標題下方的小字，例如所屬群組或功能數量 */
  subtitle?: string
  description?: string
}>()
</script>

<template>
  <ULink
    :to="to"
    class="group rounded-lg border border-default bg-default p-4 transition hover:border-primary hover:shadow-md"
  >
    <div class="flex items-start gap-3">
      <div class="flex size-11 shrink-0 items-center justify-center rounded-md bg-primary/10 text-primary transition group-hover:bg-primary group-hover:text-inverted">
        <UIcon :name="icon" class="size-6" />
      </div>
      <div class="min-w-0">
        <p class="truncate font-semibold text-highlighted">
          {{ title }}
        </p>
        <p v-if="subtitle" class="truncate text-xs text-muted">
          {{ subtitle }}
        </p>
        <p v-if="description" class="mt-1.5 text-sm text-toned">
          {{ description }}
        </p>
      </div>
    </div>
  </ULink>
</template>
