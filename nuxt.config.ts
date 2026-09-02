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
    public: {
      // 1.0 .NET 站台的根位址。**不要加 /api** ——
      // PRORIL 的路由是 {controller}/{action}/{id?}，沒有 api 前綴
      // （原本這裡的預設值是從製造中心複製過來的 localhost:7000/api，兩點都錯）。
      apiBase: process.env.NUXT_PUBLIC_API_BASE || 'https://intranet-dev.proril.com',
      blockRobots: process.env.NUXT_PUBLIC_BLOCK_ROBOTS === 'true',
      devToken: process.env.NUXT_PUBLIC_DEV_TOKEN || ''
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
