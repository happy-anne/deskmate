<script setup lang="ts">
import type { AppUser } from '~/types/db'
definePageMeta({ layout: 'blank' })

const client = useDb()
const { completeOnboarding } = useProfile()
const { error: toastError } = useToast()

const name = ref('')
const phone = ref('')
const loading = ref(false)
const match = ref<AppUser | null>(null)
const linkExisting = ref(true)

// Look for a placeholder (임시) user with the same name to offer takeover.
watchDebounced(
  name,
  async (v) => {
    match.value = null
    const trimmed = v.trim()
    if (trimmed.length < 2) return
    const { data } = await client
      .from('users')
      .select('*')
      .eq('name', trimmed)
      .eq('is_placeholder', true)
      .maybeSingle()
    match.value = (data as AppUser) ?? null
  },
  { debounce: 350 }
)

const formatted = computed(() =>
  phone.value.replace(/[^\d]/g, '').replace(/(\d{3})(\d{4})(\d{0,4})/, '$1-$2-$3').replace(/-$/, '')
)

async function submit() {
  if (name.value.trim().length < 2) return toastError('이름을 입력해주세요')
  if (formatted.value.replace(/\D/g, '').length < 10)
    return toastError('휴대폰 번호를 확인해주세요')

  loading.value = true
  try {
    const me = await completeOnboarding(name.value, formatted.value)
    if (match.value && linkExisting.value) {
      const { error } = await client.rpc('promote_placeholder', {
        p_placeholder_id: match.value.id,
        p_real_id: me.id,
      })
      if (error) console.warn('placeholder link failed', error.message)
    }
    await navigateTo('/pending', { replace: true })
  } catch (e: any) {
    toastError(e.message ?? '문제가 생겼어요')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="flex min-h-dvh flex-col px-6 pb-10 pt-safe-t">
    <div class="mt-16">
      <h1 class="text-heading-lg text-ink">처음 오셨네요</h1>
      <p class="mt-2 text-body-lg text-grey-600">
        근무표에 표시할 정보를 알려주세요.
      </p>
    </div>

    <div class="mt-10 space-y-5">
      <div>
        <label class="mb-2 block text-body font-medium text-grey-700">이름</label>
        <input v-model="name" class="field" placeholder="홍길동" autocomplete="name" />
      </div>
      <div>
        <label class="mb-2 block text-body font-medium text-grey-700"
          >휴대폰 번호</label
        >
        <input
          :value="formatted"
          class="field tnum"
          inputmode="tel"
          placeholder="010-1234-5678"
          @input="phone = ($event.target as HTMLInputElement).value"
        />
      </div>

      <!-- Placeholder takeover -->
      <div
        v-if="match"
        class="rounded-xl border border-primary/30 bg-primary/[0.06] p-4"
      >
        <div class="flex items-start gap-2">
          <AppIcon name="sparkle" :size="20" class="mt-0.5 shrink-0 text-primary" />
          <div class="flex-1">
            <p class="text-body-lg font-semibold text-ink">
              기존 임시 사용자가 있어요
            </p>
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
      class="btn btn-xl btn-primary mt-auto w-full"
      :disabled="loading"
      @click="submit"
    >
      {{ loading ? '저장 중…' : '시작하기' }}
    </button>
  </div>
</template>
