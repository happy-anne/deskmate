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

  const error = (m: string) => show(m, 'error')

  return { toasts, show, error }
}
