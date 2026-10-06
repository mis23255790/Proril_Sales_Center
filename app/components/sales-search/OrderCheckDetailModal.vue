<script setup lang="ts">
/**
 * 訂單資料檢核主 modal：開啟時自己重新查詢該筆訂單的最新資料（對照舊版
 * show_order_detail 的做法），顯示表頭唯讀欄位、執行檢核、特規Pass、信用額度、
 * 品號卡片（含「只顯示NG」與分頁）。
 */
import type { ChkValue, CopCheckRule, OrderInfoVerifyRow } from '~/types/orderInfoVerify'
import { feFinChk, poCheckSummary } from '~/utils/orderInfoVerify'

const props = defineProps<{
  orderKey: { copSource: string, orderType: string, orderNo: string, customerNo: string } | null
  showAmount: boolean
  conditionLoading: boolean
  conditionRows: CopCheckRule[]
}>()

const emit = defineEmits<{ checked: [] }>()

const open = defineModel<boolean>('open', { default: false })
/**
 * 「檢核條件」modal 巢狀開在這個 modal 裡面（見 template 最後），才會疊在最上層；
 * 原本是頁面層的兄弟 modal，從這裡開會被壓在底下。
 */
const showConditionModal = ref(false)

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

/** 金額／信用額度 group 的底色：NG 淡紅、特規Pass 淡黃，色碼同主表格（1.0 bgcolor_*）。 */
const chkGroupBg = (chk: ChkValue) => (chk === 'N' ? 'bg-[#f8ccc8]' : chk === 'P' ? 'bg-[#fceec9]' : '')

const customAmt = ref('')
const paidCheck = ref(false)
const passMemoAmt = ref('')
const passMemoCredit = ref('')

const showNgOnly = ref(false)
const page = ref(1)
const pageSize = 6

const filteredRows = computed(() =>
  // 看明細檢核結果 COP_PoDetailCheck.FinChk（vPoDetail.finFlag 是 ERP 結案碼，不是檢核結果）
  showNgOnly.value ? rows.value.filter(r => r.copPoDetailCheck?.finChk !== 'Y') : rows.value)

const pagedRows = computed(() => {
  const start = (page.value - 1) * pageSize
  return filteredRows.value.slice(start, start + pageSize)
})

watch(filteredRows, () => {
  page.value = 1
})

