<script setup lang="ts">
definePageMeta({ layout: 'blank' })

// Reached via the password-recovery email link (Supabase sets a session from
// the URL) or while logged in. Lets the user set a new password.
const client = useSupabaseClient()
const authUser = useSupabaseUser()
const { show, error: toastError } = useToast()

const password = ref('')
const confirm = ref('')
const loading = ref(false)

async function save() {
  if (password.value.length < 6) return toastError('비밀번호는 6자 이상이어야 해요')
  if (password.value !== confirm.value) return toastError('비밀번호가 일치하지 않아요')
  if (!authUser.value) return toastError('링크가 만료됐어요. 다시 시도해주세요')

  loading.value = true
  const { error } = await client.auth.updateUser({ password: password.value })
  loading.value = false
  if (error) return toastError(error.message)
  show('비밀번호를 변경했어요')
  navigateTo('/schedule', { replace: true })
}
</script>

<template>
  <div class="flex min-h-dvh flex-col bg-white px-6 pb-10 pt-safe-t">
    <h1 class="mt-20 text-heading-lg text-ink">비밀번호 설정</h1>
    <p class="mt-2 text-body-lg text-grey-600">
      새로 사용할 비밀번호를 입력해주세요.
    </p>

    <div class="mt-10 space-y-4">
      <div>
        <label class="mb-2 block text-body font-medium text-grey-700">새 비밀번호</label>
        <input v-model="password" type="password" class="field" placeholder="6자 이상" autocomplete="new-password" />
      </div>
      <div>
        <label class="mb-2 block text-body font-medium text-grey-700">비밀번호 확인</label>
        <input v-model="confirm" type="password" class="field" placeholder="다시 입력" autocomplete="new-password" @keyup.enter="save" />
      </div>
    </div>

    <button class="btn btn-xl btn-primary mt-auto w-full" :disabled="loading" @click="save">
      {{ loading ? '변경 중…' : '비밀번호 변경' }}
    </button>
  </div>
</template>
