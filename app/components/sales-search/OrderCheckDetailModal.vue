<script setup lang="ts">
/**
 * 訂單資料檢核主 modal：開啟時自己重新查詢該筆訂單的最新資料（對照舊版
 * show_order_detail 的做法），顯示表頭唯讀欄位、執行檢核、特規Pass、信用額度、
 * 品號卡片（含「只顯示NG」與分頁）。
 */
import type { OrderInfoVerifyRow } from '~/types/orderInfoVerify'
import { chkBadgeColor, chkBadgeLabel, feFinChk, poCheckSummary } from '~/utils/orderInfoVerify'

const props = defineProps<{
  orderKey: { copSource: string, orderType: string, orderNo: string, customerNo: string } | null
  showAmount: boolean
}>()

const emit = defineEmits<{ checked: [] }>()

const open = defineModel<boolean>('open', { default: false })
const showConditionModal = defineModel<boolean>('showCondition', { default: false })

const api = useOrderInfoVerifyApi()
const toast = useToast()

const loading = ref(false)
const checking = ref(false)
const applyingPass = ref<'CustSumAmtChk' | 'AvailableChk' | null>(null)
const rows = ref<OrderInfoVerifyRow[]>([])
const credit = ref<Record<string, number> | null>(null)

const header = computed(() => rows.value[0])
const copPoCheck = computed(() => header.value?.copPoCheck)
const finChk = computed(() => feFinChk(copPoCheck.value))
const summary = computed(() => poCheckSummary(copPoCheck.value))

const customAmt = ref('')
const paidCheck = ref(false)
const passMemoAmt = ref('')
const passMemoCredit = ref('')

const showNgOnly = ref(false)
const page = ref(1)
const pageSize = 6

const filteredRows = computed(() =>
  showNgOnly.value ? rows.value.filter(r => r.vPoDetail.finFlag !== 'Y') : rows.value)

const pagedRows = computed(() => {
  const start = (page.value - 1) * pageSize
  return filteredRows.value.slice(start, start + pageSize)
})

watch(filteredRows, () => { page.value = 1 })

const load = async () => {
  if (!props.orderKey) return
  loading.value = true
  try {
    const [orderRes, creditRes] = await Promise.all([
      api.getPOCheckView({
        copSource: props.orderKey.copSource,
        orderType: props.orderKey.orderType,
        orderNo: props.orderKey.orderNo
      }),
      api.getCredit(props.orderKey.customerNo)
    ])

    rows.value = orderRes?.isSuccess ? (orderRes.body ?? []) : []
    credit.value = (creditRes?.isSuccess ? creditRes.body?.[0] : null) as Record<string, number> | null

    customAmt.value = copPoCheck.value?.custAmt != null ? String(copPoCheck.value.custAmt) : ''
    paidCheck.value = copPoCheck.value?.paidChk === 'Y'
    passMemoAmt.value = ''
    passMemoCredit.value = ''
  } catch (err) {
    console.log('OrderCheckDetailModal load failed -->', err)
    rows.value = []
    toast.add({ title: '讀取訂單檢核資料失敗', color: 'error' })
  } finally {
    loading.value = false
  }
}

watch(() => [props.orderKey, open.value], ([, isOpen]) => {
  if (isOpen && props.orderKey) load()
}, { immediate: true })

const onCheck = async () => {
  if (!header.value) return
  if (!customAmt.value) {
    toast.add({ title: '請輸入客戶金額', color: 'warning' })
    return
  }

  checking.value = true
  try {
    const res = await api.checkCOPOrderInfo({
      copSource: header.value.copSource,
      poNo: `${header.value.單別}-${header.value.單號}`,
      custAmt: Number(customAmt.value),
      paidCheck: paidCheck.value ? 'Y' : 'N',
      creditAvalAmt: credit.value?.信用可超出額 ?? 0
    })
    if (!res?.isSuccess) {
      toast.add({ title: '執行檢核失敗', description: res?.message ?? '', color: 'error' })
      return
    }
    toast.add({ title: '檢核完成', color: 'success' })
    await load()
    emit('checked')
  } catch (err) {
    console.log('onCheck failed -->', err)
    toast.add({ title: '執行檢核失敗', color: 'error' })
  } finally {
    checking.value = false
  }
}

