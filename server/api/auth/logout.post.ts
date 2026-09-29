/**
 * 登出：清掉 httpOnly 的 token cookie（瀏覽器 JS 刪不掉，只能由 server 端清）。
 * 只登出業務中心；PRORIL 通行證目前沒有 end_session 端點，那邊的 session 還在。
 */
export default defineEventHandler((event) => {
  assertSameSiteRequest(event)
  clearAuthCookies(event)
  return { status: true }
})
