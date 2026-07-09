<script setup lang="ts">
const authUser = useSupabaseUser()
const { profile, load: loadProfile } = useProfile()
const notif = useNotifications()
const pin = usePinLock()

// Boot: load profile + notifications once authenticated, wire realtime.
watch(
  authUser,
  async (u) => {
    if (u) {
      await loadProfile()
      if (profile.value) {
        await notif.load()
        notif.subscribe()
      }
    } else {
      notif.unsubscribe()
    }
  },
  { immediate: true }
)

onMounted(() => {
  pin.init()

  // Activity tracking for the 15-minute idle lock.
  const onActivity = () => pin.touch()
  const events = ['pointerdown', 'keydown', 'visibilitychange']
  events.forEach((e) => window.addEventListener(e, onActivity, { passive: true }))

  // Re-evaluate idle when the app returns to foreground.
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') pin.evaluateIdle()
  })

  // Safety poll every 30s.
  const timer = setInterval(() => pin.evaluateIdle(), 30_000)

  onBeforeUnmount(() => {
    events.forEach((e) => window.removeEventListener(e, onActivity))
    clearInterval(timer)
    notif.unsubscribe()
  })
})
</script>

<template>
  <div class="min-h-dvh">
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
    <ToastHost />
    <PinLock v-if="pin.locked.value" />
  </div>
</template>
