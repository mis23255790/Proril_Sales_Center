import type { CopSalesOrder, CopSalesOrderRow } from '~/types/salesShipping'
import { FOOTER_FLAG, isDetailRow, isSummaryRow, PRODUCT_TYPE } from '~/types/salesShipping'

/** YYYY-MM-DD → YYYYMMDD，SP 吃的是這種緊湊格式（getDateStringCompact）。 */
export const toCompactDate = (value?: string | null) => (value ?? '').replaceAll('-', '')

/**
 * 對應舊畫面的「成品(5開頭) / 零件(x開頭)」勾選框。
 *
 * 都不勾 = A（含 9 開頭等其他品號）、都勾 = a、只勾成品 = 5、只勾零件 = x。
 */
export const getProductType = (show5x: boolean, showX: boolean) => {
  if (!show5x && !showX) return PRODUCT_TYPE.ALL_UNCHECKED
  if (show5x && showX) return PRODUCT_TYPE.ALL_CHECKED
  if (show5x) return PRODUCT_TYPE.FINISHED
  return PRODUCT_TYPE.PART
}

/**
 * 幫每一列補上 showIndex：同一個群組（依 keyFn 判斷）相鄰列共用同一個號碼，
 * 用來做斑馬紋交錯（奇偶 showIndex 換色），對照舊版 bootstrap-table 的
 * product_disp_index / disp_index 邏輯。
 */
const assignShowIndex = (rows: CopSalesOrder[], keyFn: (row: CopSalesOrder) => string): CopSalesOrderRow[] => {
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

const productKey = (row: CopSalesOrder) => row.th004 ?? ''
const soKey = (row: CopSalesOrder) => `${row.th001 ?? ''}-${row.th002 ?? ''}`

/** 品號細項：FooterFlag 非 Y（N + S + T）。groupName=TH004 查出來的結果。 */
export const toProductDetailRows = (rows: CopSalesOrder[]) =>
  assignShowIndex(rows.filter(r => isDetailRow(r.footerFlag)), productKey)

/** 品號統計：FooterFlag 非 N（S + Y + T）。groupName=TH004 查出來的結果。 */
export const toProductGroupRows = (rows: CopSalesOrder[]) =>
  assignShowIndex(rows.filter(r => isSummaryRow(r.footerFlag)), productKey)

/** 銷貨單細項：FooterFlag 非 Y（N + S + T）。groupName=TH001 查出來的結果。 */
export const toSoDetailRows = (rows: CopSalesOrder[]) =>
  assignShowIndex(rows.filter(r => isDetailRow(r.footerFlag)), soKey)

/** 銷貨單統計：FooterFlag 非 N（S + Y + T）。groupName=TH001 查出來的結果。 */
export const toSoGroupRows = (rows: CopSalesOrder[]) =>
  assignShowIndex(rows.filter(r => isSummaryRow(r.footerFlag)), soKey)

/**
 * 頁面上方「總金額NT」：品號查詢結果中，非群組小計列（FooterFlag != Y）的
 * 台幣未稅 + 台幣稅額加總，對照舊版 show_product_2tab 的 sum_notax / sum_tax。
 */
export const sumTotalAmount = (rows: CopSalesOrder[]) =>
  rows
    .filter(r => r.footerFlag !== FOOTER_FLAG.GROUP)
    .reduce((sum, r) => sum + (r.th037 ?? 0) + (r.th038 ?? 0), 0)

/** 千分位數字，金額欄位顯示用（FloatAddThousand）。 */
export const formatAmount = (value?: number | null) => {
  if (value === null || value === undefined || Number.isNaN(value)) return ''
  return value.toLocaleString('zh-TW', { minimumFractionDigits: 0, maximumFractionDigits: 2 })
}
