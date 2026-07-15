<script setup lang="ts">
import type { Schedule } from '~/types/db'

const req = useRequests()
const swap = useSwap()
const sched = useSchedule()
const { profile } = useProfile()
const { show, error: toastError } = useToast()

// 알림 딥링크 등에서 ?tab=recruit 로 진입하면 해당 탭을 연다.
const initialTab = useRoute().query.tab
const tab = ref<'received' | 'sent' | 'recruit'>(
  initialTab === 'sent' || initialTab === 'recruit' ? initialTab : 'received'
)

await useAsyncData('requests', async () => {
  await req.load()
  if (!sched.schedules.value.length) await sched.load()
  return true
})
onMounted(() => req.subscribe())
onBeforeUnmount(() => req.unsubscribe())

const meId = computed(() => profile.value?.id ?? null)
const myShifts = computed(() =>
  sched.schedules.value.filter((s) => s.user_id === meId.value && !s.is_pinned)
)

const STATUS: Record<string, { label: string; cls: string }> = {
  pending: { label: '대기 중', cls: 'badge-yellow' },
  completed: { label: '완료', cls: 'badge-green' },
  rejected: { label: '거절됨', cls: 'badge-red' },
  cancelled: { label: '취소됨', cls: 'badge-grey' },
}

async function act(fn: Promise<void>, ok: string) {
  try {
    await fn
    show(ok)
    await req.load()
    await sched.load()
  } catch (e: any) {
    toastError(e.message)
  }
}

function shiftLabel(s: Schedule) {
  const ev = sched.events.value.find((e) => e.id === s.event_id)
  return ev ? `${ev.week_label} ${s.slot_no}번` : `${s.slot_no}번`
}

// ---- Apply-to-recruit sheet ----
const applyOpen = ref(false)
const applyTarget = ref<any>(null)
function openApply(recruit: any) {
  applyTarget.value = recruit
  applyOpen.value = true
}
async function applyWith(mine: Schedule) {
  try {
    await swap.applyRecruit(applyTarget.value.id, mine)
    show('모집에 지원했어요')
    applyOpen.value = false
    await req.load()
  } catch (e: any) {
    toastError(e.message)
  }
}
</script>

