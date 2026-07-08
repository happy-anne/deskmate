<script setup lang="ts">
definePageMeta({ layout: 'blank' })
// Supabase parses the magic-link token from the URL, then we route onward.
const authUser = useSupabaseUser()

watch(
  authUser,
  (u) => {
    if (u) navigateTo('/schedule', { replace: true })
  },
  { immediate: true }
)
</script>

<template>
  <div class="grid min-h-dvh place-items-center">
    <p class="text-body text-grey-500">로그인 중…</p>
  </div>
</template>
