<script setup lang="ts">
const { toasts } = useToast()
</script>

<template>
  <Teleport to="body">
    <div
      class="pointer-events-none fixed inset-x-0 bottom-24 z-[110] mx-auto flex max-w-app flex-col items-center gap-2 px-5"
    >
      <TransitionGroup name="fade">
        <div
          v-for="t in toasts"
          :key="t.id"
          class="pointer-events-auto rounded-lg px-4 py-3 text-body font-medium text-white shadow-elevated"
          :class="t.tone === 'error' ? 'bg-error' : 'bg-ink'"
        >
          {{ t.message }}
        </div>
      </TransitionGroup>
    </div>
  </Teleport>
</template>
