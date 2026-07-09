<script setup lang="ts">
const client = useDb()

const { data: rows } = await useAsyncData('history', async () => {
  const { data } = await client
    .from('swap_history')
    .select(
      '*, schedule:schedules(*, event:events(*)), before_user:users!before_user_id(id,name), after_user:users!after_user_id(id,name)'
    )
    .order('completed_at', { ascending: false })
    .limit(200)
  return data ?? []
})

// Group the per-cell rows back into one entry per completed swap.
const groups = computed(() => {
  const map = new Map<string, any[]>()
  for (const r of rows.value ?? []) {
    const key = r.request_id ?? r.id
    ;(map.get(key) ?? map.set(key, []).get(key)!).push(r)
  }
  return [...map.values()].map((moves) => ({
    at: moves[0].completed_at,
    moves,
  }))
})

function label(r: any) {
  const s = r.schedule
  if (!s) return '-'
  return `${s.event?.week_label ?? ''} ${s.slot_no}번`.trim()
}
</script>

<template>
  <div>
    <AppHeader title="변경내역" />

    <div class="mx-auto max-w-app space-y-3 px-4 pb-6 pt-2">
      <div v-if="!groups.length" class="py-16 text-center">
        <div class="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-grey-100 text-grey-400">
          <AppIcon name="history" :size="28" />
        </div>
        <p class="mt-4 text-body-lg text-grey-700">아직 변경 이력이 없어요</p>
        <p class="mt-1 text-body text-grey-500">근무를 교환하면 여기에 기록돼요.</p>
      </div>

      <div v-for="(g, i) in groups" :key="i" class="card p-4">
        <div class="mb-2 flex items-center gap-2">
          <span class="badge badge-yellow">변경됨</span>
          <span class="text-body-sm text-grey-500 tnum">{{ timeAgo(g.at) }}</span>
        </div>
        <div class="space-y-2">
          <div
            v-for="m in g.moves"
            :key="m.id"
            class="flex items-center gap-2 text-body-lg"
          >
            <span class="w-16 shrink-0 font-semibold text-ink">{{ label(m) }}</span>
            <span class="text-grey-500 line-through">{{ m.before_user?.name ?? '미배정' }}</span>
            <AppIcon name="arrowRight" :size="16" class="text-grey-400" />
            <span class="font-semibold text-primary">{{ m.after_user?.name ?? '미배정' }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