const onApplyPass = async (passItem: 'CustSumAmtChk' | 'AvailableChk', memo: string) => {
  if (!copPoCheck.value?.orderChkNo) {
    toast.add({ title: '請先執行檢核，才能套用特規Pass', color: 'warning' })
    return
  }

  applyingPass.value = passItem
  try {
    const res = await api.copOrderInfoPassCheck({
      checkNo: copPoCheck.value.orderChkNo,
      passItem,
      passMemo: memo
    })
    if (!res?.isSuccess) {
      toast.add({ title: '特規Pass失敗', description: res?.message ?? '', color: 'error' })
      return
    }
    toast.add({ title: '特規Pass完成', color: 'success' })
    await load()
    emit('checked')
  } catch (err) {
    console.log('onApplyPass failed -->', err)
    toast.add({ title: '特規Pass失敗', color: 'error' })
  } finally {
    applyingPass.value = null
  }
}
</script>

<template>
  <UModal v-model:open="open" title="訂單資料檢核" :ui="{ content: 'max-w-5xl' }">
    <template #body>
      <div v-if="header" class="flex flex-col gap-4">
        <!-- 表頭 -->
        <div class="rounded-lg border border-default bg-elevated/40 p-4">
          <div class="mb-3 flex items-center justify-between gap-2">
            <p class="text-sm font-semibold text-highlighted">
              {{ header.copSource }} {{ header.單別名稱 }} {{ header.單別 }}-{{ header.單號 }}
            </p>
            <div class="flex items-center gap-2">
              <UBadge :color="chkBadgeColor(finChk)" variant="subtle">
                {{ chkBadgeLabel(finChk) }}
              </UBadge>
              <UButton size="sm" :loading="checking" @click="onCheck">
                檢核
              </UButton>
            </div>
          </div>
          <p v-if="summary" class="mb-3 text-xs text-error">
            {{ summary }}
          </p>

          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
            <UFormField label="訂單日期" size="sm">
              <UInput :model-value="header.訂單日期 ?? ''" readonly class="w-full" />
            </UFormField>
            <UFormField label="客戶單號" size="sm">
              <UInput :model-value="header.客戶單號 ?? ''" readonly class="w-full" />
            </UFormField>
            <UFormField label="部門" size="sm">
              <UInput :model-value="`${header.部門代號} ${header.depName ?? ''}`" readonly class="w-full" />
            </UFormField>
            <UFormField label="客戶" size="sm">
              <UInput :model-value="`${header.客戶代號} ${header.客戶名稱}`" readonly class="w-full" />
            </UFormField>
            <UFormField label="交易幣別" size="sm">
              <UInput :model-value="header.幣別 ?? ''" readonly class="w-full" />
            </UFormField>
            <UFormField label="業務人員" size="sm">
              <UInput :model-value="`${header.業務人員 ?? ''} ${header.業務名稱}`" readonly class="w-full" />
            </UFormField>
            <UFormField label="PackingList備註" size="sm" class="sm:col-span-2">
              <UInput :model-value="header.packinglist備註 ?? ''" readonly class="w-full" />
            </UFormField>
            <UFormField label="匯率" size="sm">
              <UInput :model-value="header.匯率 ?? undefined" readonly class="w-full" />
            </UFormField>
            <UFormField label="價格條件" size="sm">
              <UInput :model-value="header.價格條件 ?? ''" readonly class="w-full" />
            </UFormField>
            <UFormField label="電話 / 傳真" size="sm">
              <UInput :model-value="`${header.telNo ?? ''} / ${header.faxNo ?? ''}`" readonly class="w-full" />
            </UFormField>
            <UFormField label="交易條件" size="sm">
              <UInput :model-value="`${header.交易條件 ?? ''} ${header.交易條件名稱}`" readonly class="w-full" />
            </UFormField>
            <UFormField label="付款條件" size="sm">
              <div class="flex items-center gap-2">
                <UInput :model-value="header.付款條件 ?? ''" readonly class="w-full" />
                <UCheckbox v-model="paidCheck" label="已付款確認" />
              </div>
            </UFormField>
            <UFormField label="送貨地址一" size="sm" class="sm:col-span-2">
              <UInput :model-value="header.送貨地址一 ?? ''" readonly class="w-full" />
            </UFormField>
            <UFormField label="附件檔案" size="sm">
              <UInput :model-value="header.附件檔案" readonly class="w-full" />
            </UFormField>
            <UFormField label="送貨地址二" size="sm" class="sm:col-span-2">
              <UInput :model-value="header.送貨地址二 ?? ''" readonly class="w-full" />
            </UFormField>
            <UFormField label="運輸方式" size="sm">
              <UInput :model-value="header.運輸方式 ?? ''" readonly class="w-full" />
            </UFormField>
            <UFormField label="流程代號" size="sm">
              <UInput :model-value="header.流程代號 ?? ''" readonly class="w-full" />
            </UFormField>
            <UFormField label="起始港口" size="sm">
              <UInput :model-value="header.起始港口 ?? ''" readonly class="w-full" />
            </UFormField>
            <UFormField label="目的港口" size="sm">
              <UInput :model-value="header.目的港口 ?? ''" readonly class="w-full" />
            </UFormField>
          </div>
        </div>

        <!-- 訂單金額 / 信用額度 -->
        <UAccordion
          :items="[
            { label: '訂單金額', slot: 'amount' },
            { label: '信用額度', slot: 'credit' }
          ]"
        >
          <template #amount>
            <div class="flex flex-col gap-2 p-2">
              <div class="flex flex-wrap items-center gap-2">
                <span class="text-sm text-muted">訂單金額</span>
                <UInput :model-value="formatAmount(header.訂單金額)" readonly class="w-32" />
                <span class="text-sm text-muted">客戶金額</span>
                <UInput v-model="customAmt" type="number" placeholder="輸入客戶金額" class="w-40" />
              </div>
              <div class="flex flex-wrap items-center gap-2">
                <span class="text-sm text-muted">特規原因</span>
                <UInput v-model="passMemoAmt" class="max-w-md flex-1" />
                <UButton
                  size="sm" color="warning" variant="subtle" :loading="applyingPass === 'CustSumAmtChk'"
                  @click="onApplyPass('CustSumAmtChk', passMemoAmt)"
                >
                  特規Pass
                </UButton>
              </div>
            </div>
          </template>

          <template #credit>
            <div class="flex flex-col gap-2 p-2">
              <div class="flex flex-wrap items-center gap-2">
                <span class="text-sm text-muted">信用額度</span>
                <UInput :model-value="formatAmount(credit?.信用可超出額)" readonly class="w-32" />
                <span class="text-sm text-muted">信用餘額</span>
                <UInput :model-value="formatAmount(credit?.信用餘額)" readonly class="w-32" />
              </div>
              <div class="flex flex-wrap items-center gap-2">
                <span class="text-sm text-muted">特規原因</span>
                <UInput v-model="passMemoCredit" class="max-w-md flex-1" />
                <UButton
                  size="sm" color="warning" variant="subtle" :loading="applyingPass === 'AvailableChk'"
                  @click="onApplyPass('AvailableChk', passMemoCredit)"
                >
                  特規Pass
                </UButton>
              </div>
              <div v-if="credit" class="overflow-x-auto rounded-lg border border-default">
                <table class="w-full text-xs">
                  <thead>
                    <tr class="border-b border-default text-left text-muted">
                      <th class="p-2">
                        欄位
                      </th>
                      <th class="p-2">
                        值
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="(value, name) in credit" :key="name" class="border-b border-default last:border-0">
                      <td class="p-2">
                        {{ name }}
                      </td>
                      <td class="p-2">
                        {{ formatAmount(value) }}
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </template>
        </UAccordion>

        <!-- 品號卡片 -->
        <div class="flex items-center justify-between">
          <UCheckbox v-model="showNgOnly" label="只顯示NG" />
          <UButton size="xs" color="neutral" variant="outline" @click="showConditionModal = true">
            檢核條件
          </UButton>
        </div>

        <div v-if="loading" class="py-8 text-center text-sm text-muted">
          載入中…
        </div>
        <div v-else class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <OrderCheckProductCard
            v-for="row in pagedRows"
            :key="row.vPoDetail.序號"
            :detail="row.vPoDetail"
            :check="row.copPoDetailCheck"
            :show-amount="showAmount"
          />
          <p v-if="pagedRows.length === 0" class="col-span-full py-8 text-center text-sm text-muted">
            查無品號明細
          </p>
        </div>

        <div v-if="filteredRows.length > pageSize" class="flex justify-center">
          <UPagination v-model:page="page" :items-per-page="pageSize" :total="filteredRows.length" />
        </div>
      </div>
    </template>

    <template #footer>
      <div class="flex w-full justify-end">
        <UButton color="neutral" variant="outline" @click="open = false">
          關閉
        </UButton>
      </div>
    </template>
  </UModal>
</template>
