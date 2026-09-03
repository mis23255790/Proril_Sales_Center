import type { UnfinOrder, UnfinOrderRow } from '~/types/salesOrderUnfinish'
import { isUnfinishDetailRow, isUnfinishSummaryRow } from '~/types/salesOrderUnfinish'

/**
 * 幫每一列補上 showIndex：同一個群組（依 keyFn 判斷）相鄰列共用同一個號碼，
 * 用來做斑馬紋交錯，對照舊版 bootstrap-table 的 product_disp_index / disp_index 邏輯。
 */
const assignUnfinishShowIndex = (rows: UnfinOrder[], keyFn: (row: UnfinOrder) => string): UnfinOrderRow[] => {
  let index = 0
  let lastKey: string | null = null
  return rows.map((row) => {
    const key = keyFn(row)
    if (key !== lastKey) {
      lastKey = key
      index += 1
    }
    return { ...row, showIndex: index }
  })
}

const productKey = (row: UnfinOrder) => row.td004 ?? ''
const soKey = (row: UnfinOrder) => `${row.tc001 ?? ''}-${row.tc002 ?? ''}`

/** 品號細項：FooterFlag 非 Y（N + S + T）。groupName=TD004 查出來的結果。 */
export const toUnfinishProductDetailRows = (rows: UnfinOrder[]) =>
  assignUnfinishShowIndex(rows.filter(r => isUnfinishDetailRow(r.footerFlag)), productKey)

/** 品號統計：FooterFlag 非 N（S + Y + T）。groupName=TD004 查出來的結果。 */
export const toUnfinishProductGroupRows = (rows: UnfinOrder[]) =>
  assignUnfinishShowIndex(rows.filter(r => isUnfinishSummaryRow(r.footerFlag)), productKey)

/** 訂單細項：FooterFlag 非 Y（N + S + T）。groupName=TC001 查出來的結果。 */
export const toUnfinishSoDetailRows = (rows: UnfinOrder[]) =>
  assignUnfinishShowIndex(rows.filter(r => isUnfinishDetailRow(r.footerFlag)), soKey)

/** 訂單統計：FooterFlag 非 N（S + Y + T）。groupName=TC001 查出來的結果。 */
export const toUnfinishSoGroupRows = (rows: UnfinOrder[]) =>
  assignUnfinishShowIndex(rows.filter(r => isUnfinishSummaryRow(r.footerFlag)), soKey)

/**
 * 頁面上方「總金額NT」：品號查詢結果中，非群組小計列（FooterFlag != Y）的
 * 台幣金額加總，對照舊版 show_product_2tab 的 sum_notax 累加。
 */
export const sumUnfinishTotalAmount = (rows: UnfinOrder[]) =>
  rows
    .filter(r => r.footerFlag !== 'Y')
    .reduce((sum, r) => sum + (r.ntd ?? 0), 0)
