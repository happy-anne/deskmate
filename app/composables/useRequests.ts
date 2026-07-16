/**
 * Loads swap requests / recruits with the joined schedule + event + user info
 * needed to render "1주 2번 · 홍길동" style rows. Nested selects use PostgREST
 * FK-column hints because swap_requests references users/schedules twice.
 */
const SELECT = `
  *,
  requester:users!requester_id(id,name),
  target:users!target_user_id(id,name),
  requester_schedule:schedules!requester_schedule_id(*, event:events(*), user:users(id,name)),
  target_schedule:schedules!target_schedule_id(*, event:events(*), user:users(id,name))
`

export function useRequests() {
  const client = useDb()
  const { profile } = useProfile()

  const all = useState<any[]>('requests-all', () => [])
  const applications = useState<Record<string, any[]>>('recruit-apps', () => ({}))
  const loading = useState('requests-loading', () => false)

  const meId = computed(() => profile.value?.id ?? null)

  const sent = computed(() =>
    all.value.filter(
      (r) =>
        r.requester_id === meId.value && (r.type === 'direct' || r.type === 'repay')
    )
  )
  const received = computed(() =>
    all.value.filter(
      (r) =>
        r.target_user_id === meId.value && (r.type === 'direct' || r.type === 'repay')
    )
  )
  const openRecruits = computed(() =>
    all.value.filter(
      (r) =>
        r.type === 'recruit' &&
        r.status === 'pending' &&
        r.requester_id !== meId.value
    )
  )
  const myRecruits = computed(() =>
    all.value.filter((r) => r.type === 'recruit' && r.requester_id === meId.value)
  )

  async function load() {
    if (!profile.value) return
    loading.value = true
    const { data } = await client
      .from('swap_requests')
      .select(SELECT)
      .order('created_at', { ascending: false })
    all.value = data ?? []

    // Applications for recruits I authored.
    const ids = myRecruits.value.map((r) => r.id)
    if (ids.length) {
      const { data: apps } = await client
        .from('recruit_applications')
        .select('*, applicant:users(id,name), applicant_schedule:schedules(*, event:events(*))')
        .in('request_id', ids)
      const grouped: Record<string, any[]> = {}
      for (const a of apps ?? []) {
        ;(grouped[a.request_id] ??= []).push(a)
      }
      applications.value = grouped
    }
    loading.value = false
  }

  let channel: ReturnType<typeof client.channel> | null = null
  function subscribe() {
    if (!import.meta.client || channel) return
    channel = client
      .channel('requests-live')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'swap_requests' },
        () => load()
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'recruit_applications' },
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

  return {
    all,
    applications,
    loading,
    sent,
    received,
    openRecruits,
    myRecruits,
    load,
    subscribe,
    unsubscribe,
  }
}

/** '1주 2번' from a joined schedule row */
export function schedLabel(s: any): string {
  if (!s) return '-'
  const wk = s.event?.week_label ?? ''
  return `${wk} ${s.slot_no}번`.trim()
}
