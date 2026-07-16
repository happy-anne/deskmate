/**
 * "대신해주고 나중에 바꾸기" 되갚음 약속.
 * 되갚음 달(다음 달)이 도래하면 양쪽 모두에게 스케줄 상단 배너로 안내한다.
 *   - 대신해준 사람(coverer): "○○님이 대신해주기로 예정되어 있어요."
 *   - 갚을 사람(covered):    "○○님 대신 하기로 예정되어 있어요."
 * 닫기는 역할별로 독립 저장(dismissed / covered_dismissed).
 */
export function useCover() {
  const client = useDb()
  const { profile } = useProfile()

  const items = useState<any[]>('cover-agreements', () => [])

  async function load() {
    if (!profile.value) return
    const me = profile.value.id
    const { data } = await client
      .from('cover_agreements')
      .select('*, coverer:users!coverer_id(id,name), covered:users!covered_user_id(id,name)')
      .or(`coverer_id.eq.${me},covered_user_id.eq.${me}`)
      .eq('settled', false)
    items.value = data ?? []
  }

  // 되갚음 달이 도래했고, 내 역할 기준으로 아직 안 닫은 약속만 배너로.
  const active = computed(() => {
    const me = profile.value?.id
    const cur = currentMonth()
    return items.value
      .filter((c) => c.return_month <= cur)
      .map((c) => {
        const iAmCoverer = c.coverer_id === me
        return {
          id: c.id,
          role: iAmCoverer ? 'coverer' : 'covered',
          otherName: (iAmCoverer ? c.covered?.name : c.coverer?.name) ?? '상대',
          dismissed: iAmCoverer ? c.dismissed : c.covered_dismissed,
        }
      })
      .filter((c) => !c.dismissed)
  })

  async function dismiss(id: string) {
    items.value = items.value.filter((c) => c.id !== id)
    await client.rpc('dismiss_cover', { p_id: id })
  }

  // 내가 갚아야 할(covered=me) 상대(coverer)의 근무인지 — "대신 해주기" 노출용.
  // 되갚음 달이 도래한 약속만. 반환값은 그 약속(요청에 링크할 id 포함).
  function owedTo(userId: string | null | undefined) {
    const me = profile.value?.id
    if (!userId || !me) return null
    const cur = currentMonth()
    return (
      items.value.find(
        (c) =>
          c.covered_user_id === me &&
          c.coverer_id === userId &&
          c.return_month <= cur
      ) ?? null
    )
  }

  return { items, active, load, dismiss, owedTo }
}
