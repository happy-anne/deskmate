<script setup lang="ts">
const { unread } = useNotifications()

const tabs = [
  { to: '/schedule', label: '근무표', icon: 'calendar' },
  { to: '/requests', label: '요청', icon: 'swap' },
  { to: '/history', label: '변경내역', icon: 'history' },
  { to: '/notifications', label: '알림', icon: 'bell', badge: true },
  { to: '/me', label: '내정보', icon: 'user' },
]

const route = useRoute()
const active = (to: string) => route.path.startsWith(to)
</script>

<template>
  <nav
    class="fixed inset-x-0 bottom-0 z-30 mx-auto max-w-app border-t border-grey-200 bg-white/95 pb-[calc(30px+env(safe-area-inset-bottom))] backdrop-blur"
  >
    <ul class="flex">
      <li v-for="t in tabs" :key="t.to" class="flex-1">
        <NuxtLink
          :to="t.to"
          class="relative flex h-14 flex-col items-center justify-center gap-0.5"
          :class="active(t.to) ? 'text-primary' : 'text-grey-400'"
        >
          <div class="relative">
            <AppIcon :name="t.icon" :size="24" />
            <span
              v-if="t.badge && unread > 0"
              class="absolute -right-2 -top-1 grid h-4 min-w-4 place-items-center rounded-full bg-error px-1 text-[10px] font-bold text-white"
            >
              {{ unread > 99 ? '99+' : unread }}
            </span>
          </div>
          <span
            class="text-[11px] font-medium"
            :class="active(t.to) ? 'text-ink' : 'text-grey-500'"
            >{{ t.label }}</span
          >
        </NuxtLink>
      </li>
    </ul>
  </nav>
</template>
