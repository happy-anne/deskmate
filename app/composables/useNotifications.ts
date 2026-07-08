import type { AppNotification } from '~/types/db'

/** In-app notification centre + realtime badge count. */
export function useNotifications() {
  const client = useDb()
  const { profile } = useProfile()

  const items = useState<AppNotification[]>('notifications', () => [])
  const unread = computed(() => items.value.filter((n) => !n.is_read).length)

  async function load() {
    if (!profile.value) return
    const { data } = await client
      .from('notifications')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(100)
    items.value = (data as AppNotification[]) ?? []
  }

  async function markRead(id: string) {
    const n = items.value.find((x) => x.id === id)
    if (!n || n.is_read) return
    n.is_read = true
    await client.from('notifications').update({ is_read: true }).eq('id', id)
  }

  async function markAllRead() {
    const ids = items.value.filter((n) => !n.is_read).map((n) => n.id)
    if (!ids.length) return
    items.value.forEach((n) => (n.is_read = true))
    await client.from('notifications').update({ is_read: true }).in('id', ids)
  }

  let channel: ReturnType<typeof client.channel> | null = null
  function subscribe() {
    if (!import.meta.client || !profile.value || channel) return
    channel = client
      .channel('notifications:' + profile.value.id)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${profile.value.id}`,
        },
        (payload) => {
          items.value = [payload.new as AppNotification, ...items.value]
        }
      )
      .subscribe()
  }

  function unsubscribe() {
    if (channel) {
      client.removeChannel(channel)
      channel = null
    }
  }

  return { items, unread, load, markRead, markAllRead, subscribe, unsubscribe }
}
