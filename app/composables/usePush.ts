/**
 * Web push via Firebase Cloud Messaging.
 *
 * FCM is loaded lazily and only if runtimeConfig.public.fcm is filled. Without
 * config we still request the Notification permission and persist a marker so
 * the UI works end-to-end; the actual token registration is a no-op until FCM
 * keys are provided (see .env.example). The token is saved to users.push_token.
 */
export function usePush() {
  const client = useDb()
  const { profile } = useProfile()
  const config = useRuntimeConfig()

  const enabled = useState('push-enabled', () =>
    import.meta.client
      ? typeof Notification !== 'undefined' && Notification.permission === 'granted'
      : false
  )

  async function enable(): Promise<boolean> {
    if (!import.meta.client || typeof Notification === 'undefined') return false

    const perm = await Notification.requestPermission()
    if (perm !== 'granted') {
      enabled.value = false
      return false
    }
    enabled.value = true

    const fcm = config.public.fcm as Record<string, string>
    if (!fcm?.apiKey || !fcm?.vapidKey) {
      // No FCM keys configured — permission granted, token registration skipped.
      return true
    }

    try {
      const token = await registerFcm(fcm)
      if (token && profile.value) {
        await client.from('users').update({ push_token: token }).eq('id', profile.value.id)
      }
    } catch (e) {
      console.warn('FCM registration failed', e)
    }
    return true
  }

  async function registerFcm(fcm: Record<string, string>): Promise<string | null> {
    // Dynamically import so the SDK isn't bundled unless push is actually used.
    const { initializeApp, getApps } = await import('firebase/app')
    const { getMessaging, getToken, onMessage } = await import('firebase/messaging')

    const app = getApps().length ? getApps()[0] : initializeApp(fcm)
    const messaging = getMessaging(app)

    // FCM uses /firebase-messaging-sw.js for background messages.
    const token = await getToken(messaging, { vapidKey: fcm.vapidKey })

    // Foreground messages -> refresh the in-app notification list.
    onMessage(messaging, () => {
      useNotifications().load()
    })
    return token
  }

  return { enabled, enable }
}
