/**
 * "대신해주고 나중에 바꾸기" 되갚음 약속.
 * 내가 대신해준 건들 중, 되갚음 달(다음 달)이 도래했고 아직 안 닫은 것만
 * 스케줄 상단 배너로 안내한다.
 */
export function useCover() {
  const client = useDb()
  const { profile } = useProfile()

  const items = useState<any[]>('cover-agreements', () => [])

  async function load() {
    if (!profile.value) return
    const { data } = await client
      .from('cover_agreements')
      .select('*, covered:users!covered_user_id(id,name)')
      .eq('coverer_id', profile.value.id)
      .eq('dismissed', false)
    items.value = data ?? []
  }

  // 되갚음 달(return_month)이 이번 달 이하이면 배너 노출.
  const active = computed(() => {
    const cur = currentMonth()
    return items.value.filter((c) => c.return_month <= cur)
  })

  async function dismiss(id: string) {
    items.value = items.value.filter((c) => c.id !== id)
    await client.rpc('dismiss_cover', { p_id: id })
  }

  return { items, active, load, dismiss }
}
