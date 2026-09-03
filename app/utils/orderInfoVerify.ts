import type { ChkValue, CopPoCheck, OrderInfoVerifyGroup, OrderInfoVerifyRow } from '~/types/orderInfoVerify'

/** 表頭 17 個檢核欄位，用來判斷這張訂單的整體檢核結果。 */
const HEADER_CHK_FIELDS: (keyof CopPoCheck)[] = [
  'depChk', 'depBlankChk', 'packListBlankChk', 'priceBlankChk', 'preDateChk',
  'custAmtZeroChk', 'custSumAmtChk', 'custPochk', 'transChk', 'processCodeChk',
  'tradeChk', 'outPortChk', 'inPortChk', 'upFileChk', 'rateChk', 'paidChk'
]

/**
 * 訂單整體檢核結果：任一 NG→NG，否則任一特規Pass→P，否則 Y，尚未檢核回 null。
 * 對照舊版 get_FEFinCheck_pass_flag / set_FEFinCheck_pass_flag。
 */
export const feFinChk = (check?: CopPoCheck | null): ChkValue => {
  if (!check) return null
  const values = HEADER_CHK_FIELDS.map(f => check[f] as ChkValue)
  if (values.some(v => v === 'N')) return 'N'
  if (values.some(v => v === 'P')) return 'P'
  return 'Y'
}

/** 依 "{copSource}-{單別}-{單號}" 分組成訂單層級的列，供主表格顯示。 */
export const groupOrderInfoVerifyRows = (rows: OrderInfoVerifyRow[]): OrderInfoVerifyGroup[] => {
  const groups = new Map<string, OrderInfoVerifyGroup>()

  rows.forEach((row) => {
    const key = `${row.copSource}-${row.單別}-${row.單號}`
    const existing = groups.get(key)
    if (existing) {
      existing.rows.push(row)
      return
    }

    groups.set(key, {
      key,
      copSource: row.copSource,
      單別名稱: row.單別名稱,
      單別: row.單別,
      單號: row.單號,
      訂單日期: row.訂單日期,
      客戶代號: row.客戶代號,
      客戶名稱: row.客戶名稱,
      部門代號: row.部門代號,
      packinglist備註: row.packinglist備註,
      客戶單號: row.客戶單號,
      訂單金額: row.訂單金額,
      交易條件: row.交易條件,
      交易條件名稱: row.交易條件名稱,
      起始港口: row.起始港口,
      目的港口: row.目的港口,
      運輸方式: row.運輸方式,
      流程代號: row.流程代號,
      業務名稱: row.業務名稱,
      業務人員: row.業務人員,
      confirmFlag: row.confirmFlag,
      copPoCheck: row.copPoCheck,
      rows: [row]
    })
  })

  return [...groups.values()]
}

/** 檢核狀態 → 徽章顏色，主表格與 modal 共用。 */
export const chkBadgeColor = (chk: ChkValue): 'success' | 'warning' | 'error' | 'neutral' => {
  if (chk === 'Y') return 'success'
  if (chk === 'P') return 'warning'
  if (chk === 'N') return 'error'
  return 'neutral'
}

/** 檢核狀態 → 顯示文字。 */
export const chkBadgeLabel = (chk: ChkValue): string => {
  if (chk === 'Y') return '通過'
  if (chk === 'P') return '特規Pass'
  if (chk === 'N') return 'NG'
  return '未檢核'
}

/**
 * 表頭層級 NG 項目的規則說明文字（modal 上方紅字），對照舊版 get_po_check_str。
 * 只列出 NG 的項目，Y/P 不列。
 */
export const poCheckSummary = (check?: CopPoCheck | null): string => {
  if (!check) return ''

  const labeled: { field: keyof CopPoCheck, label: string, ruleField: keyof CopPoCheck }[] = [
    { field: 'depChk', label: '部門', ruleField: 'depChkRule' },
    { field: 'depBlankChk', label: '部門空白', ruleField: 'depBlankChkRule' },
    { field: 'packListBlankChk', label: 'PackingList空白', ruleField: 'packListBlankChkRule' },
    { field: 'priceBlankChk', label: '價格條件空白', ruleField: 'priceBlankChkRule' },
    { field: 'preDateChk', label: '預交日', ruleField: 'preDateChkRule' },
    { field: 'custAmtZeroChk', label: '客戶金額為0', ruleField: 'custAmtZeroChkRule' },
    { field: 'custSumAmtChk', label: '訂單金額', ruleField: 'custSumAmtChkRule' },
    { field: 'custPochk', label: '客戶單號', ruleField: 'custPochkRule' },
    { field: 'transChk', label: '運輸方式', ruleField: 'transChkRule' },
    { field: 'processCodeChk', label: '流程代號', ruleField: 'processCodeChkRule' },
    { field: 'tradeChk', label: '交易條件', ruleField: 'tradeChkRule' },
    { field: 'outPortChk', label: '起始港口', ruleField: 'outPortChkRule' },
    { field: 'inPortChk', label: '目的港口', ruleField: 'inPortChkRule' },
    { field: 'upFileChk', label: '附件檔案', ruleField: 'upFileChkRule' },
    { field: 'rateChk', label: '匯率', ruleField: 'rateChkRule' },
    { field: 'paidChk', label: '付款確認', ruleField: 'paidChkRule' }
  ]

  return labeled
    .filter(item => check[item.field] === 'N')
    .map(item => `${item.label}：${check[item.ruleField] ?? '不符規則'}`)
    .join('；')
}
