<script setup lang="ts">
// Full-screen lock shown after 15 min idle. Verifies the device-local PIN.
const { verify } = usePinLock()
const entry = ref('')
const shake = ref(false)

const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del']

function press(k: string) {
  if (k === 'del') {
    entry.value = entry.value.slice(0, -1)
    return
  }
  if (k === '' || entry.value.length >= 4) return
  entry.value += k
  if (entry.value.length === 4) submit()
}

function submit() {
  if (verify(entry.value)) {
    entry.value = ''
  } else {
    shake.value = true
    setTimeout(() => {
      shake.value = false
      entry.value = ''
    }, 400)
  }
}
</script>

<template>
  <div
    class="fixed inset-0 z-[100] mx-auto flex max-w-app flex-col items-center bg-white px-8 pt-safe-t"
  >
    <div class="mt-24 flex flex-col items-center">
      <div
        class="grid h-14 w-14 place-items-center rounded-2xl bg-primary/10 text-primary"
      >
        <AppIcon name="lock" :size="28" />
      </div>
      <h1 class="mt-5 text-heading-lg text-ink">PIN을 입력해주세요</h1>
      <p class="mt-1 text-body text-grey-500">잠금을 해제하려면 4자리를 입력하세요</p>

      <div
        class="mt-10 flex gap-4"
        :class="shake ? 'animate-[shake_0.4s]' : ''"
      >
        <span
          v-for="i in 4"
          :key="i"
          class="h-4 w-4 rounded-full transition-colors"
          :class="entry.length >= i ? 'bg-primary' : 'bg-grey-200'"
        />
      </div>
    </div>

    <div class="mt-auto grid w-full max-w-xs grid-cols-3 gap-2 pb-16">
      <button
        v-for="(k, i) in keys"
        :key="i"
        :disabled="k === ''"
        class="grid h-16 place-items-center rounded-2xl text-[27px] font-medium text-ink transition-colors active:bg-grey-100 disabled:opacity-0"
        @click="press(k)"
      >
        <AppIcon v-if="k === 'del'" name="chevron-left" :size="26" />
        <span v-else>{{ k }}</span>
      </button>
    </div>
  </div>
</template>

<style scoped>
@keyframes shake {
  0%, 100% { transform: translateX(0); }
  25% { transform: translateX(-8px); }
  75% { transform: translateX(8px); }
}
</style>
