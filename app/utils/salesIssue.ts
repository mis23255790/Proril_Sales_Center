import type { SalesIssue, SalesIssueRow } from '~/types/salesIssue'
import { PHRASE_TYPE } from '~/types/salesIssue'

/** 分號分隔字串轉陣列，順手去空白與空值。 */
export const splitList = (value?: string | null) =>
  (value ?? '').split(';').map(s => s.trim()).filter(Boolean)

/**
 * 把三串同索引對齊的關鍵字字串拆成 (type, code, name) 陣列。
 *
 * 後端 GetSOPOrder / GetSOPList_Edit 回的 phraseTypeList / phraseCodeList /
 * phraseNameList 是靠**位置**對應的，不是 key-value。任何一串被過濾或排序，
 * 對應關係就整個錯開 —— 所以這裡只 split，不做 filter。
 */
export const parsePhraseTriples = (issue: Pick<SalesIssue, 'phraseTypeList' | 'phraseCodeList' | 'phraseNameList'>) => {
  const types = (issue.phraseTypeList ?? '').split(';')
  const codes = (issue.phraseCodeList ?? '').split(';')
  const names = (issue.phraseNameList ?? '').split(';')

  return types
    .map((type, i) => ({
      phraseType: (type ?? '').trim(),
      phraseCode: (codes[i] ?? '').trim(),
      phraseName: (names[i] ?? '').trim()
    }))
    .filter(p => p.phraseType && p.phraseCode)
}

/** ISO 字串 → YYYY-MM-DD，壞值回空字串（不要讓 Invalid Date 出現在畫面上）。 */
export const toDateString = (value?: string | Date | null) => {
  if (!value) return ''
  const date = value instanceof Date ? value : new Date(value)
  if (Number.isNaN(date.getTime())) return ''
  const yyyy = date.getFullYear()
  const mm = String(date.getMonth() + 1).padStart(2, '0')
  const dd = String(date.getDate()).padStart(2, '0')
  return `${yyyy}-${mm}-${dd}`
}

/** ISO 字串 → YYYY-MM-DD HH:mm。 */
export const toDateTimeString = (value?: string | Date | null) => {
  if (!value) return ''
  const date = value instanceof Date ? value : new Date(value)
  if (Number.isNaN(date.getTime())) return ''
  const hh = String(date.getHours()).padStart(2, '0')
  const mi = String(date.getMinutes()).padStart(2, '0')
  return `${toDateString(date)} ${hh}:${mi}`
}

/**
 * 清掉舊內文裡壞掉的行高。
 *
 * 從 Outlook / Word 貼進舊 Summernote 的內容，`<p>` 與 `<span>` 上常常帶著
 * `style="line-height: 0.3"`（16px 字配 4.8px 行高），行與行會直接疊在一起。
 * 這是 1.0 反覆處理過的老問題（release-note 上有好幾筆行高相關的修正）。
 *
 * inline style 的優先權高於樣式表，所以只能在渲染前把這個宣告拿掉，
 * 讓 `.issue-content` / `.issue-editor-body` 的預設行高生效。
 * **只砍明顯壞掉的值**：使用者用舊編輯器刻意設的 1.0 ~ 1.6 保留不動。
 *
 * 注意：編輯器載入時也會做這件事，所以開啟舊進度並重新儲存，
 * 這則進度的壞行高就會被永久修正掉（只影響有被編輯的那一則）。
 */
export const fixLegacyLineHeight = (root: HTMLElement | null | undefined) => {
  if (!root) return
  try {
    for (const el of Array.from(root.querySelectorAll<HTMLElement>('[style*="line-height"]'))) {
      const raw = el.style.lineHeight
      if (!raw) continue

      const value = Number.parseFloat(raw)
      if (Number.isNaN(value)) continue

      const broken = raw.endsWith('px')
        ? value < 12 // 小於 12px 的行高不可能塞得下 16px 的字
        : value < 1 // 無單位倍率小於 1 一定會疊字
      if (broken) el.style.removeProperty('line-height')
    }
  } catch (err) {
    console.log('fixLegacyLineHeight failed -->', err)
  }
}

/** 議題編號一律 6 碼左補零，後端 transferWpNoToPadding 也是這個規則。 */
export const padWpno = (wpno: string | number) =>
  String(wpno).trim().padStart(6, '0')

/**
 * 列表用的衍生欄位。
 *
 * 客戶別要把「關鍵字裡 type 03 的職能主題」和「CRM 客戶名」合併 ——
 * 舊系統早期用關鍵字記客戶，改成客戶導向後才有 customerName，
 * 兩種資料至今並存，只看一邊會有議題顯示不出客戶。
 */
export const toIssueRow = (issue: SalesIssue): SalesIssueRow => {
  const triples = parsePhraseTriples(issue)
  const customers = triples
    .filter(p => p.phraseType === PHRASE_TYPE.JOB)
    .map(p => p.phraseName)

  if (issue.customerName && !customers.includes(issue.customerName)) {
    customers.push(issue.customerName)
  }

  return {
    ...issue,
    createDate: toDateString(issue.createTime),
    categories: triples.filter(p => p.phraseType === PHRASE_TYPE.CATEGORY).map(p => p.phraseName),
    customers
  }
}
