interface Toast {
  id: number
  message: string
  tone: 'default' | 'error'
}

let seq = 0

/** Toss-style dark toast, auto-dismiss. Success-of-money is a screen, not a toast. */
export function useToast() {
  const toasts = useState<Toast[]>('toasts', () => [])

  function show(message: string, tone: Toast['tone'] = 'default', ms = 2600) {
    const id = ++seq
    toasts.value = [...toasts.value, { id, message, tone }]
    if (import.meta.client) {
      setTimeout(() => {
        toasts.value = toasts.value.filter((t) => t.id !== id)
      }, ms)
    }
  }

  // 어떤 형태의 에러가 들어와도 사용자용 한글 문구로 바꿔서 보여준다.
  const error = (m: unknown) => show(humanError(m), 'error')

  return { toasts, show, error }
}
