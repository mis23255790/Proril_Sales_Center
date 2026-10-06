import type { MaybeRefOrGetter } from 'vue'

/**
 * 頂部導覽列（layouts/default.vue 的 UDashboardNavbar）顯示的頁面名稱。
 *
 * 一般頁面不用呼叫：導覽列會依序取 definePageMeta 的 title → 權限樹對應的功能名稱 → 模組名稱。
 * 只有標題會變的頁面（例如客戶相關資訊要顯示客戶名稱）才用這個覆寫，離開頁面自動清掉。
 */
export const usePageHeading = (title: MaybeRefOrGetter<string>) => {
  const heading = useState<string>('pageHeading', () => '')
  watchEffect(() => {
    heading.value = toValue(title)
  })
  onBeforeUnmount(() => {
    heading.value = ''
  })
}
