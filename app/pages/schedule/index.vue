<script setup lang="ts">
import type { Schedule } from '~/types/db'

const { profile, pinFeatureOn } = useProfile()
const sched = useSchedule()
const swap = useSwap()
const { show, error: toastError } = useToast()

const meId = computed(() => profile.value?.id ?? null)

await useAsyncData('schedule-' + sched.month.value, () => sched.load())
onMounted(() => sched.subscribe())
onBeforeUnmount(() => sched.unsubscribe())

function eventOf(s: Schedule) {
  return sched.events.value.find((e) => e.id === s.event_id)
}

// week_label("3주")에서 주차 숫자를 뽑는다. 숫자가 없으면 뒤로 밀리도록 큰 값.
function weekNo(s: Schedule) {
  const n = parseInt(eventOf(s)?.week_label ?? '', 10)
  return Number.isNaN(n) ? Number.MAX_SAFE_INTEGER : n
}

// My shifts this month (for offering in a direct swap), 주차 → 날짜 → 번호 순.
const myShifts = computed(() =>
  sched.schedules.value
    .filter((s) => s.user_id === meId.value)
    .sort(
      (a, b) =>
        weekNo(a) - weekNo(b) ||
        (eventOf(a)?.date ?? '').localeCompare(eventOf(b)?.date ?? '') ||
        a.slot_no - b.slot_no
    )
)

function shiftLabel(s: Schedule) {
  const ev = eventOf(s)
  return ev ? `${ev.week_label} ${s.slot_no}번` : `${s.slot_no}번`
}

// ---- Cell action sheet ------------------------------------------------------
const sheetOpen = ref(false)
const active = ref<Schedule | null>(null)
const mode = ref<'actions' | 'pick-mine'>('actions')
const message = ref('')
const busy = ref(false)

const activeIsMine = computed(() => active.value?.user_id === meId.value)

function openCell(cell: Schedule) {
  active.value = cell
  mode.value = 'actions'
  message.value = ''
  sheetOpen.value = true
}

async function doRecruit() {
  if (!active.value) return
  busy.value = true
  try {
    await swap.openRecruit(active.value, message.value)
    show('교환 모집을 등록했어요')
    sheetOpen.value = false
  } catch (e: any) {
    toastError(e.message)
  } finally {
    busy.value = false
  }
}

async function doPin(pinned: boolean) {
  if (!active.value) return
  try {
    await sched.togglePin(active.value, pinned)
    show(pinned ? '이 근무를 교환 불가로 설정했어요' : '핀을 해제했어요')
    sheetOpen.value = false
  } catch (e: any) {
    toastError(e.message)
  }
}

