/**
 * 查詢條件區塊展開／收合狀態，各頁面用 pageKey 分開記。
 * 記在 cookie（SSR 也讀得到，進頁面不會先展開再收合閃一下），一年有效，預設展開。
 * 收合只是 v-show 藏欄位，條件值還在，收合狀態下按查詢照樣帶目前的條件。
 */
export const useFiltersOpen = (pageKey: string) =>
  useCookie<boolean>(`filters-open-${pageKey}`, { default: () => true, maxAge: 60 * 60 * 24 * 365 })
