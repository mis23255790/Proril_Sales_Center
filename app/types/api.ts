// 後端 .NET (PRORIL) 統一回傳信封。全站 API 都是這個形狀。
export interface ApiResponse<T = any> {
  isSuccess: boolean
  message?: string | null
  body?: T
  body2?: any
}
