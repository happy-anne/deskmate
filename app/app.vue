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

  // Activity tracking for the 15-minute idle lock. Only genuine interaction
  // counts as activity — NOT visibilitychange. Returning to the foreground must
  // re-evaluate idle, not reset it, otherwise the app could never lock.
  const onActivity = () => pin.touch()
  const events = ['pointerdown', 'keydown']
  events.forEach((e) => window.addEventListener(e, onActivity, { passive: true }))

  // Re-evaluate idle when the app returns to foreground (timers pause in bg).
  const onVisible = () => {
    if (document.visibilityState === 'visible') pin.evaluateIdle()
  }
  document.addEventListener('visibilitychange', onVisible)

  // Safety poll every 30s while in the foreground.
  const timer = setInterval(() => pin.evaluateIdle(), 30_000)

  onBeforeUnmount(() => {
    events.forEach((e) => window.removeEventListener(e, onActivity))
    document.removeEventListener('visibilitychange', onVisible)
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
