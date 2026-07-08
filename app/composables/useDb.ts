import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database'

/** Strongly-typed Supabase client (rows/inserts/rpc are typed via Database). */
export function useDb() {
  return useSupabaseClient() as unknown as SupabaseClient<Database>
}
