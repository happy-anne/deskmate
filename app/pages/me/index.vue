<script setup lang="ts">
const client = useDb()
const { profile, updateProfile } = useProfile()
const pin = usePinLock()
const push = usePush()
const { show, error: toastError } = useToast()

onMounted(() => pin.init())

// ---- profile edit ----
const editOpen = ref(false)
const editName = ref('')
const editPhone = ref('')
function openEdit() {
  editName.value = profile.value?.name ?? ''
  editPhone.value = profile.value?.phone ?? ''
  editOpen.value = true
}
async function saveProfile() {
  try {
    await updateProfile({ name: editName.value.trim(), phone: editPhone.value.trim() })
    show('저장했어요')
    editOpen.value = false
  } catch (e: any) {
    toastError(e.message)
  }
}

// ---- pin ----
const pinOpen = ref(false)
const newPin = ref('')
const confirmPin = ref('')
function savePin() {
  if (newPin.value !== confirmPin.value) return toastError('PIN이 일치하지 않아요')
  try {
    pin.setPin(newPin.value)
    show('PIN을 설정했어요')
    pinOpen.value = false
    newPin.value = confirmPin.value = ''
  } catch (e: any) {
    toastError(e.message)
  }
}
function togglePin(on: boolean) {
  if (on && !pin.hasPin.value) {
    pinOpen.value = true
    return
  }
  pin.setEnabled(on)
  show(on ? 'PIN 잠금을 켰어요' : 'PIN 잠금을 껐어요')
}

async function enablePush() {
  const ok = await push.enable()
  show(ok ? '알림을 켰어요' : '알림 권한이 필요해요', ok ? 'default' : 'error')
}

async function logout() {
  await client.auth.signOut()
  navigateTo('/login', { replace: true })
}
</script>

<template>
  <div>
    <AppHeader title="내정보" />

    <div class="mx-auto max-w-app space-y-3 px-4 pb-6 pt-1">
      <!-- Profile -->
      <div class="card flex items-center gap-4 p-5">
        <div class="grid h-14 w-14 place-items-center rounded-full bg-primary/10 text-primary">
          <AppIcon name="user" :size="28" />
        </div>
        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-2">
            <p class="truncate text-heading text-ink">{{ profile?.name }}</p>
            <span v-if="profile?.role === 'admin'" class="badge badge-blue">관리자</span>
          </div>
          <p class="text-body text-grey-500 tnum">{{ profile?.phone || '번호 미등록' }}</p>
        </div>
        <button class="btn btn-sm btn-neutral" @click="openEdit">수정</button>
      </div>

      <!-- Security -->
      <div class="overflow-hidden rounded-xl bg-white shadow-card">
        <div class="flex items-center justify-between px-5 py-4">
          <div class="flex items-center gap-3">
            <AppIcon name="lock" :size="20" class="text-grey-600" />
            <div>
              <p class="text-body-lg font-medium text-ink">PIN 잠금</p>
              <p class="text-body-sm text-grey-500">15분 미사용 시 자동 잠금</p>
            </div>
          </div>
          <button
            role="switch"
            :aria-checked="pin.enabled.value"
            class="relative h-7 w-12 rounded-full transition-colors"
            :class="pin.enabled.value ? 'bg-primary' : 'bg-grey-300'"
            @click="togglePin(!pin.enabled.value)"
          >
            <span
              class="absolute top-1 h-5 w-5 rounded-full bg-white shadow transition-all"
              :class="pin.enabled.value ? 'left-6' : 'left-1'"
            />
          </button>
        </div>
        <button
          class="flex w-full items-center justify-between border-t border-grey-100 px-5 py-4 active:bg-grey-50"
          @click="pinOpen = true"
        >
          <span class="text-body-lg text-ink">PIN 변경</span>
          <AppIcon name="chevron-right" :size="20" class="text-grey-400" />
        </button>
      </div>

      <!-- Notifications -->
      <div class="overflow-hidden rounded-xl bg-white shadow-card">
        <button
          class="flex w-full items-center justify-between px-5 py-4 active:bg-grey-50"
          @click="enablePush"
        >
          <div class="flex items-center gap-3">
            <AppIcon name="bell" :size="20" class="text-grey-600" />
            <span class="text-body-lg text-ink">푸시 알림 켜기</span>
          </div>
          <span class="badge" :class="push.enabled.value ? 'badge-green' : 'badge-grey'">
            {{ push.enabled.value ? '켜짐' : '꺼짐' }}
          </span>
        </button>
      </div>

      <!-- Admin -->
      <NuxtLink
        v-if="profile?.role === 'admin'"
        to="/admin"
        class="flex items-center justify-between rounded-xl bg-white px-5 py-4 shadow-card active:bg-grey-50"
      >
        <div class="flex items-center gap-3">
          <AppIcon name="shield" :size="20" class="text-grey-600" />
          <span class="text-body-lg text-ink">관리자 메뉴</span>
        </div>
        <AppIcon name="chevron-right" :size="20" class="text-grey-400" />
      </NuxtLink>

      <button class="btn btn-lg btn-ghost mt-2 w-full text-grey-500" @click="logout">
        <AppIcon name="logout" :size="20" /> 로그아웃
      </button>
    </div>

    <!-- Edit profile sheet -->
    <BottomSheet v-model="editOpen" title="내 정보 수정">
      <label class="mb-2 block text-body font-medium text-grey-700">이름</label>
      <input v-model="editName" class="field mb-4" />
      <label class="mb-2 block text-body font-medium text-grey-700">휴대폰 번호</label>
      <input v-model="editPhone" class="field tnum" inputmode="tel" />
      <button class="btn btn-xl btn-primary mt-6 w-full" @click="saveProfile">저장하기</button>
    </BottomSheet>

    <!-- PIN change sheet -->
    <BottomSheet v-model="pinOpen" title="PIN 변경">
      <p class="mb-4 text-body text-grey-600">잠금 해제에 사용할 4자리 숫자를 정해주세요.</p>
      <label class="mb-2 block text-body font-medium text-grey-700">새 PIN</label>
      <input
        v-model="newPin"
        class="field tnum mb-4 text-center tracking-[0.5em]"
        inputmode="numeric"
        maxlength="4"
        type="password"
      />
      <label class="mb-2 block text-body font-medium text-grey-700">PIN 확인</label>
      <input
        v-model="confirmPin"
        class="field tnum text-center tracking-[0.5em]"
        inputmode="numeric"
        maxlength="4"
        type="password"
      />
      <button
        class="btn btn-xl btn-primary mt-6 w-full"
        :disabled="newPin.length !== 4"
        @click="savePin"
      >
        설정하기
      </button>
    </BottomSheet>
  </div>
</template>
