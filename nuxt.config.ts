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

  runtimeConfig: {
    public: {
      apiBase: process.env.NUXT_PUBLIC_API_BASE || 'https://localhost:7000/api',
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
