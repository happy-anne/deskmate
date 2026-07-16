<script setup lang="ts">
definePageMeta({ layout: 'blank' })
// 이 화면에서는 body 배경을 흰색으로.
useHead({ bodyAttrs: { style: 'background-color:#fff' } })

const client = useSupabaseClient()
const authUser = useSupabaseUser()
const { error: toastError } = useToast()

const { show } = useToast()
const email = ref('')
const password = ref('')
const loading = ref(false)

async function resetPassword() {
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.value)) {
    return toastError('먼저 이메일을 입력해주세요')
  }
  const { error } = await client.auth.resetPasswordForEmail(email.value.trim(), {
    redirectTo: `${window.location.origin}/reset`,
  })
  if (error) return toastError(error.message)
  show('비밀번호 재설정 메일을 보냈어요')
}

watchEffect(() => {
  if (authUser.value) navigateTo('/schedule', { replace: true })
})

async function login() {
  if (!email.value.trim() || !password.value) {
    return toastError('이메일과 비밀번호를 입력해주세요')
  }
  loading.value = true
  // 방금 로그인했음을 app.vue에 알려 세션 만료 검사 대신 활동시각을 찍게 한다.
  sessionStorage.setItem('deskmate.freshLogin', '1')
  const { error } = await client.auth.signInWithPassword({
    email: email.value.trim(),
    password: password.value,
  })
  loading.value = false
  if (error) return toastError(error)
  // watchEffect routes onward once the session is set.
}
</script>

<template>
  <div class="flex min-h-dvh flex-col bg-white px-6 pb-10 pt-safe-t">
    <div class="mt-20">
      <div class="grid h-14 w-14 place-items-center overflow-hidden rounded-2xl border-2 border-[#191f28] bg-white">
        <img src="/favicon/favicon_512.png" alt="DeskMate" class="h-full w-full object-cover" />
      </div>
      <h1 class="mt-6 text-display-lg text-ink">DeskMate</h1>
      <p class="mt-2 text-body-lg text-grey-600">
        데스크 메이트와 함께 슬기로운 안내 생활~
      </p>
    </div>

    <div class="mt-12 space-y-3">
      <div>
        <label class="mb-2 block text-body font-medium text-grey-700">이메일</label>
        <input
          v-model="email"
          type="email"
          inputmode="email"
          autocomplete="email"
          placeholder="you@example.com"
          class="field"
        />
      </div>
      <div>
        <label class="mb-2 block text-body font-medium text-grey-700">비밀번호</label>
        <input
          v-model="password"
          type="password"
          autocomplete="current-password"
          placeholder="비밀번호"
          class="field"
          @keyup.enter="login"
        />
      </div>
      <button
        class="ml-auto block text-body-sm font-medium text-grey-500"
        @click="resetPassword"
      >
        비밀번호를 잊으셨나요?
      </button>
    </div>

    <div class="mt-auto pt-10">
      <button class="btn btn-xl btn-primary w-full" :disabled="loading" @click="login">
        {{ loading ? '로그인 중…' : '로그인' }}
      </button>
      <NuxtLink
        to="/signup"
        class="mt-3 block text-center text-body-lg font-medium text-grey-600"
      >
        아직 계정이 없으신가요? <span class="font-semibold text-primary">회원가입</span>
      </NuxtLink>
    </div>
  </div>
</template>
