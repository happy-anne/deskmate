<script setup lang="ts">
definePageMeta({ middleware: 'admin' })

const client = useDb()
const { settings } = useProfile()
const { show, error: toastError } = useToast()

async function togglePin(on: boolean) {
  const prev = settings.value?.swap_pin_enabled
  if (settings.value) settings.value.swap_pin_enabled = on
  const { error } = await client
    .from('app_settings')
    .update({ swap_pin_enabled: on, updated_at: new Date().toISOString() })
    .eq('id', 1)
  if (error) {
    if (settings.value) settings.value.swap_pin_enabled = !!prev
    return toastError(error.message)
  }
  show(on ? '교환 불가 기능을 켰어요' : '교환 불가 기능을 껐어요')
}

// Count pending signups to badge the 사용자 관리 menu item.
const { data: pendingCount } = await useAsyncData('admin-pending-count', async () => {
  const { count } = await client
    .from('users')
    .select('id', { count: 'exact', head: true })
    .eq('is_placeholder', false)
    .eq('status', 'pending')
  return count ?? 0
})

const menu = computed(() => [
  {
    to: '/admin/users',
    icon: 'users',
    title: '사용자 관리',
    desc: '가입 승인·임시 사용자 관리',
    badge: pendingCount.value || 0,
  },
  { to: '/admin/schedule', icon: 'calendar', title: '근무표 관리', desc: '월 생성·근무일·배정·공개', badge: 0 },
  { to: '/admin/presets', icon: 'settings', title: '시간 프리셋', desc: '하절기·동절기 시간 구성', badge: 0 },
])
</script>

<template>
  <div>
    <AppHeader title="관리자" back />

    <div class="space-y-3 px-4 pb-6 pt-1">
      <!-- 교환 불가 기능 -->
      <div class="card flex items-center justify-between p-5">
        <div>
          <p class="text-body-lg font-semibold text-ink">교환 불가 기능</p>
          <p class="mt-0.5 text-body-sm text-grey-500">
            사용자가 근무에 핀을 걸어 교환에서 제외할 수 있어요
          </p>
        </div>
        <button
          role="switch"
          :aria-checked="settings?.swap_pin_enabled"
          class="relative h-7 w-12 shrink-0 rounded-full transition-colors"
          :class="settings?.swap_pin_enabled ? 'bg-primary' : 'bg-grey-300'"
          @click="togglePin(!settings?.swap_pin_enabled)"
        >
          <span
            class="absolute top-1 h-5 w-5 rounded-full bg-white shadow transition-all"
            :class="settings?.swap_pin_enabled ? 'left-6' : 'left-1'"
          />
        </button>
      </div>

      <NuxtLink
        v-for="m in menu"
        :key="m.to"
        :to="m.to"
        class="flex items-center gap-4 rounded-xl bg-white p-5 shadow-card active:bg-grey-50"
      >
        <div class="grid h-11 w-11 place-items-center rounded-xl bg-primary/10 text-primary">
          <AppIcon :name="m.icon" :size="22" />
        </div>
        <div class="flex-1">
          <p class="text-body-lg font-semibold text-ink">{{ m.title }}</p>
          <p class="text-body-sm text-grey-500">{{ m.desc }}</p>
        </div>
        <span v-if="m.badge" class="badge badge-fill-blue">{{ m.badge }}</span>
        <AppIcon name="chevron-right" :size="20" class="text-grey-400" />
      </NuxtLink>
    </div>
  </div>
</template>
