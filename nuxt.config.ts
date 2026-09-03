// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  modules: [
    '@nuxt/eslint',
    '@nuxt/ui',
    '@nuxtjs/robots'
  ],

  devtools: {
    enabled: true
  },

  css: ['~/assets/css/main.css'],

  // components/ 底下用子目錄分共用（common/）與模組（sales-issue/、sales-search/…），
  // 純粹整理檔案位置。pathPrefix:false 讓元件標籤名照舊只看檔名（例如
  // common/AppLogo.vue 還是 <AppLogo>），不會因為換資料夾就變成 <CommonAppLogo>，
  // 才不用把全站呼叫端都改一輪。
  components: [
    { path: '~/components', pathPrefix: false }
  ],

  runtimeConfig: {
    // 以下只在 server 端讀得到（code 換 token 要帶 client secret，不能進瀏覽器）
    oauthTokenUrl: process.env.NUXT_OAUTH_TOKEN_URL || 'https://oauth.proril.com/oauth/token',
    oauthClientSecret: process.env.NUXT_OAUTH_CLIENT_SECRET || '',
    // 呼叫 MainApi/LoginSso 用的內部密鑰，必須跟 api/appsettings 的 Sso:InternalSecret 一致
    ssoInternalSecret: process.env.NUXT_SSO_INTERNAL_SECRET || '',
    // 驗證 Manufacturing Center 轉來的身分交接票證用，必須跟對方簽發票證的密鑰一致
    mfgHandoffSecret: process.env.NUXT_MFG_HANDOFF_SECRET || '',

    public: {
      // 1.0 .NET 站台的根位址。**不要加 /api** ——
      // PRORIL 的路由是 {controller}/{action}/{id?}，沒有 api 前綴
      // （原本這裡的預設值是從製造中心複製過來的 localhost:7000/api，兩點都錯）。
      apiBase: process.env.NUXT_PUBLIC_API_BASE || 'https://intranet-dev.proril.com',
      blockRobots: process.env.NUXT_PUBLIC_BLOCK_ROBOTS === 'true',
      devToken: process.env.NUXT_PUBLIC_DEV_TOKEN || '',

      // PRORIL 通行證 SSO，見 https://oauth.proril.com/docs
      oauthClientId: process.env.NUXT_PUBLIC_OAUTH_CLIENT_ID || '',
      oauthAuthorizeUrl: process.env.NUXT_PUBLIC_OAUTH_AUTHORIZE_URL || 'https://oauth.proril.com/oauth/authorize',
      oauthRedirectUri: process.env.NUXT_PUBLIC_OAUTH_REDIRECT_URI || '',
      oauthScope: process.env.NUXT_PUBLIC_OAUTH_SCOPE || 'openid',

      // Manufacturing Center 的網址，身分交接失敗時導使用者回去重新進入
      mfgCenterUrl: process.env.NUXT_PUBLIC_MFG_CENTER_URL || ''
    }
  },

  robots: {
    disallow: process.env.NUXT_PUBLIC_BLOCK_ROBOTS === 'true' ? ['/'] : []
  },

  compatibilityDate: '2026-06-30',

  eslint: {
    config: {
      stylistic: {
        commaDangle: 'never',
        braceStyle: '1tbs'
      }
    }
  }
})
