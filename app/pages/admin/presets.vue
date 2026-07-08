<script setup lang="ts">
import type { TimePreset } from '~/types/db'
definePageMeta({ middleware: 'admin' })

const client = useDb()
const { show, error: toastError } = useToast()

const presets = ref<TimePreset[]>([])
async function load() {
  const { data } = await client
    .from('time_presets')
    .select('*, slots:preset_slots(*)')
    .order('created_at')
  presets.value = ((data as TimePreset[]) ?? []).map((p) => ({
    ...p,
    slots: (p.slots ?? []).sort((a, b) => a.slot_no - b.slot_no),
  }))
}
await useAsyncData('admin-presets', load)

const sheetOpen = ref(false)
const editingId = ref<string | null>(null)
const name = ref('')
const slots = ref<{ start: string; end: string }[]>([])

function openCreate() {
  editingId.value = null
  name.value = ''
  slots.value = [
    { start: '08:00', end: '10:00' },
    { start: '10:00', end: '12:00' },
    { start: '12:00', end: '14:00' },
    { start: '14:00', end: '16:00' },
  ]
  sheetOpen.value = true
}
function openEdit(p: TimePreset) {
  editingId.value = p.id
  name.value = p.name
  slots.value = (p.slots ?? []).map((s) => ({
    start: s.start_time.slice(0, 5),
    end: s.end_time.slice(0, 5),
  }))
  if (!slots.value.length) slots.value = [{ start: '', end: '' }]
  sheetOpen.value = true
}

function addSlot() {
  slots.value.push({ start: '', end: '' })
}
function removeSlot(i: number) {
  slots.value.splice(i, 1)
}

async function save() {
  if (name.value.trim().length < 1) return toastError('프리셋 이름을 입력해주세요')
  const rows = slots.value
    .filter((s) => s.start && s.end)
    .map((s, i) => ({ slot_no: i + 1, start_time: s.start, end_time: s.end }))

  let presetId = editingId.value
  if (presetId) {
    const { error } = await client
      .from('time_presets')
      .update({ name: name.value.trim() })
      .eq('id', presetId)
    if (error) return toastError(error.message)
    // Replace slots wholesale — simplest correct edit.
    await client.from('preset_slots').delete().eq('preset_id', presetId)
  } else {
    const { data: p, error } = await client
      .from('time_presets')
      .insert({ name: name.value.trim() })
      .select()
      .single()
    if (error || !p) return toastError(error?.message ?? '오류')
    presetId = p.id
  }

  if (rows.length) {
    const { error: e2 } = await client
      .from('preset_slots')
      .insert(rows.map((r) => ({ ...r, preset_id: presetId })))
    if (e2) return toastError(e2.message)
  }
  show(editingId.value ? '프리셋을 수정했어요' : '프리셋을 추가했어요')
  sheetOpen.value = false
  await load()
}

async function removePreset(id: string) {
  if (!confirm('이 프리셋을 삭제할까요?')) return
  const { error } = await client.from('time_presets').delete().eq('id', id)
  if (error) return toastError(error.message)
  await load()
}
</script>

<template>
  <div>
    <AppHeader title="시간 프리셋" back>
      <template #action>
        <button class="btn btn-sm btn-primary" @click="openCreate">
          <AppIcon name="plus" :size="18" /> 추가
        </button>
      </template>
    </AppHeader>

    <div class="space-y-3 px-4 pb-6 pt-1">
      <div v-if="!presets.length" class="py-16 text-center text-body text-grey-500">
        프리셋이 없어요. 하절기·동절기 시간을 추가해보세요.
      </div>
      <div v-for="p in presets" :key="p.id" class="card p-4">
        <div class="mb-2 flex items-center justify-between">
          <span class="text-subtitle text-ink">{{ p.name }}</span>
          <div class="flex items-center gap-3">
            <button class="text-body-sm font-semibold text-primary" @click="openEdit(p)">수정</button>
            <button class="text-body-sm text-error" @click="removePreset(p.id)">삭제</button>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-2">
          <div
            v-for="s in p.slots"
            :key="s.id"
            class="flex items-center gap-2 rounded-lg bg-grey-50 px-3 py-2"
          >
            <span class="badge badge-blue">{{ s.slot_no }}번</span>
            <span class="text-body text-grey-700 tnum">{{ hhmm(s.start_time) }}~{{ hhmm(s.end_time) }}</span>
          </div>
        </div>
      </div>
    </div>

    <BottomSheet v-model="sheetOpen" :title="editingId ? '프리셋 수정' : '프리셋 추가'">
      <label class="mb-2 block text-body font-medium text-grey-700">이름</label>
      <input v-model="name" class="field mb-4" placeholder="하절기 / 동절기" />

      <p class="mb-2 text-body font-medium text-grey-700">시간 구성</p>
      <div class="space-y-2">
        <div v-for="(s, i) in slots" :key="i" class="flex items-center gap-2">
          <span class="w-8 text-body-sm text-grey-500 tnum">{{ i + 1 }}번</span>
          <input v-model="s.start" type="time" class="field flex-1 tnum py-2.5" />
          <span class="text-grey-400">~</span>
          <input v-model="s.end" type="time" class="field flex-1 tnum py-2.5" />
          <button class="grid h-9 w-9 shrink-0 place-items-center text-grey-400" @click="removeSlot(i)">
            <AppIcon name="x" :size="18" />
          </button>
        </div>
      </div>
      <button class="btn btn-md btn-neutral mt-3 w-full" @click="addSlot">
        <AppIcon name="plus" :size="18" /> 타임 추가
      </button>
      <button class="btn btn-xl btn-primary mt-4 w-full" @click="save">
        {{ editingId ? '수정하기' : '저장하기' }}
      </button>
    </BottomSheet>
  </div>
</template>
