/**
 * Manufacturing Center 轉來的身分交接（handoff）：
 * 驗證票證 -> 呼叫後端 MainApi/LoginSso 換成 Sales Center 自己的內部 JWT。
 *
 * 跟 /api/auth/sso（PRORIL 通行證 OAuth，見 sso.post.ts）共用同一支 LoginSso，
 * 差別只在「怎麼確認這個帳號是誰驗證過的」：
 * OAuth 那條是直接跟通行證換 id_token，這條是驗 Manufacturing Center 簽發的票證。
 * LoginSso 本身不管帳號從哪來，只認 X-Internal-Secret + 帳號要在 MUsers 裡存在。
 */
interface LoginModel {
  status: boolean
  username?: string | null
  message?: string | null
  token?: string | null
}

export default defineEventHandler(async (event) => {
  const { ticket } = await readBody<{ ticket: string }>(event)
  if (!ticket) {
    throw createError({ statusCode: 400, statusMessage: '缺少票證 ticket' })
  }

  const config = useRuntimeConfig()
  if (!config.mfgHandoffSecret) {
    throw createError({ statusCode: 500, statusMessage: '尚未設定 NUXT_MFG_HANDOFF_SECRET，無法驗證製造中心轉來的身分' })
  }

  let account: string
  try {
    account = verifyHandoffTicket(ticket, config.mfgHandoffSecret)
  } catch (err: any) {
    console.log('handoff ticket verify failed -->', err)
    throw createError({ statusCode: 401, statusMessage: err?.message || '票證驗證失敗' })
  }

  try {
    return await $fetch<LoginModel>(`${config.public.apiBase}/MainApi/LoginSso`, {
      method: 'POST',
      headers: { 'X-Internal-Secret': config.ssoInternalSecret },
      body: { account }
    })
  } catch (err: any) {
    console.log('handoff LoginSso failed -->', err)
    throw createError({ statusCode: 502, statusMessage: '後端登入失敗' })
  }
})
