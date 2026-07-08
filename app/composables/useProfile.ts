import type { AppUser, AppSettings } from '~/types/db'

/**
 * Loads and caches the current user's DeskMate profile (public.users row)
 * plus the global app settings. `profile` is null until onboarding completes.
 */
export function useProfile() {
  const client = useDb()
  const authUser = useSupabaseUser()

  const profile = useState<AppUser | null>('profile', () => null)
  const settings = useState<AppSettings | null>('app-settings', () => null)
  const loading = useState('profile-loading', () => false)

  const isAdmin = computed(() => profile.value?.role === 'admin')
  const isApproved = computed(
    () => profile.value?.status === 'approved' || isAdmin.value
  )
  const pinFeatureOn = computed(() => settings.value?.swap_pin_enabled ?? false)

  async function load() {
    if (!authUser.value) {
      profile.value = null
      return
    }
    loading.value = true
    const [{ data: me }, { data: s }] = await Promise.all([
      client
        .from('users')
        .select('*')
        .eq('auth_id', authUser.value.id)
        .maybeSingle(),
      client.from('app_settings').select('*').eq('id', 1).maybeSingle(),
    ])
    profile.value = (me as AppUser) ?? null
    settings.value = (s as AppSettings) ?? null
    loading.value = false
  }

  /** Create the users row (signup / onboarding). Starts as 'pending' approval. */
  async function completeOnboarding(name: string, phone: string) {
    if (!authUser.value) throw new Error('로그인이 필요해요')
    const { data, error } = await client
      .from('users')
      .insert({
        auth_id: authUser.value.id,
        name: name.trim(),
        phone: phone.trim(),
        role: 'user',
        status: 'pending',
        is_placeholder: false,
      })
      .select()
      .single()
    if (error) throw error
    profile.value = data as AppUser
    return data as AppUser
  }

  async function updateProfile(patch: Partial<Pick<AppUser, 'name' | 'phone'>>) {
    if (!profile.value) return
    const { data, error } = await client
      .from('users')
      .update(patch)
      .eq('id', profile.value.id)
      .select()
      .single()
    if (error) throw error
    profile.value = data as AppUser
  }

  return {
    profile,
    settings,
    loading,
    isAdmin,
    isApproved,
    pinFeatureOn,
    load,
    completeOnboarding,
    updateProfile,
  }
}
