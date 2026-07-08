// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-01-01',
  // Opt into the Nuxt 4 directory structure & behaviour (app/ dir, etc.)
  future: { compatibilityVersion: 4 },

  devtools: { enabled: true },

  modules: [
    '@nuxtjs/tailwindcss',
    '@pinia/nuxt',
    '@vueuse/nuxt',
    '@nuxtjs/supabase',
    '@vite-pwa/nuxt',
  ],

  css: ['~/assets/css/main.css'],

  app: {
    head: {
      title: 'DeskMate',
      viewport:
        'width=device-width, initial-scale=1, viewport-fit=cover, maximum-scale=1, user-scalable=no',
      meta: [
        { name: 'theme-color', content: '#ffffff' },
        { name: 'apple-mobile-web-app-capable', content: 'yes' },
        { name: 'apple-mobile-web-app-status-bar-style', content: 'default' },
        { name: 'apple-mobile-web-app-title', content: 'DeskMate' },
        {
          name: 'description',
          content: '안내 데스크 근무표를 실시간으로 관리하고 교환하세요',
        },
      ],
      link: [
        { rel: 'apple-touch-icon', href: '/icons/icon-192.png' },
      ],
    },
  },

  // @nuxtjs/supabase — redirect handling. Public routes below skip the guard;
  // finer-grained auth is enforced by our own middleware + PIN lock.
  supabase: {
    redirectOptions: {
      login: '/login',
      callback: '/confirm',
      include: undefined,
      exclude: ['/login', '/signup', '/confirm', '/onboarding', '/pending', '/reset'],
      cookieRedirect: false,
    },
  },

  pwa: {
    registerType: 'autoUpdate',
    manifest: {
      name: 'DeskMate — 근무표',
      short_name: 'DeskMate',
      description: '안내 데스크 근무표를 실시간으로 관리하고 교환하세요',
      lang: 'ko',
      theme_color: '#ffffff',
      background_color: '#ffffff',
      display: 'standalone',
      orientation: 'portrait',
      start_url: '/',
      scope: '/',
      icons: [
        { src: '/icons/icon-192.png', sizes: '192x192', type: 'image/png' },
        { src: '/icons/icon-512.png', sizes: '512x512', type: 'image/png' },
        {
          src: '/icons/icon-512-maskable.png',
          sizes: '512x512',
          type: 'image/png',
          purpose: 'maskable',
        },
      ],
    },
    workbox: {
      navigateFallback: '/',
      globPatterns: ['**/*.{js,css,html,png,svg,ico,woff2}'],
    },
    client: { installPrompt: true },
    devOptions: { enabled: true, type: 'module' },
  },

  runtimeConfig: {
    public: {
      // FCM web push config — filled from env at build/runtime.
      fcm: {
        apiKey: '',
        authDomain: '',
        projectId: '',
        messagingSenderId: '',
        appId: '',
        vapidKey: '',
      },
    },
  },

  typescript: { strict: true },
})
