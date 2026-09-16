import type {
  CustomerUnfinOrderRow,
  SalesTotalRow,
  SalesYearRow,
  UnfinOrderSummaryRow
} from '~/types/customerRelated'

/**
 * 客戶相關資訊頁的兩段彙總邏輯。後端回的是原始明細（對齊 1.0 的端點形狀），
 * 分群與統計都在前端做——這兩支就是 1.0 customer-related.js 裡
 * showSalesOrder() / showSalesTotal() 那兩段的搬移。
 */

/** 詢問單，不是真的訂單，訂單頁籤要整批濾掉（1.0 2025-05-06 加的）。 */
const INQUIRY_ORDER_TYPE = '2700'

/**
 * 未完成訂單：逐筆品項 → 依「單別+單號」彙總成一列。
 *
 * 成品（品號開頭 5）與零件（品號開頭 x）的數量金額分兩組統計，其餘品號不計入金額，
 * 但那張訂單本身仍然會出現在清單裡。金額是原幣金額 td012 乘上匯率 tc009（換算台幣）。
 *
 * 品號開頭的 'x' **只比對小寫**，跟 1.0 以及 V_SalesTotal 的 `in ('5','x')` 一致
 * （資料庫定序是 BIN，本來就區分大小寫）。
 *
 * 與 1.0 的差異：1.0 只在群組第一筆是 5 或 x 開頭時才初始化那幾個數字欄位，
 * 都不是的話整列的數量金額是 undefined，畫面會算出 $NaN。這裡一律從 0 起算。
 */
export const toUnfinOrderSummary = (rows: CustomerUnfinOrderRow[]): UnfinOrderSummaryRow[] => {
  const byOrder = new Map<string, UnfinOrderSummaryRow>()

  for (const row of rows) {
    if ((row.tc001 ?? '').trim() === INQUIRY_ORDER_TYPE) continue

    const key = `${(row.tc001 ?? '').trim()}-${(row.tc002 ?? '').trim()}`
    let summary = byOrder.get(key)
    if (!summary) {
      summary = {
        copSource: row.copSource,
        tc001: row.tc001,
        tc002: row.tc002,
        tc003: row.tc003,
        td013: row.td013,
        qty05: 0,
        amt05: 0,
        qty0x: 0,
        amt0x: 0,
        qty0a: 0,
        amt0a: 0
      }
      byOrder.set(key, summary)
    }

    const productNo = row.td004 ?? ''
    const qty = row.td008 ?? 0
    const amount = (row.tc009 ?? 0) * (row.td012 ?? 0)

    if (productNo.startsWith('5')) {
      summary.qty05 += qty
      summary.amt05 += amount
    } else if (productNo.startsWith('x')) {
      summary.qty0x += qty
      summary.amt0x += amount
    } else {
      continue
    }

    summary.qty0a += qty
    summary.amt0a += amount
  }

  return [...byOrder.values()]
}

/**
 * 年／月銷售統計：V_SalesTotal 的混合列 → 每年一列、外加一列總計。
 *
 * 輸入的 `ym` 長度 4 是年度總計（直接當該年的合計）、長度 6 是該年某月。
 *
 * 即使完全沒有資料，也一定會有「今年、去年、前年」三列（1.0 的行為，
 * 讓畫面至少看得出這個客戶近三年沒有銷售，而不是一片空白）；資料裡出現的其他年份
 * 接在後面。最後一列是總計，**只加總各月的數字、不加年度總計列**，
 * 避免同一筆金額被算兩次。
 */
export const toSalesYearRows = (rows: SalesTotalRow[]): SalesYearRow[] => {
  const emptyMonths = () => Array.from({ length: 12 }, () => ({ qty: null as number | null, amt: null as number | null }))

  const thisYear = new Date().getFullYear()
  const years = new Map<string, SalesYearRow>()
  for (const year of [thisYear, thisYear - 1, thisYear - 2]) {
    years.set(String(year), { year: String(year), months: emptyMonths(), sumQty: null, sumAmt: null, isTotal: false })
  }

  const total: SalesYearRow = { year: 'Total', months: emptyMonths(), sumQty: 0, sumAmt: 0, isTotal: true }

  for (const row of rows) {
    const ym = (row.ym ?? '').trim()
    if (ym.length < 4) continue

    const year = ym.slice(0, 4)
    let target = years.get(year)
    if (!target) {
      target = { year, months: emptyMonths(), sumQty: null, sumAmt: null, isTotal: false }
      years.set(year, target)
    }

    const qty = row.totalQty ?? 0
    const amt = row.totalAmt ?? 0

    if (ym.length <= 4) {
      target.sumQty = qty
      target.sumAmt = amt
      continue
    }

    const monthIndex = Number(ym.slice(4, 6)) - 1
    if (monthIndex < 0 || monthIndex > 11) continue

    target.months[monthIndex] = { qty, amt }
    total.months[monthIndex] = {
      qty: (total.months[monthIndex]?.qty ?? 0) + qty,
      amt: (total.months[monthIndex]?.amt ?? 0) + amt
    }
    total.sumQty = (total.sumQty ?? 0) + qty
    total.sumAmt = (total.sumAmt ?? 0) + amt
  }

  return [...years.values(), total]
}

/**
 * 銷售頁籤點某個月 → 跳銷貨檢索時要帶的日期區間。
 * `month` 傳 null 代表整年（1.0 的 month = -1）。
 */
export const salesMonthRange = (year: string, month: number | null) => {
  const y = Number(year)
  const start = month === null ? new Date(y, 0, 1) : new Date(y, month - 1, 1)
  const end = month === null ? new Date(y, 11, 31) : new Date(y, month, 0)
  const pad = (n: number) => String(n).padStart(2, '0')
  const fmt = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
  return { startDate: fmt(start), endDate: fmt(end) }
}
