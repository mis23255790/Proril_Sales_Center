<script setup lang="ts">
/**
 * 權限樹（1.0 用 fancytree，2.0 自己刻）。
 *
 * 層級依 RBAC_Permission 的 parentKey：模組（MODULE）→ 分組（GROUP）→ 頁面（PAGE）→ 細項（ACTION）。
 *
 * 只有頁面與細項有 checkbox，模組／分組純粹是分類（1.0 也是 `checkbox: false`）。
 * 勾選互相獨立、**不做父子連動**（對應 fancytree 的 `selectMode: 2`）——
 * 「勾了細項就自動開啟所屬頁面與上層」是存檔時才補的，見 app/utils/permissionTree.ts 的
 * collectSelection()。這裡若做連動，反而會在載入既有權限時把沒授權的功能也點亮。
 *
 * 停用節點（node.disabled，自己或祖先 aStatus = 'N'）照樣列出、標「停用」，checkbox disabled，
 * 原本的勾選照樣顯示；子孫也一併是 disabled（後端算的是「連同祖先」的有效狀態）。
 *
 * 元件自己遞迴呼叫自己（Nuxt 的 components 自動匯入支援自我參照）。
 */
import type { PermissionTreeNode } from '~/types/system'

const props = defineProps<{
  nodes: PermissionTreeNode[]
  /** 勾起來的節點 key。由呼叫端持有。 */
  selected: Set<string>
  /** 展開的節點 key。 */
  expanded: Set<string>
  depth?: number
  disabled?: boolean
  /** 父節點已停用：子孫一樣是 disabled，但「停用」標籤只標在最上面那一層，不要整串都標。 */
  parentDisabled?: boolean
}>()

const emit = defineEmits<{
  (e: 'toggle-select' | 'toggle-expand', key: string): void
}>()

const depth = computed(() => props.depth ?? 0)
</script>

<template>
  <ul class="space-y-0.5">
    <li v-for="node in nodes" :key="node.key">
      <div
        class="flex items-center gap-1 rounded py-1 hover:bg-elevated"
        :style="{ paddingLeft: `${depth * 18}px` }"
      >
        <button
          v-if="node.children.length"
          type="button"
          class="flex size-5 shrink-0 items-center justify-center text-muted"
          @click="emit('toggle-expand', node.key)"
        >
          <UIcon
            :name="expanded.has(node.key) ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right'"
            class="size-4"
          />
        </button>
        <span v-else class="size-5 shrink-0" />

        <UCheckbox
          v-if="node.checkable"
          :model-value="selected.has(node.key)"
          :disabled="disabled || node.disabled"
          :label="node.label"
          @update:model-value="emit('toggle-select', node.key)"
        />
        <button
          v-else
          type="button"
          class="text-sm font-medium"
          :class="node.disabled ? 'text-dimmed' : 'text-highlighted'"
          @click="emit('toggle-expand', node.key)"
        >
          {{ node.label }}
        </button>
        <UBadge v-if="node.disabled && !parentDisabled" color="neutral" variant="subtle" size="sm" class="ml-1">
          停用
        </UBadge>
      </div>

      <PermissionTree
        v-if="node.children.length && expanded.has(node.key)"
        :nodes="node.children"
        :selected="selected"
        :expanded="expanded"
        :depth="depth + 1"
        :disabled="disabled"
        :parent-disabled="node.disabled"
        @toggle-select="emit('toggle-select', $event)"
        @toggle-expand="emit('toggle-expand', $event)"
      />
    </li>
  </ul>
</template>
