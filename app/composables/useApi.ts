export const useApi = () => {
  const toast = useToast()

  // token 在 httpOnly cookie，由 /api/proxy 在 server 端轉成 Authorization，這裡不用帶
  const apiFetch = async <T = any>(path: string, opts: Record<string, any> = {}): Promise<T> => {
    try {
      return await $fetch(path, {
        baseURL: '/api/proxy',
        ...opts
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
 * 登入狀態。token 本身在 httpOnly cookie `proril-token`，JS 讀不到；
 * 前端看的是 server 端一起寫的 `proril-session`（只有帳號與到期時間，
 * 見 server/utils/authCookie.ts）。放 cookie 而不是 localStorage，SSR 階段才讀得到，
 * auth.global.ts 才能在 server 端就把未登入者擋掉。
 *
 * NUXT_PUBLIC_DEV_TOKEN 有值時（本機開發）沒有 session cookie 就用它的 claims。
 */
export interface AuthSession {
  account: string
  exp: number
}

const authSessionCookie = () => useCookie<AuthSession | null>('proril-session', {
  path: '/',
  sameSite: 'lax'
})

export const getAuthSession = (): AuthSession | null => {
  const session = authSessionCookie().value
  if (session?.exp) return session

  const devToken = useRuntimeConfig().public.devToken
  if (!devToken) return null
  const payload = decodeJwtPayload(devToken)
  if (!payload?.exp) return null
  return { account: (payload.sub as string) || '', exp: payload.exp }
}

export const isAuthSessionValid = (): boolean => {
  const session = getAuthSession()
  return !!session && Date.now() < session.exp * 1000
}

/** 登出：httpOnly cookie 只能由 server 端清，前端這份 session 也一起清掉。 */
export const logoutAuth = async () => {
  try {
    await $fetch('/api/auth/logout', { method: 'POST' })
  } catch (err) {
    console.log('logoutAuth failed -->', err)
  }
  authSessionCookie().value = null
}
