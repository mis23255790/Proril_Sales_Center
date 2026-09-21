// @ts-check
import withNuxt from './.nuxt/eslint.config.mjs'

export default withNuxt(
  {
    rules: {
      // CLAUDE.md：開發效率優先時允許彈性使用 any，只降級成提醒，不擋 CI
      '@typescript-eslint/no-explicit-any': 'warn'
    }
  }
)
