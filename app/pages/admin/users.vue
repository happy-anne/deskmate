<script setup lang="ts">
import type { AppUser } from '~/types/db'
definePageMeta({ middleware: 'admin' })

const client = useDb()
const { profile } = useProfile()
const { show, error: toastError } = useToast()

const users = ref<AppUser[]>([])
const q = ref('')

async function load() {
  const { data } = await client.from('users').select('*').order('created_at')
  users.value = (data as AppUser[]) ?? []
}
await useAsyncData('admin-users', load)

// Pending signups (real accounts awaiting approval).
const pending = computed(() =>
  users.value.filter((u) => !u.is_placeholder && u.status === 'pending')
)
const members = computed(() =>
  users.value.filter(
    (u) => (u.is_placeholder || u.status !== 'pending') && u.name.includes(q.value.trim())
  )
)
// Total members (placeholders + approved/rejected), independent of the search box.
const memberCount = computed(
  () => users.value.filter((u) => u.is_placeholder || u.status !== 'pending').length
)

async function setStatus(u: AppUser, status: AppUser['status']) {
  const { error } = await client.from('users').update({ status }).eq('id', u.id)
  if (error) return toastError(error.message)
  u.status = status
  show(status === 'approved' ? `${u.name}님을 승인했어요` : `${u.name}님을 거절했어요`)
}

// create placeholder (approved by definition — no login)
const addOpen = ref(false)
const newName = ref('')
const nameInput = ref<HTMLInputElement | null>(null)

// Autofocus the name field when the sheet opens (after it has mounted).
watch(addOpen, (open) => {
  if (open) nextTick(() => nameInput.value?.focus())
})
async function createPlaceholder() {
  const name = newName.value.trim()
  if (name.length < 1) return
  const { error } = await client
    .from('users')
    .insert({ name, is_placeholder: true, status: 'approved' })
  if (error) return toastError(error.message)
  show(`${name}(임시)을 추가했어요`)
  newName.value = ''
  addOpen.value = false
  await load()
}

async function toggleAdmin(u: AppUser) {
  if (u.is_placeholder) return
  const role = u.role === 'admin' ? 'user' : 'admin'
  const { error } = await client.from('users').update({ role }).eq('id', u.id)
  if (error) return toastError(error.message)
  u.role = role
}

async function remove(u: AppUser) {
  if (!confirm(`${u.name}님을 삭제할까요?`)) return
  const { error } = await client.from('users').delete().eq('id', u.id)
  if (error) return toastError(error.message)
  await load()
}
</script>

<template>
  <div>
    <AppHeader title="사용자 관리" back>
      <template #action>
        <button class="btn btn-sm btn-primary" @click="addOpen = true">
          <AppIcon name="plus" :size="18" /> 임시 추가
        </button>
      </template>
    </AppHeader>

    <div class="mx-auto max-w-app px-4 pb-6 pt-1">
      <!-- Pending approvals -->
      <section v-if="pending.length" class="mb-4">
        <div class="mb-2 flex items-center gap-2 px-1">
          <span class="text-body font-semibold text-grey-700">가입 신청</span>
          <span class="badge badge-fill-blue">{{ pending.length }}</span>
        </div>
        <ul class="space-y-2">
          <li
            v-for="u in pending"
            :key="u.id"
            class="card flex items-center gap-3 p-4"
          >
            <div class="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-warning/10 text-warning">
              <AppIcon name="user" :size="20" />
            </div>
            <div class="min-w-0 flex-1">
              <p class="truncate text-body-lg font-semibold text-ink">{{ u.name }}</p>
              <p class="text-body-sm text-grey-500 tnum">{{ u.phone || '—' }}</p>
            </div>
            <button class="btn btn-sm btn-neutral" @click="setStatus(u, 'rejected')">거절</button>
            <button class="btn btn-sm btn-primary" @click="setStatus(u, 'approved')">승인</button>
          </li>
        </ul>
      </section>

      <!-- Members -->
      <div class="mb-2 flex items-center gap-2 px-1">
        <span class="text-body font-semibold text-grey-700">전체 사용자</span>
        <span class="badge badge-grey">{{ memberCount }}명</span>
      </div>
      <input v-model="q" class="field mb-3" placeholder="이름 검색" />
      <ul class="divide-y divide-grey-100 overflow-hidden rounded-xl bg-white shadow-card">
        <li v-for="u in members" :key="u.id" class="flex items-center gap-3 px-4 py-3.5">
          <div class="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-grey-100 text-grey-500">
            <AppIcon name="user" :size="20" />
          </div>
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-1.5">
              <span class="truncate text-body-lg font-medium text-ink">{{ u.name }}</span>
              <span v-if="u.is_placeholder" class="badge badge-grey">임시</span>
              <span v-else-if="u.role === 'admin'" class="badge badge-blue">관리자</span>
              <span v-else-if="u.status === 'rejected'" class="badge badge-red">거절됨</span>
            </div>
            <p class="text-body-sm text-grey-500 tnum">{{ u.phone || '—' }}</p>
          </div>
          <button
            v-if="!u.is_placeholder && u.id !== profile?.id && u.status === 'approved'"
            class="btn btn-sm btn-neutral"
            @click="toggleAdmin(u)"
          >
            {{ u.role === 'admin' ? '관리자 해제' : '관리자 지정' }}
          </button>
          <button
            v-if="u.id !== profile?.id"
            class="grid h-9 w-9 place-items-center rounded-full text-grey-400 active:bg-grey-100"
            aria-label="삭제"
            @click="remove(u)"
          >
            <AppIcon name="x" :size="18" />
          </button>
        </li>
      </ul>
    </div>

    <BottomSheet v-model="addOpen" title="임시 사용자 추가">
      <p class="mb-4 text-body text-grey-600">
        로그인 없이 이름만으로 근무에 배정할 수 있어요. 같은 이름으로 가입하면 이력을 이어받을 수 있어요.
      </p>
      <input ref="nameInput" v-model="newName" class="field" placeholder="이름" @keyup.enter="createPlaceholder" />
      <button class="btn btn-xl btn-primary mt-6 w-full" @click="createPlaceholder">추가하기</button>
    </BottomSheet>
  </div>
</template>
