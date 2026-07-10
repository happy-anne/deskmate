/**
 * Web Push via the standard Push API + VAPID (no Firebase/FCM).
 *
 * On enable() we ask for Notification permission, subscribe through the active
 * service worker with the public VAPID key, and store the subscription
 * (endpoint + keys) in `push_subscriptions` — one row per device. The server
 * route /api/push/send later delivers pushes to those endpoints when a
 * `notifications` row is inserted for the user.
 */
export function usePush() {
  const client = useDb()
  const { profile } = useProfile()
  const config = useRuntimeConfig()

  const enabled = useState('push-enabled', () => false)

  const isSupported = () =>
    import.meta.client &&
    'serviceWorker' in navigator &&
    'PushManager' in window &&
    typeof Notification !== 'undefined'

  // Reflect the real subscription state (permission granted AND subscribed).
  async function refresh() {
    if (!isSupported() || Notification.permission !== 'granted') {
      enabled.value = false
      return
    }
    try {
      const reg = await navigator.serviceWorker.ready
      enabled.value = !!(await reg.pushManager.getSubscription())
    } catch {
      enabled.value = false
    }
  }
  if (import.meta.client) onMounted(refresh)

  function urlBase64ToUint8Array(base64: string): Uint8Array {
    const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4)
    const raw = atob(padded.replace(/-/g, '+').replace(/_/g, '/'))
    return Uint8Array.from([...raw].map((c) => c.charCodeAt(0)))
  }

  async function enable(): Promise<boolean> {
    if (!isSupported() || !profile.value) return false

    const perm = await Notification.requestPermission()
    if (perm !== 'granted') {
      enabled.value = false
      return false
    }

    const vapidPublicKey = config.public.vapidPublicKey as string
    if (!vapidPublicKey) {
      // Keys not configured yet — permission granted but no subscription made.
      return false
    }

    try {
      const reg = await navigator.serviceWorker.ready
      const sub =
        (await reg.pushManager.getSubscription()) ??
        (await reg.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: urlBase64ToUint8Array(vapidPublicKey),
        } as PushSubscriptionOptionsInit))

      const json = sub.toJSON()
      await client.from('push_subscriptions').upsert(
        {
          user_id: profile.value.id,
          endpoint: json.endpoint!,
          p256dh: json.keys?.p256dh ?? null,
          auth: json.keys?.auth ?? null,
        },
        { onConflict: 'user_id,endpoint' }
      )
      enabled.value = true
      return true
    } catch (e) {
      console.warn('Push subscribe failed', e)
      enabled.value = false
      return false
    }
  }

  async function disable(): Promise<void> {
    if (!isSupported()) return
    try {
      const reg = await navigator.serviceWorker.ready
      const sub = await reg.pushManager.getSubscription()
      if (sub) {
        if (profile.value) {
          await client
            .from('push_subscriptions')
            .delete()
            .eq('user_id', profile.value.id)
            .eq('endpoint', sub.endpoint)
        }
        await sub.unsubscribe()
      }
    } finally {
      enabled.value = false
    }
  }

  return { enabled, enable, disable, refresh }
}
