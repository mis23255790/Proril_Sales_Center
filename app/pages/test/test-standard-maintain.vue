<script setup lang="ts">
import type { ApiResponse, DTestStandard } from '~/types/test'

const { apiFetch } = useApi()
const toast = useToast()
const { testTypeOptions, testPlaceOptions, phaseOptions, frequencyOptions } = useTestEnums()

const searchName = ref('')
const testNameOptions = ref<string[]>([])
const searching = ref(false)
const saving = ref(false)
const deleting = ref(false)
const found = ref(false)

const isFunctionTest = ref(true)

const form = reactive<DTestStandard>({
  id: 0,
  testNo: '',
  testName: '',
  maxWater: null as any,
  maxLift: null as any,
  maxWatt: null as any,
  maxAmpere: null as any,
  standardWater: null as any,
  standardLift: null as any,
  standardWatt: null as any,
  standardAmpere: null as any,
  testType: 1,
  testPlace: '實驗室',
  phase: '1Ø',
  frequency: '50HZ',
  voltage: '',
  testRule: '',
  passFlag: '0',
  memo: '',
  hasNameplate: 'Y'
})

const resetForm = (name: string) => {
  Object.assign(form, {
    id: 0,
    testNo: '',
    testName: name,
    maxWater: null,
    maxLift: null,
    maxWatt: null,
    maxAmpere: null,
    standardWater: null,
    standardLift: null,
    standardWatt: null,
    standardAmpere: null,
    testType: 1,
    testPlace: '實驗室',
    phase: '1Ø',
    frequency: '50HZ',
    voltage: '',
    testRule: '',
    passFlag: '0',
    memo: '',
    hasNameplate: 'Y'
  })
  isFunctionTest.value = true
  found.value = false
}

const fetchTestNameOptions = async () => {
  try {
    const res = await apiFetch<ApiResponse<string[]>>('/TestApi/GetTestStandardList')
    testNameOptions.value = res?.body ?? []
  } catch {
    testNameOptions.value = []
  }
}

onMounted(fetchTestNameOptions)

const search = async () => {
  if (!searchName.value.trim()) return
  searching.value = true
  try {
    const res = await apiFetch<ApiResponse<DTestStandard>>('/TestApi/GetTestPlan', {
      params: { input: searchName.value.trim(), test_rule: '' }
    })
    if (res?.isSuccess && res.body?.testNo) {
      Object.assign(form, res.body)
      isFunctionTest.value = form.passFlag === '0'
      found.value = true
      toast.add({ title: '已載入現有測試標準', color: 'success' })
    } else {
      resetForm(searchName.value.trim())
      toast.add({ title: '查無該計畫，請直接輸入資料並儲存', color: 'info' })
    }
  } finally {
    searching.value = false
  }
}

watch(isFunctionTest, (val) => {
  form.passFlag = val ? '0' : 'Y'
})

const save = async () => {
  if (!form.testName.trim()) {
    toast.add({ title: '請輸入測試標準名稱', color: 'warning' })
    return
  }
  if (isFunctionTest.value && (!form.testPlace || !form.phase || !form.frequency || !form.testRule)) {
    toast.add({ title: '請完整填寫檢驗方式/測試地點/相數/頻率/測試規則', color: 'warning' })
    return
  }
  saving.value = true
  try {
    const ok = await apiFetch<boolean>('/TestApi/SaveTestPlan', { params: form })
    if (ok) {
      toast.add({ title: '儲存成功', color: 'success' })
      await search()
    } else {
      toast.add({ title: '儲存失敗', color: 'error' })
    }
  } finally {
    saving.value = false
  }
}

const remove = async () => {
  if (!form.testNo) return
  deleting.value = true
  try {
    const res = await apiFetch<ApiResponse<any>>('/TestApi/DeleteTestPlan', { params: { testNo: form.testNo } })
    if (res?.isSuccess) {
      toast.add({ title: '已刪除', color: 'success' })
      resetForm('')
      searchName.value = ''
    } else {
      toast.add({ title: '刪除失敗', description: res?.message ?? '', color: 'error' })
    }
  } finally {
    deleting.value = false
  }
}
</script>

