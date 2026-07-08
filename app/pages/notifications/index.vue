<script setup lang="ts">
const notif = useNotifications()
await useAsyncData('notifications', () => notif.load())

const ICON: Record<string, string> = {
  swap_request: 'swap',
  recruit_apply: 'megaphone',
  swap_accepted: 'check',
  swap_rejected: 'x',
  recruit_approved: 'check',
  schedule_published: 'calendar',
}

function open(n: any) {
  notif.markRead(n.id)
  if (n.type === 'swap_request') navigateTo('/requests')
  else if (n.type === 'recruit_apply' || n.type === 'recruit_approved') navigateTo('/requests')
  else if (n.type === 'schedule_published') navigateTo('/schedule')
  else if (n.type === 'swap_accepted') navigateTo('/history')
}
</script>

<template>
  <div>
    <AppHeader title="알림">
      <template #action>
        <button
          v-if="notif.unread.value"
          class="text-body font-semibold text-primary"
          @click="notif.markAllRead()"
        >
          모두 읽음
        </button>
      </template>
    </AppHeader>

    <div class="px-4 pb-6 pt-1">
      <div v-if="!notif.items.value.length" class="py-16 text-center">
        <div class="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-grey-100 text-grey-400">
          <AppIcon name="bell" :size="28" />
        </div>
        <p class="mt-4 text-body-lg text-grey-700">새 알림이 없어요</p>
        <p class="mt-1 text-body text-grey-500">교환 요청과 소식이 여기에 도착해요.</p>
      </div>

      <ul class="divide-y divide-grey-100 overflow-hidden rounded-xl bg-white shadow-card">
        <li
          v-for="n in notif.items.value"
          :key="n.id"
          class="flex cursor-pointer items-start gap-3 px-4 py-3.5 active:bg-grey-50"
          :class="!n.is_read && 'bg-primary/[0.03]'"
          @click="open(n)"
        >
          <div
            class="mt-0.5 grid h-9 w-9 shrink-0 place-items-center rounded-full"
            :class="n.is_read ? 'bg-grey-100 text-grey-500' : 'bg-primary/10 text-primary'"
          >
            <AppIcon :name="ICON[n.type] ?? 'bell'" :size="18" />
          </div>
          <div class="min-w-0 flex-1">
            <p class="text-body-lg font-semibold text-ink">{{ n.title }}</p>
            <p class="text-body text-grey-600">{{ n.body }}</p>
            <p class="mt-0.5 text-caption text-grey-400 tnum">{{ timeAgo(n.created_at) }}</p>
          </div>
          <span v-if="!n.is_read" class="mt-2 h-2 w-2 shrink-0 rounded-full bg-primary" />
        </li>
      </ul>
    </div>
  </div>
</template>