async function offerMine(mine: Schedule) {
  if (!active.value) return
  busy.value = true
  try {
    await swap.requestDirect(mine, active.value, message.value)
    show('교환 요청을 보냈어요')
    sheetOpen.value = false
  } catch (e: any) {
    toastError(e.message)
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <div>
    <AppHeader title="스케줄">
      <template #action>
        <NuxtLink
          v-if="profile?.role === 'admin'"
          to="/admin"
          class="grid h-9 w-9 place-items-center rounded-full text-grey-600 active:bg-grey-100"
          aria-label="관리자"
        >
          <AppIcon name="shield" :size="22" />
        </NuxtLink>
      </template>
    </AppHeader>

    <!-- Current month -->
    <div class="mx-auto flex max-w-app items-center justify-center px-4 pb-1 pt-1">
      <span class="text-subtitle text-ink tnum">{{ monthLabel(sched.month.value) }}</span>
    </div>

    <div class="mx-auto max-w-app space-y-3 px-4 pb-6 pt-2">
      <!-- Loading skeleton -->
      <template v-if="sched.loading.value && !sched.events.value.length">
        <div v-for="i in 3" :key="i" class="h-40 animate-pulse rounded-xl bg-grey-100" />
      </template>

      <!-- Empty -->
      <div
        v-else-if="!sched.events.value.length"
        class="mt-16 flex flex-col items-center px-6 text-center"
      >
        <div class="grid h-14 w-14 place-items-center rounded-2xl bg-grey-100 text-grey-400">
          <AppIcon name="calendar" :size="28" />
        </div>
        <p class="mt-4 text-body-lg text-grey-700">
          아직 이번 달 스케줄이 없어요
        </p>
        <p class="mt-1 text-body text-grey-500">
          관리자가 스케줄을 등록하면 여기에 표시돼요.
        </p>
      </div>

      <!-- Cards -->
      <ScheduleCard
        v-for="v in sched.view.value"
        :key="v.event.id"
        :view="v"
        :me-id="meId"
        @cell="openCell"
      />

      <p class="px-1 pt-1 text-center text-caption text-grey-400">
        내 이름은 파란색으로 강조돼요 · 셀을 눌러 교환하세요
      </p>
    </div>

    <!-- Cell action sheet -->
    <BottomSheet
      v-model="sheetOpen"
      :title="active ? shiftLabel(active) : ''"
    >
      <template v-if="active">
        <div class="mb-4 rounded-xl bg-grey-50 p-4">
          <p class="text-body-sm text-grey-500">담당</p>
          <p class="text-body-lg font-semibold text-ink">
            {{ active.user?.name ?? '미배정' }}
          </p>
        </div>

        <!-- Pinned: not exchangeable -->
        <div
          v-if="active.is_pinned && !activeIsMine"
          class="flex items-center gap-2 rounded-xl bg-grey-50 p-4 text-body text-grey-600"
        >
          <AppIcon name="pin" :size="18" class="text-grey-400" />
          이 근무는 교환할 수 없어요.
        </div>

        <!-- MODE: actions -->
        <template v-else-if="mode === 'actions'">
          <!-- My cell -->
          <template v-if="activeIsMine">
            <textarea
              v-model="message"
              rows="2"
              placeholder="교환 모집에 남길 메모 (선택)"
              class="field mb-3 resize-none text-body-lg"
            />
            <button class="btn btn-lg btn-primary w-full" :disabled="busy" @click="doRecruit">
              <AppIcon name="megaphone" :size="20" /> 교환 모집 등록
            </button>

            <template v-if="pinFeatureOn">
              <button
                v-if="!active.is_pinned"
                class="btn btn-lg btn-neutral mt-2 w-full"
                @click="doPin(true)"
              >
                <AppIcon name="pin" :size="20" /> 교환 불가로 설정
              </button>
              <button v-else class="btn btn-lg btn-neutral mt-2 w-full" @click="doPin(false)">
                <AppIcon name="pin" :size="20" /> 핀 해제
              </button>
            </template>
          </template>

          <!-- Someone else's cell -->
          <template v-else>
            <button
              class="btn btn-lg btn-primary w-full"
              :disabled="!active.user_id"
              @click="mode = 'pick-mine'"
            >
              <AppIcon name="swap" :size="20" /> 이 근무와 교환하기
            </button>
            <p class="mt-3 text-center text-body-sm text-grey-500">
              내 근무 중 하나를 골라 교환을 요청해요.
            </p>
          </template>
        </template>

        <!-- MODE: pick which of my shifts to offer -->
        <template v-else>
          <p class="mb-2 text-body font-medium text-grey-700">
            어떤 내 근무와 바꿀까요?
          </p>
          <div v-if="myShifts.length" class="space-y-2">
            <textarea
              v-model="message"
              rows="2"
              placeholder="상대에게 남길 메모 (선택)"
              class="field mb-1 resize-none text-body-lg"
            />
            <button
              v-for="m in myShifts.filter((s) => !s.is_pinned)"
              :key="m.id"
              class="card-compact flex w-full items-center justify-between px-4 py-3 text-left active:bg-grey-50"
              :disabled="busy"
              @click="offerMine(m)"
            >
              <span class="text-body-lg font-medium text-ink">{{ shiftLabel(m) }}</span>
              <AppIcon name="arrowRight" :size="18" class="text-grey-400" />
            </button>
          </div>
          <p v-else class="rounded-xl bg-grey-50 p-4 text-body text-grey-600">
            이번 달에 교환할 내 근무가 없어요.
          </p>
          <button class="btn btn-md btn-ghost mt-3 w-full" @click="mode = 'actions'">
            뒤로
          </button>
        </template>
      </template>
    </BottomSheet>
  </div>
</template>
