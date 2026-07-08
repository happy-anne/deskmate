<script setup lang="ts">
definePageMeta({ layout: 'blank' })

const client = useDb()
const { profile, load } = useProfile()
const { show } = useToast()

const checking = ref(false)

// If they somehow land here already approved, move on.
watchEffect(() => {
  if (profile.value?.status === 'approved' || profile.value?.role === 'admin') {
    navigateTo('/schedule', { replace: true })
  }
})

async function recheck() {
  checking.value = true
  await load()
  checking.value = false
  if (profile.value?.status === 'pending') show('아직 승인 대기 중이에요')
}

// Live update: when an admin approves this account, route in automatically.
let channel: ReturnType<typeof client.channel> | null = null
onMounted(() => {
  if (!profile.value) return
  channel = client
    .channel('me-approval')
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'users',
        filter: `id=eq.${profile.value.id}`,
      },
      (payload) => {
        const status = (payload.new as { status?: string }).status
        if (status === 'approved') navigateTo('/schedule', { replace: true })
      }
    )
    .subscribe()
})
onBeforeUnmount(() => {
  if (channel) client.removeChannel(channel)
})

async function logout() {
  await client.auth.signOut()
  navigateTo('/login', { replace: true })
}
</script>

<template>
  <div class="flex min-h-dvh flex-col items-center bg-white px-8 pt-safe-t text-center">
    <div class="mt-28 grid h-16 w-16 place-items-center rounded-2xl bg-warning/10 text-warning">
      <AppIcon name="lock" :size="30" />
    </div>
    <h1 class="mt-6 text-heading-lg text-ink">승인 대기 중이에요</h1>
    <p class="mt-2 text-body-lg text-grey-600">
      <b class="text-ink">{{ profile?.name }}</b>님, 가입 신청이 접수됐어요.<br />
      관리자가 승인하면 바로 이용할 수 있어요.
    </p>
    <p class="mt-6 rounded-xl bg-grey-50 px-4 py-3 text-body text-grey-500">
      승인되면 이 화면에서 자동으로 넘어가요.
    </p>

    <div class="mt-auto w-full pb-10">
      <button class="btn btn-lg btn-neutral w-full" :disabled="checking" @click="recheck">
        {{ checking ? '확인 중…' : '승인 상태 새로고침' }}
      </button>
      <button class="btn btn-lg btn-ghost mt-2 w-full text-grey-500" @click="logout">
        <AppIcon name="logout" :size="20" /> 로그아웃
      </button>
    </div>
  </div>
</template>
