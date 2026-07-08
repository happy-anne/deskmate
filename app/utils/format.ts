// Small formatting helpers for schedule display.

const WEEKDAYS = ['일', '월', '화', '수', '목', '금', '토']

/** 'HH:MM:SS' -> 'HH:MM' */
export function hhmm(time: string | null | undefined): string {
  if (!time) return '--:--'
  return time.slice(0, 5)
}

/** '2026-08-01' -> '8/1 토' */
export function shortDate(date: string): string {
  const d = new Date(date + 'T00:00:00')
  return `${d.getMonth() + 1}/${d.getDate()} ${WEEKDAYS[d.getDay()]}`
}

/** '2026-08' -> '2026년 8월' */
export function monthLabel(month: string): string {
  const [y, m] = month.split('-')
  return `${y}년 ${Number(m)}월`
}

/** current month as 'YYYY-MM' */
export function currentMonth(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}

/** shift a 'YYYY-MM' by n months */
export function shiftMonth(month: string, n: number): string {
  const [y, m] = month.split('-').map(Number)
  const d = new Date(y ?? 0, (m ?? 1) - 1 + n, 1)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}

/** relative Korean time, e.g. '방금', '3분 전', '2시간 전', '3일 전' */
export function timeAgo(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime()
  const min = Math.floor(diff / 60000)
  if (min < 1) return '방금'
  if (min < 60) return `${min}분 전`
  const hr = Math.floor(min / 60)
  if (hr < 24) return `${hr}시간 전`
  const day = Math.floor(hr / 24)
  if (day < 7) return `${day}일 전`
  const d = new Date(iso)
  return `${d.getMonth() + 1}/${d.getDate()}`
}
