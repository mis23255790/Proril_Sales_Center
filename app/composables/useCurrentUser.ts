import type { ApiResponse } from '~/types/api'

interface CurrentUser {
  account: string
  username: string
  isAdmin: boolean
}

/**
 * 目前登入者的姓名/管理員身分。
 *
 * 帳號本身可以直接解 JWT（見 useAuthAccount），但姓名不在 token 裡，
 * 要打 MainApi/GetCurrentUser 查 M_User。
 */
export const useCurrentUser = () => {
  const { apiFetch } = useApi()

  const getCurrentUser = () => apiFetch<ApiResponse<CurrentUser>>('/MainApi/GetCurrentUser')

  return { getCurrentUser }
}
