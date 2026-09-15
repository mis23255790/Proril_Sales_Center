<script setup lang="ts">
const config = useRuntimeConfig()
const show = config.public.showWatermark
</script>

<template>
  <div v-if="show" class="dev-watermark" aria-hidden="true">
    <svg class="dev-watermark__svg">
      <defs>
        <pattern
          id="dev-watermark-pattern"
          width="260"
          height="200"
          patternUnits="userSpaceOnUse"
          patternTransform="rotate(-30)"
        >
          <text x="0" y="100" class="dev-watermark__text">開發環境</text>
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill="url(#dev-watermark-pattern)" />
    </svg>
  </div>
</template>

<style scoped>
.dev-watermark {
  position: fixed;
  inset: 0;
  z-index: 9999;
  pointer-events: none;

  .dev-watermark__svg {
    width: 100%;
    height: 100%;
  }

  .dev-watermark__text {
    font-size: 24px;
    font-family: inherit;
    fill: #6b7280;
    opacity: 0.35;
  }
}
</style>
