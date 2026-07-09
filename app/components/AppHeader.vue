<script setup lang="ts">
defineProps<{
  title: string
  subtitle?: string
  back?: boolean
}>()
const router = useRouter()

// Cast a soft shadow under the header only once the body is scrolled,
// so at rest the header blends into the page background.
const scrolled = ref(false)
function onScroll() {
  scrolled.value = window.scrollY > 4
}
onMounted(() => {
  onScroll()
  window.addEventListener('scroll', onScroll, { passive: true })
})
onBeforeUnmount(() => window.removeEventListener('scroll', onScroll))
</script>

<template>
  <header
    class="sticky top-0 z-20 bg-grey-100 pt-safe-t transition-shadow duration-200"
    :class="scrolled ? 'shadow-header' : ''"
  >
    <div
      class="mx-auto flex min-h-14 max-w-app items-center gap-1 px-4 py-2.5 md:py-5"
    >
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
