import type { Schedule, SwapRequest, RecruitApplication } from '~/types/db'

/** Swap (지정 교환) & recruit (교환 모집) actions. */
export function useSwap() {
  const client = useDb()
  const { profile } = useProfile()

  /** 지정 교환 요청 생성: 내 근무 <-> 상대 근무 */
  async function requestDirect(mine: Schedule, target: Schedule, message = '') {
    if (!profile.value) throw new Error('로그인이 필요해요')
    if (mine.is_pinned || target.is_pinned)
      throw new Error('이 근무는 교환할 수 없어요')
    if (!target.user_id) throw new Error('상대 근무에 담당자가 없어요')

    const { data, error } = await client
      .from('swap_requests')
      .insert({
        type: 'direct',
        requester_id: profile.value.id,
        target_user_id: target.user_id,
        requester_schedule_id: mine.id,
        target_schedule_id: target.id,
        message: message || null,
        status: 'pending',
      })
      .select()
      .single()
    if (error) throw error
    return data as SwapRequest
  }

  /** 교환 모집 등록: 내 근무를 열어 누구든 지원 */
  async function openRecruit(mine: Schedule, message = '') {
    if (!profile.value) throw new Error('로그인이 필요해요')
    if (mine.is_pinned) throw new Error('이 근무는 교환할 수 없어요')

    const { data, error } = await client
      .from('swap_requests')
      .insert({
        type: 'recruit',
        requester_id: profile.value.id,
        requester_schedule_id: mine.id,
        message: message || null,
        status: 'pending',
      })
      .select()
      .single()
    if (error) throw error
    return data as SwapRequest
  }

  /** 교환 모집에 지원 (내 근무를 걸고) */
  async function applyRecruit(requestId: string, mine: Schedule) {
    if (!profile.value) throw new Error('로그인이 필요해요')
    if (mine.is_pinned) throw new Error('이 근무는 교환할 수 없어요')
    const { data, error } = await client
      .from('recruit_applications')
      .insert({
        request_id: requestId,
        applicant_id: profile.value.id,
        applicant_schedule_id: mine.id,
      })
      .select()
      .single()
    if (error) throw error
    return data as RecruitApplication
  }

  const accept = async (id: string) => {
    const { error } = await client.rpc('accept_swap', { p_request_id: id })
    if (error) throw new Error(error.message)
  }
  const reject = async (id: string) => {
    const { error } = await client.rpc('reject_swap', { p_request_id: id })
    if (error) throw new Error(error.message)
  }
  const approveApplicant = async (id: string) => {
    const { error } = await client.rpc('approve_recruit', { p_application_id: id })
    if (error) throw new Error(error.message)
  }

  async function cancel(id: string) {
    const { error } = await client
      .from('swap_requests')
      .update({ status: 'cancelled' })
      .eq('id', id)
    if (error) throw error
  }

  return {
    requestDirect,
    openRecruit,
    applyRecruit,
    accept,
    reject,
    approveApplicant,
    cancel,
  }
}
