/* global importScripts, firebase */
// Firebase Cloud Messaging background handler.
// Fill in the config below with your Firebase web app values (same as .env),
// then push notifications work while the PWA is backgrounded/closed.
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js')
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js')

const firebaseConfig = {
  apiKey: '',
  authDomain: '',
  projectId: '',
  messagingSenderId: '',
  appId: '',
}

if (firebaseConfig.apiKey) {
  firebase.initializeApp(firebaseConfig)
  const messaging = firebase.messaging()

  messaging.onBackgroundMessage((payload) => {
    const { title, body } = payload.notification || {}
    self.registration.showNotification(title || 'DeskMate', {
      body: body || '',
      icon: '/icons/icon-192.png',
      badge: '/icons/icon-192.png',
      data: payload.data || {},
    })
  })
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  event.waitUntil(clients.openWindow('/notifications'))
})
