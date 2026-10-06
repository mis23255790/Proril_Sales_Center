<script setup lang="ts">
/**
 * 訂單資料檢核的燈號：通過＝綠燈、NG＝紅燈，圖檔照搬 1.0（wwwroot/images/circle-*.png）。
 * 特規Pass 與未檢核 1.0 沒有對應燈號，沿用圖示＋文字。
 */
import type { ChkValue } from '~/types/orderInfoVerify'
import { chkBadgeLabel } from '~/utils/orderInfoVerify'

withDefaults(defineProps<{
  chk: ChkValue
  /** 燈號旁要不要顯示文字；預設不顯示，滑鼠移上去看 title。 */
  showLabel?: boolean
}>(), { showLabel: false })
</script>

<template>
  <span class="inline-flex shrink-0 items-center gap-1 text-sm" :title="chkBadgeLabel(chk)">
    <img v-if="chk === 'Y'" src="/images/circle-green.png" alt="通過" class="size-4">
    <img v-else-if="chk === 'N'" src="/images/circle-red.png" alt="NG" class="size-4">
    <UIcon v-else-if="chk === 'P'" name="i-lucide-shield-check" class="size-4 text-warning" />
    <UIcon v-else name="i-lucide-circle-dashed" class="size-4 text-muted" />
    <span
      v-if="showLabel"
      class="font-semibold"
      :class="chk === 'Y' ? 'text-success' : chk === 'N' ? 'text-error' : chk === 'P' ? 'text-warning' : 'text-muted'"
    >{{ chkBadgeLabel(chk) }}</span>
  </span>
</template>