<template>
  <div>
    <AppHeader title="요청" />

    <div class="mx-auto max-w-app px-4 pb-2 pt-1">
      <div class="segment">
        <button
          class="segment-item"
          :class="tab === 'received' && 'segment-item-active'"
          @click="tab = 'received'"
        >
          받은 요청
          <span v-if="req.received.value.filter(r=>r.status==='pending').length" class="text-primary">
            {{ req.received.value.filter(r=>r.status==='pending').length }}
          </span>
        </button>
        <button class="segment-item" :class="tab === 'sent' && 'segment-item-active'" @click="tab = 'sent'">
          보낸 요청
        </button>
        <button class="segment-item" :class="tab === 'recruit' && 'segment-item-active'" @click="tab = 'recruit'">
          교환 모집
        </button>
      </div>
    </div>

    <div class="mx-auto max-w-app space-y-3 px-4 pb-6 pt-2">
      <!-- RECEIVED -->
      <template v-if="tab === 'received'">
        <div v-if="!req.received.value.length" class="py-16 text-center text-body text-grey-500">
          받은 교환 요청이 없어요.
        </div>
        <div v-for="r in req.received.value" :key="r.id" class="card p-4">
          <div class="mb-3 flex items-center justify-between">
            <span class="text-body-lg font-semibold text-ink">{{ r.requester?.name }}님의 요청</span>
            <span class="badge" :class="STATUS[r.status]?.cls">{{ STATUS[r.status]?.label }}</span>
          </div>
          <div class="flex items-center gap-3 rounded-xl bg-grey-50 p-3">
            <div class="flex-1 text-center">
              <p class="text-caption text-grey-500">받는 근무</p>
              <p class="text-body-lg font-semibold text-ink">{{ schedLabel(r.requester_schedule) }}</p>
              <p class="text-body-sm text-grey-500">{{ r.requester?.name }}</p>
            </div>
            <AppIcon name="swap" :size="20" class="text-grey-400" />
            <div class="flex-1 text-center">
              <p class="text-caption text-grey-500">주는 근무</p>
              <p class="text-body-lg font-semibold text-primary">{{ schedLabel(r.target_schedule) }}</p>
              <p class="text-body-sm text-grey-500">나</p>
            </div>
          </div>
          <p v-if="r.message" class="mt-3 rounded-lg bg-grey-50 px-3 py-2 text-body text-grey-600">
            "{{ r.message }}"
          </p>
          <div v-if="r.status === 'pending'" class="mt-3 flex gap-2">
            <button class="btn btn-lg btn-neutral flex-1" @click="act(swap.reject(r.id), '요청을 거절했어요')">거절</button>
            <button class="btn btn-lg btn-primary flex-[2]" @click="act(swap.accept(r.id), '교환이 완료됐어요')">수락하기</button>
          </div>
        </div>
      </template>

      <!-- SENT -->
      <template v-else-if="tab === 'sent'">
        <div v-if="!req.sent.value.length" class="py-16 text-center text-body text-grey-500">
          보낸 교환 요청이 없어요.
        </div>
        <div v-for="r in req.sent.value" :key="r.id" class="card p-4">
          <div class="mb-3 flex items-center justify-between">
            <span class="text-body-lg font-semibold text-ink">{{ r.target?.name }}님에게</span>
            <span class="badge" :class="STATUS[r.status]?.cls">{{ STATUS[r.status]?.label }}</span>
          </div>
          <div class="flex items-center gap-3 rounded-xl bg-grey-50 p-3">
            <div class="flex-1 text-center">
              <p class="text-caption text-grey-500">내 근무</p>
              <p class="text-body-lg font-semibold text-primary">{{ schedLabel(r.requester_schedule) }}</p>
            </div>
            <AppIcon name="swap" :size="20" class="text-grey-400" />
            <div class="flex-1 text-center">
              <p class="text-caption text-grey-500">상대 근무</p>
              <p class="text-body-lg font-semibold text-ink">{{ schedLabel(r.target_schedule) }}</p>
            </div>
          </div>
          <button
            v-if="r.status === 'pending'"
            class="btn btn-md btn-weak mt-3 w-full"
            @click="act(swap.cancel(r.id), '요청을 취소했어요')"
          >
            요청 취소
          </button>
        </div>
      </template>

      <!-- RECRUIT -->
      <template v-else>
        <!-- My recruits -->
        <div v-if="req.myRecruits.value.length">
          <p class="px-1 pb-1 text-body font-semibold text-grey-700">내가 연 모집</p>
          <div v-for="r in req.myRecruits.value" :key="r.id" class="card mb-3 p-4">
            <div class="mb-2 flex items-center justify-between">
              <span class="text-body-lg font-semibold text-ink">{{ schedLabel(r.requester_schedule) }}</span>
              <span class="badge" :class="STATUS[r.status]?.cls">{{ STATUS[r.status]?.label }}</span>
            </div>
            <p v-if="r.message" class="mb-2 text-body text-grey-600">"{{ r.message }}"</p>
            <div v-if="req.applications.value[r.id]?.length" class="space-y-2">
              <div
                v-for="a in req.applications.value[r.id]"
                :key="a.id"
                class="flex items-center justify-between rounded-lg bg-grey-50 px-3 py-2"
              >
                <div>
                  <p class="text-body-lg font-medium text-ink">{{ a.applicant?.name }}</p>
                  <p class="text-body-sm text-grey-500">{{ schedLabel(a.applicant_schedule) }} 근무 제시</p>
                </div>
                <button
                  v-if="r.status === 'pending' && a.status === 'pending'"
                  class="btn btn-sm btn-primary"
                  @click="act(swap.approveApplicant(a.id), '모집을 승인했어요')"
                >
                  승인
                </button>
                <span v-else class="badge" :class="a.status==='approved' ? 'badge-green':'badge-grey'">
                  {{ a.status === 'approved' ? '승인됨' : '마감' }}
                </span>
              </div>
            </div>
            <p v-else class="text-body-sm text-grey-500">아직 지원자가 없어요.</p>
          </div>
        </div>

        <!-- Open board -->
        <p
          v-if="req.openRecruits.value.length"
          class="px-1 pb-1 pt-1 text-body font-semibold text-grey-700"
        >
          모집 중인 근무
        </p>
        <div v-if="!req.openRecruits.value.length" class="py-10 text-center text-body text-grey-500">
          지금 모집 중인 교환이 없어요.
        </div>
        <div v-for="r in req.openRecruits.value" :key="r.id" class="card mb-3 p-4">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-body-lg font-semibold text-ink">{{ schedLabel(r.requester_schedule) }}</p>
              <p class="text-body-sm text-grey-500">{{ r.requester?.name }}님이 모집</p>
            </div>
            <button class="btn btn-md btn-primary" @click="openApply(r)">지원하기</button>
          </div>
          <p v-if="r.message" class="mt-2 text-body text-grey-600">"{{ r.message }}"</p>
        </div>
      </template>
    </div>

    <!-- Apply sheet -->
    <BottomSheet v-model="applyOpen" title="어떤 근무로 지원할까요?">
      <div v-if="myShifts.length" class="space-y-2">
        <button
          v-for="m in myShifts"
          :key="m.id"
          class="card-compact flex w-full items-center justify-between px-4 py-3 text-left active:bg-grey-50"
          @click="applyWith(m)"
        >
          <span class="text-body-lg font-medium text-ink">{{ shiftLabel(m) }}</span>
          <AppIcon name="arrowRight" :size="18" class="text-grey-400" />
        </button>
      </div>
      <p v-else class="rounded-xl bg-grey-50 p-4 text-body text-grey-600">
        지원할 수 있는 내 근무가 없어요.
      </p>
    </BottomSheet>
  </div>
</template>