<template>
  <div>
    <UBreadcrumb :items="[{ label: '首頁', to: '/', icon: 'i-lucide-house' }, { label: '測試系統', icon: 'i-lucide-flask-conical' }, { label: '資料管理' }, { label: '測試標準維護' }]" class="mb-4" />

    <h1 class="mb-4 text-2xl font-bold text-highlighted">
      測試標準維護
    </h1>

    <UAlert
      color="warning"
      variant="subtle"
      class="mb-4"
      title="欄位限制"
      description="名稱下拉選單資料來自後端新端點 TestApi/GetTestStandardList；查詢仍須輸入完整名稱，測試規則請直接輸入代碼。"
    />

    <UCard class="mb-4">
      <UFormField label="測試標準名稱" description="可從下拉選單挑選既有名稱，或直接輸入完整名稱後查詢；查無資料可直接建立新標準">
        <div class="flex gap-2">
          <UInputMenu
            v-model="searchName"
            :items="testNameOptions"
            mode="autocomplete"
            open-on-click
            open-on-focus
            class="max-w-md flex-1"
            placeholder="請輸入或選擇測試標準名稱"
            @keyup.enter="search"
          />
          <UButton icon="i-lucide-search" :loading="searching" @click="search">
            查詢
          </UButton>
        </div>
      </UFormField>
    </UCard>

    <UCard>
      <div class="mb-4 flex items-center justify-between">
        <USwitch v-model="isFunctionTest" label="設定揚程水量參數（一般功能測試）" />
        <div class="flex gap-2">
          <UButton v-if="found" color="error" variant="outline" :loading="deleting" @click="remove">
            刪除
          </UButton>
          <UButton :loading="saving" @click="save">
            儲存
          </UButton>
        </div>
      </div>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <UFormField v-if="!isFunctionTest" label="測試是否合格">
          <USelectMenu v-model="form.passFlag" value-key="value" :items="[{ label: '合格', value: 'Y' }, { label: '不合格', value: 'N' }]" class="w-full" />
        </UFormField>
        <UFormField label="有銘牌">
          <USelectMenu v-model="form.hasNameplate" value-key="value" :items="[{ label: '有', value: 'Y' }, { label: '無', value: 'N' }]" class="w-full" />
        </UFormField>
      </div>

      <template v-if="isFunctionTest">
        <USeparator class="my-4" />
        <div class="grid grid-cols-2 gap-4 sm:grid-cols-4">
          <UFormField label="最大水量"><UInput v-model.number="form.maxWater" type="number" /></UFormField>
          <UFormField label="最大揚程"><UInput v-model.number="form.maxLift" type="number" /></UFormField>
          <UFormField label="最大瓦特"><UInput v-model.number="form.maxWatt" type="number" /></UFormField>
          <UFormField label="最大安培"><UInput v-model.number="form.maxAmpere" type="number" /></UFormField>
          <UFormField label="標準水量"><UInput v-model.number="form.standardWater" type="number" /></UFormField>
          <UFormField label="標準揚程"><UInput v-model.number="form.standardLift" type="number" /></UFormField>
          <UFormField label="標準瓦特"><UInput v-model.number="form.standardWatt" type="number" /></UFormField>
          <UFormField label="標準安培"><UInput v-model.number="form.standardAmpere" type="number" /></UFormField>
        </div>
        <div class="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-3">
          <UFormField label="檢驗方式">
            <USelectMenu v-model="form.testType" value-key="value" :items="testTypeOptions" class="w-full" />
          </UFormField>
          <UFormField label="測試地點">
            <USelectMenu v-model="form.testPlace" value-key="value" :items="testPlaceOptions" class="w-full" />
          </UFormField>
          <UFormField label="相數">
            <USelectMenu v-model="form.phase" value-key="value" :items="phaseOptions" class="w-full" />
          </UFormField>
          <UFormField label="頻率">
            <USelectMenu v-model="form.frequency" value-key="value" :items="frequencyOptions" class="w-full" />
          </UFormField>
          <UFormField label="電壓">
            <UInput v-model="form.voltage" />
          </UFormField>
          <UFormField label="測試規則代碼">
            <UInput v-model="form.testRule" placeholder="RuleKey" />
          </UFormField>
        </div>
      </template>

      <USeparator class="my-4" />
      <UFormField label="備註">
        <UTextarea v-model="form.memo" :rows="2" autoresize class="w-full" />
      </UFormField>
    </UCard>
  </div>
</template>
