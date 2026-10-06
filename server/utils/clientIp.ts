import type { H3Event } from 'h3'

/**
 * 轉給後端 api/ 時帶上使用者端 IP（X-Forwarded-For），後端稽核紀錄 SYS_AuditLog 用
 * （api/Controllers/Shared/BaseApiController.cs 的 GetClientIp）。
 *
 * api/ 前面一定隔著這層 Nuxt server，後端看到的連線來源永遠是 Nuxt，不帶就分不出是誰。
 * 前面若還有 nginx 反向代理，它設的 X-Forwarded-For 第一段就是使用者，xForwardedFor: true 會取那一段。
 */
export const forwardedForHeader = (event: H3Event): Record<string, string> => {
  const ip = getRequestIP(event, { xForwardedFor: true })
  return ip ? { 'X-Forwarded-For': ip } : {}
}
