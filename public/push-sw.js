/* global self, clients */
// Web Push handlers, imported into the Workbox-generated service worker
// (see nuxt.config.ts → pwa.workbox.importScripts). Displays the push payload
// sent by /api/push/send and routes the click to the right in-app screen.

self.addEventListener('push', (event) => {
  let title = 'DeskMate'
  let body = ''
  let url = '/notifications'

  if (event.data) {
    try {
      const data = event.data.json()
      if (data.title) title = data.title
      if (data.body) body = data.body
      if (data.url) url = data.url
    } catch {
      body = event.data.text()
    }
  }

  event.waitUntil(
    self.registration.showNotification(title, {
      body,
      icon: '/icons/icon-192.png',
      badge: '/icons/icon-192.png',
      data: { url },
    })
  )
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const url = event.notification.data?.url ?? '/notifications'
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      const existing = list.find((c) => 'focus' in c)
      if (existing) {
        existing.navigate?.(url)
        return existing.focus()
      }
      return clients.openWindow(url)
    })
  )
})
