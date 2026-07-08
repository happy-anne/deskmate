// Route guard for /admin/* — requires the admin role.
export default defineNuxtRouteMiddleware(async () => {
  const { profile, load } = useProfile()
  if (!profile.value) await load()
  if (profile.value?.role !== 'admin') {
    return navigateTo('/schedule', { replace: true })
  }
})
