<script setup lang="ts">
const { modules } = useAppNavigation()
</script>

<template>
  <div>
    <div class="mb-6">
      <h1 class="text-2xl font-bold text-highlighted">
        現場作業系統總覽
      </h1>
      <p class="mt-1 text-sm text-muted">
        點選左側選單或下方模組卡片，快速進入各項作業功能。
      </p>
    </div>

    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
      <ULink
        v-for="mod in modules"
        :key="mod.to"
        :to="mod.groups[0]?.items[0]?.to"
        class="group rounded-lg border border-default bg-default p-4 transition hover:border-primary hover:shadow-md"
      >
        <div class="flex items-center gap-3">
          <div class="flex size-11 shrink-0 items-center justify-center rounded-md bg-primary/10 text-primary transition group-hover:bg-primary group-hover:text-inverted">
            <UIcon :name="mod.icon" class="size-6" />
          </div>
          <div class="min-w-0">
            <p class="truncate font-semibold text-highlighted">
              {{ mod.label }}
            </p>
            <p class="truncate text-xs text-muted">
              {{ mod.labelEn }} · {{ mod.groups.reduce((n, g) => n + g.items.length, 0) }} 項功能
            </p>
          </div>
        </div>
      </ULink>
    </div>
  </div>
</template>
