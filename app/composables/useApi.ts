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

export const getAuthToken = () => {
  if (import.meta.client) return localStorage.getItem('proril-token') || ''
  return ''
}
