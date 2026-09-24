export const useApi = () => {
  const toast = useToast()
  const config = useRuntimeConfig()

  const apiFetch = async <T = any>(path: string, opts: Record<string, any> = {}): Promise<T> => {
    const token = getAuthToken() || config.public.devToken
    try {
      return await $fetch(path, {
        baseURL: '/api/proxy',
        ...opts,
        headers: {
          ...(opts.headers || {}),
          ...(token ? { Authorization: `Bearer ${token}` } : {})
        }
      }) as T
    } catch (err: any) {
      // 403 = 後端 RequirePermission 擋下來（沒有這個功能的權限），不是連線問題
      if (err?.statusCode === 403 || err?.status === 403) {
        toast.add({
          title: '沒有權限',
          description: err?.data?.message || '沒有此功能的權限，請洽系統管理員。',
          color: 'warning'
        })
        throw err
      }
      toast.add({
        title: '無法連接後端 API',
        description: err?.data?.message || err?.message || `${path} 請求失敗`,
        color: 'error'
      })
      throw err
    }
  }

  return { apiFetch }
}

/**
 * token 存在 cookie（而不是 localStorage），SSR 階段才讀得到，
 * auth.global.ts 才能在 server 端就把未登入者擋掉，不會讓受保護頁面的完整 HTML
 * 在 hydrate 完成前先送到瀏覽器。
 */
const authTokenCookie = () => useCookie<string | null>('proril-token', {
  path: '/',
  sameSite: 'lax',
  maxAge: 60 * 60 * 24
})

export const getAuthToken = () => authTokenCookie().value || ''

export const setAuthToken = (token: string) => {
  authTokenCookie().value = token
}

export const clearAuthToken = () => {
  authTokenCookie().value = null
}