/** COP_PassCheck 裡指定項目最新一筆的特規原因；後端已依 Sno 由新到舊排序。 */
const latestPassMemo = (items: string[]) =>
  header.value?.copPassChecks?.find(p => items.includes((p.passItems ?? '').trim()))?.passMemo ?? ''

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
    // 回填最新一筆特規原因（對照 1.0 updatePassMemo），套用後重新載入才看得到剛寫入的內容
    passMemoAmt.value = latestPassMemo(['CustSumAmtChk', 'CustAmtZeroChk'])
    passMemoCredit.value = latestPassMemo(['AvailableChk'])
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
  <UModal v-model:open="open" title="訂單資料檢核" :ui="{ content: 'w-[calc(100vw-2rem)] max-w-7xl' }">
    <template #body>
      <div v-if="header" class="flex flex-col gap-4">
        <!-- 表頭 -->
        <div class="rounded-lg border border-default bg-elevated/40 p-4">
          <div class="mb-3 flex items-center justify-between gap-2">
            <p class="text-sm font-semibold text-highlighted">
              {{ header.copSource }} {{ header.單別名稱 }} {{ header.單別 }}-{{ header.單號 }}
            </p>
            <div class="flex items-center gap-3">
              <!-- 狀態做成「標籤 + 圖示文字」，不用徽章，避免跟旁邊的檢核按鈕長得像而誤按 -->
              <span class="flex items-center gap-1 text-sm">
                <span class="text-muted">檢核結果：</span>
                <CheckLight :chk="finChk" />
              </span>
              <UButton size="sm" icon="i-lucide-play" :loading="checking" @click="onCheck">
                執行檢核
              </UButton>
            </div>
          </div>
          <p v-if="summary" class="mb-3 text-xs text-error">
            {{ summary }}
          </p>

          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <UFormField label="訂單日期" size="sm">
              <UInput :model-value="header.訂單日期 ?? ''" readonly variant="subtle" class="w-full" />
            </UFormField>
            <UFormField label="客戶單號" size="sm">
              <UInput :model-value="header.客戶單號 ?? ''" readonly variant="subtle" class="w-full" />
            </UFormField>
            <UFormField label="部門" size="sm">
              <UInput :model-value="`${header.部門代號} ${header.depName ?? ''}`" readonly variant="subtle" class="w-full" />
            </UFormField>
            <UFormField label="客戶" size="sm">
              <UInput :model-value="`${header.客戶代號} ${header.客戶名稱}`" readonly variant="subtle" class="w-full" />
            </UFormField>
            <UFormField label="交易幣別" size="sm">
              <UInput :model-value="header.幣別 ?? ''" readonly variant="subtle" class="w-full" />
            </UFormField>
            <UFormField label="業務人員" size="sm">
              <UInput :model-value="`${header.業務人員 ?? ''} ${header.業務名稱}`" readonly variant="subtle" class="w-full" />
            </UFormField>
            <UFormField label="PackingList備註" size="sm" class="sm:col-span-2">
              <UInput :model-value="header.packinglist備註 ?? ''" readonly variant="subtle" class="w-full" />
            </UFormField>
            <UFormField label="匯率" size="sm">
              <UInput :model-value="header.匯率 ?? undefined" readonly variant="subtle" class="w-full" />
            </UFormField>
            <UFormField label="價格條件" size="sm">
              <UInput :model-value="header.價格條件 ?? ''" readonly variant="subtle" class="w-full" />
            </UFormField>
            <UFormField label="電話 / 傳真" size="sm">
              <UInput :model-value="`${header.telNo ?? ''} / ${header.faxNo ?? ''}`" readonly variant="subtle" class="w-full" />
            </UFormField>
            <UFormField label="交易條件" size="sm">
              <UInput :model-value="`${header.交易條件 ?? ''} ${header.交易條件名稱}`" readonly variant="subtle" class="w-full" />
            </UFormField>
            <UFormField label="付款條件" size="sm">
              <div class="flex items-center gap-2">
                <UInput :model-value="header.付款條件 ?? ''" readonly variant="subtle" class="w-full" />
                <UCheckbox v-model="paidCheck" label="已付款確認" />
              </div>
            </UFormField>
            <UFormField label="送貨地址一" size="sm" class="sm:col-span-2">
              <UInput :model-value="header.送貨地址一 ?? ''" readonly variant="subtle" class="w-full" />
            </UFormField>
            <UFormField label="附件檔案" size="sm">
              <UInput :model-value="header.附件檔案" readonly variant="subtle" class="w-full" />
            </UFormField>
            <UFormField label="送貨地址二" size="sm" class="sm:col-span-2">
              <UInput :model-value="header.送貨地址二 ?? ''" readonly variant="subtle" class="w-full" />
            </UFormField>
            <UFormField label="運輸方式" size="sm">
              <UInput :model-value="header.運輸方式 ?? ''" readonly variant="subtle" class="w-full" />
            </UFormField>
            <UFormField label="流程代號" size="sm">
              <UInput :model-value="header.流程代號 ?? ''" readonly variant="subtle" class="w-full" />
            </UFormField>
            <UFormField label="起始港口" size="sm">
              <UInput :model-value="header.起始港口 ?? ''" readonly variant="subtle" class="w-full" />
            </UFormField>
            <UFormField label="目的港口" size="sm">
              <UInput :model-value="header.目的港口 ?? ''" readonly variant="subtle" class="w-full" />
            </UFormField>
          </div>
        </div>

        <!--
          訂單金額／客戶金額、信用額度／信用餘額是檢核重點，比照 1.0 排成一行直接顯示；
          特規原因不常用，收在「特規Pass」按鈕的下拉視窗裡（1.0 是收在 accordion 內）。
        -->
        <div class="flex flex-wrap items-stretch gap-3">
          <!-- 訂單金額 group：底色跟著 CustSumAmtChk（1.0 的 custsum-chk 也是整組上色） -->
          <div class="flex flex-wrap items-center gap-2 rounded-lg border border-default px-3 py-2" :class="chkGroupBg(copPoCheck?.custSumAmtChk)">
            <span class="text-sm text-muted">訂單金額</span>
            <span class="min-w-24 text-right font-semibold tabular-nums text-highlighted">
              {{ formatAmount(header.訂單金額) || '0' }}
            </span>
            <span class="text-sm text-muted after:ms-0.5 after:text-error after:content-['*']">客戶金額</span>
            <UInput v-model="customAmt" type="number" placeholder="輸入客戶金額" size="sm" class="w-36" />
            <CheckLight v-if="copPoCheck?.custSumAmtChk" :chk="copPoCheck.custSumAmtChk" />
            <span v-if="copPoCheck?.custSumAmtChk === 'P' && passMemoAmt" class="max-w-48 truncate text-xs text-muted" :title="passMemoAmt">
              原因：{{ passMemoAmt }}
            </span>
            <!-- 還沒執行檢核（沒有檢核單號）或檢核通過（Y）都不顯示特規Pass，比照 1.0 收起特規區 -->
            <UPopover v-if="copPoCheck?.orderChkNo && (copPoCheck.custSumAmtChk !== 'Y' || copPoCheck.custAmtZeroChk !== 'Y')">
              <UButton size="xs" color="warning" variant="ghost" trailing-icon="i-lucide-chevron-down">
                特規Pass
              </UButton>
              <template #content>
                <div class="flex w-80 items-center gap-2 p-3">
                  <UInput v-model="passMemoAmt" placeholder="特規原因" size="sm" class="min-w-0 flex-1" />
                  <UButton
                    size="sm" color="warning" :loading="applyingPass === 'CustSumAmtChk'"
                    @click="onApplyPass('CustSumAmtChk', passMemoAmt)"
                  >
                    套用
                  </UButton>
                </div>
              </template>
            </UPopover>
          </div>

          <!-- 信用額度 group：底色跟著 AvailableChk -->
          <div class="flex flex-wrap items-center gap-2 rounded-lg border border-default px-3 py-2" :class="chkGroupBg(copPoCheck?.availableChk)">
            <span class="text-sm text-muted">信用額度</span>
            <span class="min-w-24 text-right font-semibold tabular-nums text-highlighted">
              {{ formatAmount(credit?.信用可超出額) || '0' }}
            </span>
            <span class="text-sm text-muted">信用餘額</span>
            <span
              class="min-w-24 text-right font-semibold tabular-nums"
              :class="(credit?.信用餘額 ?? 0) < 0 ? 'text-error' : 'text-highlighted'"
            >
              {{ formatAmount(credit?.信用餘額) || '0' }}
            </span>
            <CheckLight v-if="copPoCheck?.availableChk" :chk="copPoCheck.availableChk" />
            <span v-if="copPoCheck?.availableChk === 'P' && passMemoCredit" class="max-w-48 truncate text-xs text-muted" :title="passMemoCredit">
              原因：{{ passMemoCredit }}
            </span>
            <UPopover v-if="copPoCheck?.orderChkNo && copPoCheck.availableChk !== 'Y'">
              <UButton size="xs" color="warning" variant="ghost" trailing-icon="i-lucide-chevron-down">
                特規Pass
              </UButton>
              <template #content>
                <div class="flex w-80 flex-col gap-3 p-3">
                  <div class="flex items-center gap-2">
                    <UInput v-model="passMemoCredit" placeholder="特規原因" size="sm" class="min-w-0 flex-1" />
                    <UButton
                      size="sm" color="warning" :loading="applyingPass === 'AvailableChk'"
                      @click="onApplyPass('AvailableChk', passMemoCredit)"
                    >
                      套用
                    </UButton>
                  </div>
                  <!-- 信用額度計算明細，1.0 也放在同一個收合區 -->
                  <div v-if="credit" class="max-h-64 overflow-y-auto rounded-lg border border-default text-xs">
                    <table class="w-full">
                      <tbody>
                        <tr v-for="(value, name) in credit" :key="name" class="border-b border-default last:border-0">
                          <td class="p-2 text-muted">
                            {{ name }}
                          </td>
                          <td class="p-2 text-right tabular-nums">
                            {{ formatAmount(value) }}
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </template>
            </UPopover>
          </div>
        </div>

        <!-- 品號卡片 -->
        <div class="flex items-center justify-between">
          <UCheckbox v-model="showNgOnly" label="只顯示NG" />
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
      <div class="flex w-full items-center justify-between gap-2">
        <UButton color="neutral" variant="outline" @click="showConditionModal = true">
          檢核條件
        </UButton>
        <UButton color="neutral" variant="outline" @click="open = false">
          關閉
        </UButton>
      </div>
      <!-- 巢狀 modal 要放在 modal 內容裡（不能放預設 slot，那是觸發元件），才會疊在最上層 -->
      <OrderCheckConditionModal
        v-model:open="showConditionModal"
        :loading="conditionLoading"
        :rows="conditionRows"
      />
    </template>
  </UModal>
</template>
