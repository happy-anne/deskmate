<script setup lang="ts">
import type { AppUser } from '~/types/db'
definePageMeta({ layout: 'blank' })
// 이 화면에서는 body 배경을 흰색으로.
useHead({ bodyAttrs: { style: 'background-color:#fff' } })

const client = useDb()
const { error: toastError, show } = useToast()

const name = ref('')
const phone = ref('')
const email = ref('')
const password = ref('')
const loading = ref(false)
const match = ref<AppUser | null>(null)
const linkExisting = ref(true)

// Same-name placeholder detection -> offer to inherit their history.
watchDebounced(
  name,
  async (v) => {
    match.value = null
    if (v.trim().length < 2) return
    const { data } = await client
      .from('users')
      .select('*')
      .eq('name', v.trim())
      .eq('is_placeholder', true)
      .maybeSingle()
    match.value = (data as AppUser) ?? null
  },
  { debounce: 350 }
)

const formattedPhone = computed(() =>
  phone.value
    .replace(/[^\d]/g, '')
    .replace(/(\d{3})(\d{4})(\d{0,4})/, '$1-$2-$3')
    .replace(/-$/, '')
)

async function submit() {
  if (name.value.trim().length < 2) return toastError('이름을 입력해주세요')
  if (formattedPhone.value.replace(/\D/g, '').length < 10)
    return toastError('휴대폰 번호를 확인해주세요')
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.value))
    return toastError('이메일 형식을 확인해주세요')
  if (password.value.length < 6) return toastError('비밀번호는 6자 이상이어야 해요')

  loading.value = true
  // 가입 직후 자동 로그인 시 세션 만료 검사 대신 활동시각을 찍게 한다.
  sessionStorage.setItem('deskmate.freshLogin', '1')
  try {
    const { data, error } = await client.auth.signUp({
      email: email.value.trim(),
      password: password.value,
    })
    if (error) throw error
    if (!data.session || !data.user) {
      // Email confirmation is enabled on the project.
      show('가입 확인 메일을 보냈어요. 메일 인증 후 로그인해주세요.')
      await navigateTo('/login', { replace: true })
      return
    }

    const { data: me, error: e2 } = await client
      .from('users')
      .insert({
        auth_id: data.user.id,
        name: name.value.trim(),
        phone: formattedPhone.value,
        role: 'user',
        status: 'pending',
        is_placeholder: false,
      })
      .select()
      .single()
    if (e2) throw e2

    if (match.value && linkExisting.value) {
      const { error: e3 } = await client.rpc('promote_placeholder', {
        p_placeholder_id: match.value.id,
        p_real_id: (me as AppUser).id,
      })
      if (e3) console.warn('placeholder link failed', e3.message)
    }

    await navigateTo('/pending', { replace: true })
  } catch (e) {
    toastError(e)
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="flex min-h-dvh flex-col bg-white px-6 pb-10 pt-safe-t">
    <div class="flex items-center gap-1 pt-2">
      <NuxtLink
        to="/login"
        class="-ml-2 grid h-9 w-9 place-items-center rounded-full text-grey-700 active:bg-grey-100"
      >
        <AppIcon name="chevron-left" :size="24" />
      </NuxtLink>
    </div>

    <h1 class="mt-4 text-heading-lg text-ink">회원가입</h1>
    <p class="mt-2 text-body-lg text-grey-600">
      가입 후 관리자 승인을 받으면 이용할 수 있어요.
    </p>

    <div class="mt-8 space-y-4">
      <div>
        <label class="mb-2 block text-body font-medium text-grey-700">이름</label>
        <input v-model="name" class="field" placeholder="홍길동" autocomplete="name" />
      </div>
      <div>
        <label class="mb-2 block text-body font-medium text-grey-700">휴대폰 번호</label>
        <input
          :value="formattedPhone"
          class="field tnum"
          inputmode="tel"
          placeholder="010-1234-5678"
          @input="phone = ($event.target as HTMLInputElement).value"
        />
      </div>
      <div>
        <label class="mb-2 block text-body font-medium text-grey-700">이메일</label>
        <input
          v-model="email"
          type="email"
          inputmode="email"
          autocomplete="email"
          class="field"
          placeholder="you@example.com"
        />
      </div>
      <div>
        <label class="mb-2 block text-body font-medium text-grey-700">비밀번호</label>
        <input
          v-model="password"
          type="password"
          autocomplete="new-password"
          class="field"
          placeholder="6자 이상"
        />
      </div>

      <div
        v-if="match"
        class="rounded-xl border border-primary/30 bg-primary/[0.06] p-4"
      >
        <div class="flex items-start gap-2">
          <AppIcon name="sparkle" :size="20" class="mt-0.5 shrink-0 text-primary" />
          <div class="flex-1">
            <p class="text-body-lg font-semibold text-ink">기존 임시 사용자가 있어요</p>
            <p class="mt-1 text-body text-grey-600">
              "{{ match.name }}"님의 근무·교환·변경 이력을 이어받을 수 있어요.
            </p>
            <label class="mt-3 flex items-center gap-2 text-body font-medium text-grey-700">
              <input v-model="linkExisting" type="checkbox" class="h-5 w-5 accent-primary" />
              기존 근무 내역 이어받기
            </label>
          </div>
        </div>
      </div>
    </div>

    <button
      class="btn btn-xl btn-primary mt-8 w-full"
      :disabled="loading"
      @click="submit"
    >
      {{ loading ? '가입 중…' : '가입 신청하기' }}
    </button>
  </div>
</template>
