<script setup lang="ts">
export type TestValueKey = 'maxWater' | 'maxLift' | 'maxWatt' | 'maxAmpere' | 'standardWater' | 'standardLift' | 'standardWatt' | 'standardAmpere'
export type TestValues = Record<TestValueKey, number | null>

const FIELDS: { key: TestValueKey, label: string, dir: 'min' | 'max' }[] = [
  { key: 'maxWater', label: '最大水量', dir: 'min' },
  { key: 'maxLift', label: '最大揚程', dir: 'min' },
  { key: 'maxWatt', label: '最大瓦特', dir: 'max' },
  { key: 'maxAmpere', label: '最大安培', dir: 'max' },
  { key: 'standardWater', label: '標準水量', dir: 'min' },
  { key: 'standardLift', label: '標準揚程', dir: 'min' },
  { key: 'standardWatt', label: '標準瓦特', dir: 'max' },
  { key: 'standardAmpere', label: '標準安培', dir: 'max' }
]

const props = defineProps<{
  modelValue: TestValues
  standard: TestValues
  disabled?: boolean
}>()

const emit = defineEmits<{ 'update:modelValue': [TestValues] }>()

const setValue = (key: TestValueKey, value: string | number) => {
  emit('update:modelValue', { ...props.modelValue, [key]: value === '' ? null : Number(value) })
}

const isInvalid = (field: typeof FIELDS[number]) => {
  const value = props.modelValue[field.key]
  const standard = props.standard[field.key]
  if (value == null || standard == null) return false
  return field.dir === 'min' ? value < standard : value > standard
}
</script>

<template>
  <div class="grid grid-cols-2 gap-x-4 gap-y-3 sm:grid-cols-4">
    <UFormField v-for="field in FIELDS" :key="field.key" :label="field.label">
      <UInput
        type="number"
        :model-value="modelValue[field.key] ?? undefined"
        :disabled="disabled"
        :color="isInvalid(field) ? 'error' : undefined"
        @update:model-value="setValue(field.key, $event as any)"
      />
      <p class="mt-1 text-xs text-muted">
        參考: {{ standard[field.key] ?? '-' }}
      </p>
    </UFormField>
  </div>
</template>
