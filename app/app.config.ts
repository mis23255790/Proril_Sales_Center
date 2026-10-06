export default defineAppConfig({
  ui: {
    colors: {
      primary: 'brand',
      neutral: 'navy'
    },
    table: {
      slots: {
        // 中文表頭在欄位被擠窄時會一字一行（例如「客戶名稱」直排成四行）。
        // 表頭最少保留 2 個字寬（2em）+ 左右 padding（px-4 = 2rem），一行至少 2 字；
        // 沒有文字的表頭（展開鈕、勾選框欄）不套用。
        th: 'min-w-[calc(2em+2rem)] empty:min-w-0'
      }
    }
  }
})
