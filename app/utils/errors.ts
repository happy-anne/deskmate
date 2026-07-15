// 화면에 보여줄 에러 문구로 변환한다.
//  - 이미 한글(우리가 의도해서 던진 도메인 메시지)이면 그대로 노출.
//  - 알려진 Supabase/Postgres 영어 에러는 사용자에게 도움되는 한글로 치환.
//  - 그 외 봐도 소용없는 기술 메시지는 일반 문구로 대체하고, 원문은 콘솔에만 남긴다.

const MAP: [string, string][] = [
  // 인증 / 로그인
  ['invalid login credentials', '이메일 또는 비밀번호가 올바르지 않아요'],
  ['email not confirmed', '이메일 인증이 필요해요'],
  ['user already registered', '이미 가입된 이메일이에요. 로그인해주세요'],
  ['already registered', '이미 가입된 이메일이에요. 로그인해주세요'],
  ['email signups are disabled', '지금은 이메일 가입을 받지 않고 있어요'],
  ['signups not allowed', '지금은 가입을 받지 않고 있어요'],
  ['email rate limit exceeded', '메일 전송이 잠시 제한됐어요. 잠시 후 다시 시도해주세요'],
  ['over_email_send_rate_limit', '메일 전송이 잠시 제한됐어요. 잠시 후 다시 시도해주세요'],
  ['for security purposes', '잠시 후 다시 시도해주세요'],
  // 비밀번호
  ['password should be at least', '비밀번호는 6자 이상이어야 해요'],
  ['weak password', '비밀번호가 너무 약해요'],
  ['new password should be different', '이전과 다른 비밀번호를 입력해주세요'],
  ['same_password', '이전과 다른 비밀번호를 입력해주세요'],
  // 링크 / 세션
  ['token has expired', '링크가 만료됐어요. 다시 시도해주세요'],
  ['otp_expired', '링크가 만료됐어요. 다시 시도해주세요'],
  ['invalid or has expired', '링크가 만료됐어요. 다시 시도해주세요'],
  ['jwt expired', '세션이 만료됐어요. 다시 로그인해주세요'],
  ['invalid claim', '세션이 만료됐어요. 다시 로그인해주세요'],
  // 데이터 / 권한
  ['duplicate key value', '이미 등록된 정보예요'],
  ['row-level security', '권한이 없어요'],
  ['permission denied', '권한이 없어요'],
  // 네트워크
  ['failed to fetch', '네트워크 연결을 확인해주세요'],
  ['load failed', '네트워크 연결을 확인해주세요'],
  ['networkerror', '네트워크 연결을 확인해주세요'],
]

const FALLBACK = '문제가 생겼어요. 잠시 후 다시 시도해주세요'

function extractMessage(input: unknown): string {
  if (!input) return ''
  if (typeof input === 'string') return input
  if (input instanceof Error) return input.message
  if (typeof input === 'object') {
    const o = input as Record<string, unknown>
    const v = o.message ?? o.error_description ?? o.error ?? o.hint
    return typeof v === 'string' ? v : ''
  }
  return String(input)
}

export function humanError(input: unknown): string {
  const raw = extractMessage(input).trim()
  if (!raw) return FALLBACK

  // 우리가 직접 던진 한글 메시지는 그대로 보여준다.
  if (/[가-힣]/.test(raw)) return raw

  const lower = raw.toLowerCase()
  for (const [needle, ko] of MAP) {
    if (lower.includes(needle)) return ko
  }

  // 매핑되지 않는 기술적 영어 메시지는 화면에 노출하지 않고 콘솔에만 남긴다.
  if (import.meta.dev) console.warn('[unmapped error]', raw)
  return FALLBACK
}
