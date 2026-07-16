<script setup lang="ts">
const authUser = useSupabaseUser()
const supabase = useSupabaseClient()
const { profile, load: loadProfile } = useProfile()
const notif = useNotifications()
const pin = usePinLock()

// PIN 을 설정하지 않은 경우엔 세션을 2시간으로 제한한다(미사용 기준).
// PIN 이 있으면 기존대로 30일 유지(PIN 잠금이 보호).
const NO_PIN_MAX_IDLE = 2 * 60 * 60 * 1000
const K_FRESH = 'deskmate.freshLogin'

// 2시간 넘게 미사용 + PIN 미설정이면 로그아웃. 로그아웃하면 true.
async function sessionExpiredLogout(): Promise<boolean> {
  if (!import.meta.client || !authUser.value) return false
  if (pin.isPinActive()) return false
  const last = pin.lastActiveAt()
  if (last && Date.now() - last > NO_PIN_MAX_IDLE) {
    await supabase.auth.signOut()
    await navigateTo('/login', { replace: true })
    return true
  }
  return false
}

// Boot: load profile + notifications once authenticated, wire realtime.
watch(
  authUser,
  async (u) => {
    if (u) {
      if (import.meta.client) {
        // 방금 로그인했으면 활동시각을 찍고, 그렇지 않으면(세션 복원) 만료 검사.
        if (sessionStorage.getItem(K_FRESH)) {
          sessionStorage.removeItem(K_FRESH)
          pin.touch()
        } else if (await sessionExpiredLogout()) {
          return
        }
      }
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
    if (document.visibilityState === 'visible') {
      pin.evaluateIdle()
      sessionExpiredLogout()
    }
  }
  document.addEventListener('visibilitychange', onVisible)

  // Safety poll every 30s while in the foreground.
  const timer = setInterval(() => {
    pin.evaluateIdle()
    sessionExpiredLogout()
  }, 30_000)

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
