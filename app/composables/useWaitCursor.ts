import type { WatchSource } from 'vue'

/**
 * 全頁共用的等待中計數。多個畫面／多支 API 同時在等時，全部結束才拿掉游標，
 * 避免先回來的那支把別人的 wait cursor 收掉。
 */
let waitingCount = 0

const WAIT_CLASS = 'is-waiting'

const applyCursor = () => {
  try {
    document.documentElement.classList.toggle(WAIT_CLASS, waitingCount > 0)
  } catch (err) {
    console.log('useWaitCursor applyCursor failed -->', err)
  }
}

/**
 * source 為 true 時整頁游標換成等待圖示（cursor: progress，仍可點、可輸入），
 * 用來取代整頁遮罩 FullPageLoading 的「我在忙」提示。樣式在 main.css 的 html.is-waiting。
 * 離開頁面時若還在等，會自動扣回計數。
 */
export const useWaitCursor = (source: WatchSource<boolean>) => {
  let active = false

  const set = (value: boolean) => {
    if (value === active) return
    active = value
    waitingCount = Math.max(0, waitingCount + (value ? 1 : -1))
    applyCursor()
  }

  if (import.meta.client) {
    watch(source, v => set(!!v), { immediate: true })
    onBeforeUnmount(() => set(false))
  }
}
