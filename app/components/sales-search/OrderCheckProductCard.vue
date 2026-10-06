<script setup lang="ts">
/**
 * 檢核 modal 裡的單一品號卡片。
 *
 * - 右上角燈號看明細檢核結果 COP_PoDetailCheck.FinChk（1.0 也是看 copPoDetailCheck.FinChk）。
 *   vPoDetail.finFlag 是 ERP 結案碼，不是檢核結果，2026-10-06 以前誤用它，結案碼不是 Y 就顯示紅燈。
 * - 欄位直接標色，比照 1.0 get_detail_card 的 text-highlight / text-warning：N = 紅、W = 黃（警告）。
 *   對照關係照抄 1.0（例如 PriceChk、PackListChk 標在「預交日」，關聯單價／MOQ 金額標在「前置單價」）。
 * - 下方再列出 N / W 的項目與規則說明，對照舊版 get_detail_check_str「只列有問題的」邏輯。
 */
import type { ChkValue, CopPoDetailCheck, VPoDetail } from '~/types/orderInfoVerify'

const props = defineProps<{
  detail: VPoDetail
  check?: CopPoDetailCheck | null
  showAmount: boolean
}>()

type CheckField = keyof CopPoDetailCheck

const CHECK_ITEMS: { field: CheckField, label: string, ruleField: CheckField }[] = [
  { field: 'productNoChk', label: '品號', ruleField: 'productNoChkRule' },
  { field: 'qtyChk', label: '數量', ruleField: 'qtyChkRule' },
  { field: 'amtChk', label: '金額', ruleField: 'amtChkRule' },
  { field: 'priceChk', label: '單價', ruleField: 'priceChkRule' },
  { field: 'packListChk', label: 'PackingList', ruleField: 'packListChkRule' },
  { field: 'linkTypeChk', label: '關聯單別', ruleField: 'linkTypeChkRule' },
  { field: 'linkNoChk', label: '關聯單號', ruleField: 'linkNoChkRule' },
  { field: 'linkSnoChk', label: '關聯序號', ruleField: 'linkSnoChkRule' },
  { field: 'linkQtyChk', label: '關聯數量', ruleField: 'linkQtyChkRule' },
  { field: 'linkPriceChk', label: '關聯單價', ruleField: 'linkPriceChkRule' },
  { field: 'linkChk', label: '關聯', ruleField: 'linkChkRule' },
  { field: 'moqamtChk', label: 'MOQ金額', ruleField: 'moqamtChkRule' },
  { field: 'linkMoqamtChk', label: '關聯MOQ金額', ruleField: 'linkMoqamtChkRule' }
]

/** 有問題的項目（N = 錯誤、W = 警告），附規則說明。 */
const issueItems = computed(() =>
  CHECK_ITEMS
    .map(item => ({ ...item, value: props.check?.[item.field] as ChkValue | 'W', rule: props.check?.[item.ruleField] as string | null | undefined }))
    .filter(item => item.value === 'N' || item.value === 'W')
)

const ERROR_CLASS = 'rounded bg-[#f8ccc8] px-1 font-semibold text-error'
const WARNING_CLASS = 'rounded bg-[#fceec9] px-1 font-semibold text-warning'

/** 這幾個檢核欄位裡最嚴重的狀態 → 欄位標色；還沒檢核（沒有明細檢核紀錄）不標。 */
const mark = (...fields: CheckField[]) => {
  if (!props.check) return ''
  const values = fields.map(f => props.check?.[f] as string | null | undefined)
  if (values.includes('N')) return ERROR_CLASS
  if (values.includes('W')) return WARNING_CLASS
  return ''
}

const hasLink = computed(() =>
  !!(props.detail.前置單別?.trim() || props.detail.前置單號?.trim() || props.detail.前置序號?.trim()))
</script>

<template>
  <div class="rounded-lg border border-default p-3">
    <div class="mb-2 flex items-start justify-between gap-2">
      <div>
        <p class="text-sm font-semibold text-highlighted">
          <span :class="mark('productNoChk')">{{ detail.品號 }} {{ detail.品名 }}</span>
        </p>
        <p class="text-xs text-muted">
          {{ detail.規格 }}<span v-if="detail.英文品名"> / {{ detail.英文品名 }}</span>
        </p>
      </div>
      <CheckLight :chk="check?.finChk ?? null" />
    </div>

    <div class="grid grid-cols-2 gap-x-3 gap-y-1 text-xs text-muted sm:grid-cols-4">
      <p>數量：<span :class="mark('qtyChk')">{{ formatAmount(detail.訂單數量) }} {{ detail.單位 }}</span></p>
      <p>預交日：<span :class="mark('priceChk', 'packListChk')">{{ detail.預交日 }}</span></p>
      <template v-if="showAmount">
        <p>幣別：{{ detail.幣別 }}</p>
        <p>單價：<span :class="mark('amtChk')">{{ formatAmount(detail.外幣單價) }}</span></p>
        <p>外幣金額：<span :class="mark('amtChk')">{{ formatAmount(detail.外幣金額) }}</span></p>
        <p>台幣金額：{{ formatAmount(detail.台幣金額) }}</p>
      </template>
      <template v-if="hasLink">
        <p class="col-span-2">
          前置單別-單號：<span :class="mark('linkTypeChk', 'linkChk')">{{ detail.前置單別 }}</span>-<span :class="mark('linkNoChk', 'linkChk')">{{ detail.前置單號 }}</span>
        </p>
        <p>前置序號：<span :class="mark('linkSnoChk')">{{ detail.前置序號 }}</span></p>
        <p>前置數量：<span :class="mark('linkQtyChk')">{{ formatAmount(detail.前置數量) }}</span></p>
        <p v-if="showAmount">
          前置單價：<span :class="mark('linkPriceChk', 'moqamtChk', 'linkMoqamtChk')">{{ formatAmount(detail.前置單價) }}</span>
        </p>
      </template>
    </div>

    <div v-if="issueItems.length > 0" class="mt-2 flex flex-col gap-1 border-t border-default pt-2">
      <div v-for="item in issueItems" :key="item.field" class="flex items-start gap-2 text-xs">
        <UBadge :color="item.value === 'N' ? 'error' : 'warning'" variant="subtle" size="sm">
          {{ item.label }}
        </UBadge>
        <span class="text-muted">{{ item.rule ?? (item.value === 'N' ? '不符規則' : '警告') }}</span>
      </div>
    </div>
  </div>
</template>
