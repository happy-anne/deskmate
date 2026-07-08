import type {
  ScheduleEvent,
  Schedule,
  PresetSlot,
  TimePreset,
} from '~/types/db'

export interface SlotView {
  slot_no: number
  start: string
  end: string
  cells: Schedule[] // usually 2 (position 1 & 2)
}
export interface EventView {
  event: ScheduleEvent
  slots: SlotView[]
}

/**
 * Loads a month's schedule and shapes it into "week / slot / assignees" view
 * models the way staff actually read the board. Subscribes to realtime so every
 * device shows the same latest board after a swap.
 */
export function useSchedule() {
  const client = useDb()

  const month = useState('sched-month', () => currentMonth())
  const events = useState<ScheduleEvent[]>('sched-events', () => [])
  const schedules = useState<Schedule[]>('sched-rows', () => [])
  const presets = useState<TimePreset[]>('sched-presets', () => [])
  const loading = useState('sched-loading', () => false)

  const presetSlotMap = computed(() => {
    const m = new Map<string, Map<number, PresetSlot>>()
    for (const p of presets.value) {
      const inner = new Map<number, PresetSlot>()
      for (const s of p.slots ?? []) inner.set(s.slot_no, s)
      m.set(p.id, inner)
    }
    return m
  })

  const view = computed<EventView[]>(() => {
    return events.value.map((ev) => {
      const rows = schedules.value.filter((s) => s.event_id === ev.id)
      const times = ev.preset_id ? presetSlotMap.value.get(ev.preset_id) : undefined
      const slots: SlotView[] = []
      for (let n = 1; n <= ev.slot_count; n++) {
        const t = times?.get(n)
        slots.push({
          slot_no: n,
          start: t ? hhmm(t.start_time) : '--:--',
          end: t ? hhmm(t.end_time) : '--:--',
          cells: rows
            .filter((r) => r.slot_no === n)
            .sort((a, b) => a.position - b.position),
        })
      }
      return { event: ev, slots }
    })
  })

  async function loadPresets() {
    const { data } = await client
      .from('time_presets')
      .select('*, slots:preset_slots(*)')
      .order('created_at')
    presets.value = (data as TimePreset[]) ?? []
  }

  async function load(targetMonth?: string) {
    if (targetMonth) month.value = targetMonth
    loading.value = true
    if (!presets.value.length) await loadPresets()

    // Users only see published months; drafts are admin-only (admin/schedule).
    const { data: evs } = await client
      .from('events')
      .select('*')
      .eq('month', month.value)
      .eq('is_published', true)
      .order('sort_order')
    events.value = (evs as ScheduleEvent[]) ?? []

    const { data: rows } = await client
      .from('schedules')
      .select('*, user:users(id, name)')
      .eq('month', month.value)
    schedules.value = (rows as Schedule[]) ?? []
    loading.value = false
  }

  let channel: ReturnType<typeof client.channel> | null = null
  function subscribe() {
    if (!import.meta.client || channel) return
    channel = client
      .channel('schedules-live')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'schedules' },
        () => load()
      )
      .subscribe()
  }
  function unsubscribe() {
    if (channel) {
      client.removeChannel(channel)
      channel = null
    }
  }

  async function togglePin(row: Schedule, pinned: boolean) {
    row.is_pinned = pinned
    const { error } = await client
      .from('schedules')
      .update({ is_pinned: pinned })
      .eq('id', row.id)
    if (error) {
      row.is_pinned = !pinned
      throw error
    }
  }

  return {
    month,
    events,
    schedules,
    presets,
    view,
    loading,
    load,
    loadPresets,
    subscribe,
    unsubscribe,
    togglePin,
  }
}
