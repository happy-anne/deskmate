<script setup lang="ts">
import type { AppUser, ScheduleEvent, Schedule, TimePreset } from '~/types/db'
definePageMeta({ middleware: 'admin' })

const client = useDb()
const { show, error: toastError } = useToast()

const month = ref(currentMonth())
const events = ref<ScheduleEvent[]>([])
const rows = ref<Schedule[]>([])
const presets = ref<TimePreset[]>([])
const users = ref<AppUser[]>([])

async function load() {
  const [{ data: evs }, { data: rs }, { data: ps }, { data: us }] = await Promise.all([
    // Admin sees ALL events (drafts + published).
    client.from('events').select('*').eq('month', month.value).order('sort_order'),
    client.from('schedules').select('*').eq('month', month.value),
    client.from('time_presets').select('*, slots:preset_slots(*)').order('created_at'),
    client.from('users').select('*').order('name'),
  ])
  events.value = (evs as ScheduleEvent[]) ?? []
  rows.value = (rs as Schedule[]) ?? []
  presets.value = (ps as TimePreset[]) ?? []
  users.value = (us as AppUser[]) ?? []
}
await useAsyncData('admin-sched', load)
watch(month, load)

function cellsFor(ev: ScheduleEvent, slot: number) {
  return rows.value
    .filter((r) => r.event_id === ev.id && r.slot_no === slot)
    .sort((a, b) => a.position - b.position)
}
const presetName = (id: string | null) =>
  presets.value.find((p) => p.id === id)?.name ?? '시간 미지정'

const unpublished = computed(() => events.value.filter((e) => !e.is_published))
const allPublished = computed(() => events.value.length > 0 && unpublished.value.length === 0)

// ---- create / edit event ----
const sheetOpen = ref(false)
const editingId = ref<string | null>(null)
const form = ref({
  date: month.value + '-01',
  week_label: '',
  type: '토요일',
  preset_id: '',
  slot_count: 4,
})

function openCreate() {
  editingId.value = null
  form.value = {
    date: month.value + '-01',
    week_label: events.value.length + 1 + '주',
    type: '토요일',
    preset_id: presets.value[0]?.id ?? '',
    slot_count: 4,
  }
  sheetOpen.value = true
}
function openEdit(ev: ScheduleEvent) {
  editingId.value = ev.id
  form.value = {
    date: ev.date,
    week_label: ev.week_label,
    type: ev.type,
    preset_id: ev.preset_id ?? '',
    slot_count: ev.slot_count,
  }
  sheetOpen.value = true
}

async function saveEvent() {
  if (!form.value.week_label.trim()) return toastError('주차를 입력해주세요')
  const patch = {
    date: form.value.date,
    week_label: form.value.week_label.trim(),
    type: form.value.type.trim() || '토요일',
    preset_id: form.value.preset_id || null,
    slot_count: form.value.slot_count,
  }

  if (editingId.value) {
    const ev = events.value.find((e) => e.id === editingId.value)!
    const oldCount = ev.slot_count
    const { error } = await client.from('events').update(patch).eq('id', editingId.value)
    if (error) return toastError(error.message)
    await reconcileCells(editingId.value, oldCount, form.value.slot_count)
    show('근무일을 수정했어요')
  } else {
    const { data: ev, error } = await client
      .from('events')
      .insert({ month: month.value, sort_order: events.value.length + 1, ...patch })
      .select()
      .single()
    if (error || !ev) return toastError(error?.message ?? '오류')
    const cells = []
    for (let s = 1; s <= form.value.slot_count; s++)
      for (let p = 1; p <= 2; p++)
        cells.push({ month: month.value, event_id: ev.id, slot_no: s, position: p })
    await client.from('schedules').insert(cells)
    show('근무일을 추가했어요')
  }
  sheetOpen.value = false
  await load()
}

// Grow/shrink the cell grid when slot_count changes on edit.
async function reconcileCells(eventId: string, oldCount: number, newCount: number) {
  if (newCount > oldCount) {
    const cells = []
    for (let s = oldCount + 1; s <= newCount; s++)
      for (let p = 1; p <= 2; p++)
        cells.push({ month: month.value, event_id: eventId, slot_no: s, position: p })
    if (cells.length) await client.from('schedules').insert(cells)
  } else if (newCount < oldCount) {
    await client
      .from('schedules')
      .delete()
      .eq('event_id', eventId)
      .gt('slot_no', newCount)
  }
}

async function assign(cell: Schedule, userId: string) {
  const val = userId || null
  const { error } = await client.from('schedules').update({ user_id: val }).eq('id', cell.id)
  if (error) return toastError(error.message)
  cell.user_id = val
}

async function removeEvent(ev: ScheduleEvent) {
  if (!confirm(`${ev.week_label} 근무일을 삭제할까요?`)) return
  const { error } = await client.from('events').delete().eq('id', ev.id)
  if (error) return toastError(error.message)
  await load()
}

async function publish() {
  if (!confirm(`${monthLabel(month.value)} 근무표를 공개할까요?\n사용자에게 즉시 노출되고 등록 알림이 전송돼요.`)) return
  const { error } = await client.rpc('publish_month', { p_month: month.value })
  if (error) return toastError(error.message)
  show('근무표를 공개했어요')
  await load()
}

