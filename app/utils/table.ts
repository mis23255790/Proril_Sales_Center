/**
 * 可點擊列（整列進入編輯／明細畫面）的 UTable `tr` 樣式。
 * 規範：只要 table 有對應的編輯畫面，就掛這組 class + `@select`，
 * hover 時整列變色、文字加底線、游標變手指，點任一處都進編輯畫面。
 * 列內的按鈕／連結不跟著加底線（避免 outline 按鈕看起來像壞掉）。
 */
export const clickableRowTr
  = 'cursor-pointer hover:bg-elevated/50 hover:[&_td]:underline hover:[&_td_button]:no-underline hover:[&_td_a]:no-underline'

/**
 * 分頁列的「每頁筆數」選項用的「全部」哨兵值。
 * 刻意用一個超大數字而不是 0 或 -1：不管是 tanstack 內建的 client-side
 * getPaginationRowModel()（`rows.slice(0, pageSize)`）還是後端的 `Take(pageSize)`，
 * 塞這個數字都會直接自然拿到全部資料，兩邊不用各寫一套特殊判斷。
 */
export const ALL_PAGE_SIZE = 1_000_000

/** TablePaginationBar 的每頁筆數選單選項。 */
export const PAGE_SIZE_OPTIONS = [
  { label: '每頁 20 筆', value: 20 },
  { label: '每頁 50 筆', value: 50 },
  { label: '全部', value: ALL_PAGE_SIZE }
]
