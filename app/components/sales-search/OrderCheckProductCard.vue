<script setup lang="ts">
/**
 * 檢核 modal 裡的單一品號卡片。只列出 NG 的檢核項目 + 規則說明，Y 的不特別列出，
 * 對照舊版 get_detail_check_str/get_check_res_str「只列有問題的」邏輯。
 */
import type { CopPoDetailCheck, VPoDetail } from '~/types/orderInfoVerify'
import { chkBadgeColor } from '~/utils/orderInfoVerify'

const props = defineProps<{
  detail: VPoDetail
  check?: CopPoDetailCheck | null
  showAmount: boolean
}>()

const NG_ITEMS: { field: keyof CopPoDetailCheck, label: string, ruleField: keyof CopPoDetailCheck }[] = [
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

const ngItems = computed(() =>
  NG_ITEMS
    .filter(item => props.check?.[item.field] === 'N')
    .map(item => ({ ...item, rule: props.check?.[item.ruleField] as string | null | undefined }))
)
</script>

<template>
  <div class="rounded-lg border border-default p-3">
    <div class="mb-2 flex items-start justify-between gap-2">
      <div>
        <p class="text-sm font-semibold text-highlighted">
          {{ detail.品號 }} {{ detail.品名 }}
        </p>
        <p class="text-xs text-muted">
          {{ detail.規格 }}<span v-if="detail.英文品名"> / {{ detail.英文品名 }}</span>
        </p>
      </div>
      <UBadge :color="chkBadgeColor(detail.finFlag)" variant="subtle" size="sm">
        {{ detail.finFlag ?? '未檢核' }}
      </UBadge>
    </div>

    <div class="grid grid-cols-2 gap-x-3 gap-y-1 text-xs text-muted sm:grid-cols-4">
      <p>數量：{{ formatAmount(detail.訂單數量) }} {{ detail.單位 }}</p>
      <p>預交日：{{ detail.預交日 }}</p>
      <template v-if="showAmount">
        <p>幣別：{{ detail.幣別 }}</p>
        <p>單價：{{ formatAmount(detail.外幣單價) }}</p>
        <p>外幣金額：{{ formatAmount(detail.外幣金額) }}</p>
        <p>台幣金額：{{ formatAmount(detail.台幣金額) }}</p>
      </template>
    </div>

    <div v-if="ngItems.length > 0" class="mt-2 flex flex-col gap-1 border-t border-default pt-2">
      <div v-for="item in ngItems" :key="item.field" class="flex items-start gap-2 text-xs">
        <UBadge color="error" variant="subtle" size="sm">
          {{ item.label }}
        </UBadge>
        <span class="text-muted">{{ item.rule ?? '不符規則' }}</span>
      </div>
    </div>
  </div>
</template>