async function resetMonth() {
  if (!confirm(`${monthLabel(month.value)} 전체 근무표를 초기화할까요? 되돌릴 수 없어요.`)) return
  const ids = events.value.map((e) => e.id)
  if (ids.length) await client.from('events').delete().in('id', ids)
  show('근무표를 초기화했어요')
  await load()
}
</script>

<template>
  <div>
    <AppHeader title="근무표 관리" back>
      <template #action>
        <button class="btn btn-sm btn-primary" @click="openCreate">
          <AppIcon name="plus" :size="18" /> 근무일
        </button>
      </template>
    </AppHeader>

    <div class="mx-auto flex max-w-app items-center justify-between px-5 py-2">
      <input v-model="month" type="month" class="field w-44 py-2.5 tnum" />
      <button
        v-if="events.length"
        class="text-body-sm font-semibold text-error"
        @click="resetMonth"
      >
        초기화
      </button>
    </div>

    <!-- Publish bar -->
    <div v-if="events.length" class="mx-auto max-w-app px-4 pb-1">
      <div
        v-if="unpublished.length"
        class="flex items-center justify-between rounded-xl border border-primary/20 bg-primary/[0.06] px-4 py-3"
      >
        <div class="flex items-center gap-2">
          <AppIcon name="megaphone" :size="18" class="text-primary" />
          <span class="text-body text-grey-700">
            미공개 근무일 <b class="text-ink">{{ unpublished.length }}개</b>
          </span>
        </div>
        <button class="btn btn-sm btn-primary" @click="publish">공개하기</button>
      </div>
      <div
        v-else-if="allPublished"
        class="flex items-center gap-2 rounded-xl bg-grey-100 px-4 py-3 text-body text-grey-600"
      >
        <AppIcon name="check" :size="18" class="text-success" />
        공개된 근무표예요. 사용자에게 표시됩니다.
      </div>
    </div>

    <div class="space-y-3 px-4 pb-6 pt-1">
      <div v-if="!events.length" class="py-16 text-center text-body text-grey-500">
        이 달의 근무일이 없어요.<br />오른쪽 위에서 근무일을 추가하세요.
      </div>

      <div v-for="ev in events" :key="ev.id" class="card p-4">
        <div class="mb-3 flex items-center justify-between">
          <div class="flex items-center gap-2">
            <span class="text-subtitle text-ink">{{ ev.week_label }}</span>
            <span class="text-body text-grey-500 tnum">{{ shortDate(ev.date) }}</span>
            <span class="badge" :class="ev.is_published ? 'badge-green' : 'badge-yellow'">
              {{ ev.is_published ? '공개' : '미공개' }}
            </span>
          </div>
          <div class="flex items-center gap-3">
            <button class="text-body-sm font-semibold text-primary" @click="openEdit(ev)">수정</button>
            <button class="text-body-sm text-error" @click="removeEvent(ev)">삭제</button>
          </div>
        </div>
        <div class="mb-3 flex items-center gap-2">
          <span class="badge badge-grey">{{ ev.type }}</span>
          <span class="badge badge-grey">{{ presetName(ev.preset_id) }}</span>
        </div>

        <div class="space-y-2">
          <div v-for="s in ev.slot_count" :key="s" class="flex items-center gap-2">
            <span class="w-8 shrink-0 text-body font-semibold text-grey-700 tnum">{{ s }}번</span>
            <select
              v-for="cell in cellsFor(ev, s)"
              :key="cell.id"
              :value="cell.user_id ?? ''"
              class="field flex-1 py-2.5 text-body-lg"
              @change="assign(cell, ($event.target as HTMLSelectElement).value)"
            >
              <option value="">미배정</option>
              <option v-for="u in users" :key="u.id" :value="u.id">
                {{ u.name }}{{ u.is_placeholder ? ' (임시)' : '' }}
              </option>
            </select>
          </div>
        </div>
      </div>
    </div>

    <BottomSheet v-model="sheetOpen" :title="editingId ? '근무일 수정' : '근무일 추가'">
      <div class="space-y-4">
        <div>
          <label class="mb-2 block text-body font-medium text-grey-700">날짜</label>
          <input v-model="form.date" type="date" class="field tnum" />
        </div>
        <div class="flex gap-3">
          <div class="flex-1">
            <label class="mb-2 block text-body font-medium text-grey-700">주차</label>
            <input v-model="form.week_label" class="field" placeholder="1주" />
          </div>
          <div class="flex-1">
            <label class="mb-2 block text-body font-medium text-grey-700">유형</label>
            <input v-model="form.type" class="field" placeholder="토요일" />
          </div>
        </div>
        <div>
          <label class="mb-2 block text-body font-medium text-grey-700">시간 프리셋</label>
          <select v-model="form.preset_id" class="field text-body-lg">
            <option value="">시간 미지정</option>
            <option v-for="p in presets" :key="p.id" :value="p.id">{{ p.name }}</option>
          </select>
        </div>
        <div>
          <label class="mb-2 block text-body font-medium text-grey-700">타임 개수</label>
          <input v-model.number="form.slot_count" type="number" min="1" max="10" class="field tnum" />
        </div>
      </div>
      <button class="btn btn-xl btn-primary mt-6 w-full" @click="saveEvent">
        {{ editingId ? '수정하기' : '추가하기' }}
      </button>
    </BottomSheet>
  </div>
</template>
