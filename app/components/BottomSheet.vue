<script setup lang="ts">
const props = defineProps<{ modelValue: boolean; title?: string }>()
const emit = defineEmits<{ 'update:modelValue': [boolean] }>()

function close() {
  emit('update:modelValue', false)
}

watch(
  () => props.modelValue,
  (open) => {
    if (import.meta.client)
      document.body.style.overflow = open ? 'hidden' : ''
  }
)
</script>

<template>
  <Teleport to="body">
    <Transition name="fade">
      <div
        v-if="modelValue"
        class="fixed inset-0 z-50 bg-[rgba(2,9,19,0.5)]"
        @click.self="close"
      >
        <Transition name="sheet" appear>
          <div
            class="absolute inset-x-0 bottom-0 mx-auto max-w-app rounded-t-2xl bg-white pb-safe-b shadow-modal"
          >
            <div class="flex items-center justify-between px-5 pb-2 pt-4">
              <h2 class="text-subtitle text-ink">{{ title }}</h2>
              <button
                class="-mr-2 grid h-9 w-9 place-items-center rounded-full text-grey-500 active:bg-grey-100"
                aria-label="닫기"
                @click="close"
              >
                <AppIcon name="x" :size="22" />
              </button>
            </div>
            <div class="max-h-[70vh] overflow-y-auto px-5 pb-6">
              <slot />
            </div>
          </div>
        </Transition>
      </div>
    </Transition>
  </Teleport>
</template>
