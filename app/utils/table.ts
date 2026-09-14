/**
 * 可點擊列（整列進入編輯／明細畫面）的 UTable `tr` 樣式。
 * 規範：只要 table 有對應的編輯畫面，就掛這組 class + `@select`，
 * hover 時整列變色、文字加底線、游標變手指，點任一處都進編輯畫面。
 * 列內的按鈕／連結不跟著加底線（避免 outline 按鈕看起來像壞掉）。
 */
export const clickableRowTr
  = 'cursor-pointer hover:bg-elevated/50 hover:[&_td]:underline hover:[&_td_button]:no-underline hover:[&_td_a]:no-underline'
