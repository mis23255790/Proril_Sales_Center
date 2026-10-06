<script setup lang="ts">
/**
 * 有清除按鈕（x）的 UInput。Nuxt UI 的 UInput 沒有內建 clear（只有 USelectMenu/UInputMenu 有）。
 *
 * 用法跟 UInput 一樣（v-model、placeholder、icon、size、class、@keyup.enter…全部原樣傳給 UInput），
 * 有值、而且不是 disabled／readonly 時，右側出現 x，點了清成空字串並把焦點留在輸入框。
 * 日期欄位（type="date"）瀏覽器本身就能清，不用這個。
 */
defineOptions({ inheritAttrs: false })

const model = defineModel<string | number | undefined>()
const attrs = useAttrs()
const input = useTemplateRef('input')

/** `disabled` / `readonly` 寫成無值屬性時 attrs 會是空字串，也要算。 */
const isOn = (v: unknown) => v === true || v === ''

// 後端回來的表單值可能是 null（型別上沒寫），用 != null 一併擋掉 null／undefined
const canClear = computed(() =>
  (model.value as unknown) != null && model.value !== ''
  && !isOn(attrs.disabled) && !isOn(attrs.readonly))

const clear = () => {
  model.value = ''
  ;(input.value as any)?.inputRef?.focus?.()
}
</script>

<template>
  <UInput ref="input" v-model="model" v-bind="$attrs">
    <template v-if="canClear" #trailing>
      <UButton
        color="neutral"
        variant="link"
        size="xs"
        icon="i-lucide-x"
        aria-label="清除"
        tabindex="-1"
        class="-me-1"
        @click="clear"
      />
    </template>
  </UInput>
</template>
