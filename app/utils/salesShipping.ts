import { PRODUCT_TYPE } from '~/types/salesShipping'

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

// 四個頁籤的 FooterFlag 篩選與「總金額NT」加總已搬到後端
// MixSalesShipApiController.GetSalesOrderPage（後端分頁）。

/** 千分位數字，金額欄位顯示用（FloatAddThousand）。 */
export const formatAmount = (value?: number | null) => {
  if (value === null || value === undefined || Number.isNaN(value)) return ''
  return value.toLocaleString('zh-TW', { minimumFractionDigits: 0, maximumFractionDigits: 2 })
}
