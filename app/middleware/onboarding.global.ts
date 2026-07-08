// Access gate: routes users by auth + profile + approval status.
//   no session      -> Supabase module redirects to /login
//   no profile row  -> /onboarding (complete name/phone; edge/legacy case)
//   status pending  -> /pending (until an admin approves)
//   approved/admin  -> full app
const PUBLIC = ['/login', '/signup', '/confirm', '/reset']

export default defineNuxtRouteMiddleware(async (to) => {
  const authUser = useSupabaseUser()
  if (!authUser.value) return
  if (PUBLIC.includes(to.path)) return

  const { profile, load, isApproved } = useProfile()
  if (!profile.value) await load()

  // Signed in but never created a profile row.
  if (!profile.value) {
    return to.path === '/onboarding' ? undefined : navigateTo('/onboarding')
  }

  // Awaiting approval — only the waiting screen is allowed.
  if (!isApproved.value) {
    return to.path === '/pending' ? undefined : navigateTo('/pending')
  }

  // Approved users shouldn't sit on the gate screens.
  if (to.path === '/pending' || to.path === '/onboarding') {
    return navigateTo('/schedule')
  }
})
