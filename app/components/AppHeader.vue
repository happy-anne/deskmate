<script setup lang="ts">
defineProps<{
  title: string
  subtitle?: string
  back?: boolean
}>()
const router = useRouter()
</script>

<template>
  <header
    class="sticky top-0 z-20 mx-auto max-w-app bg-white/95 pt-safe-t backdrop-blur"
  >
    <div class="flex min-h-14 items-center gap-1 px-5 py-2.5">
      <button
        v-if="back"
        class="-ml-2 grid h-9 w-9 place-items-center rounded-full text-grey-700 active:bg-grey-100"
        aria-label="뒤로"
        @click="router.back()"
      >
        <AppIcon name="chevron-left" :size="24" />
      </button>
      <div class="min-w-0 flex-1">
        <h1 class="truncate text-heading-lg text-ink">{{ title }}</h1>
        <p v-if="subtitle" class="text-body-sm text-grey-500">{{ subtitle }}</p>
      </div>
      <slot name="action" />
    </div>
  </header>
</template>
