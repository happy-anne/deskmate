// Minimal Supabase Database typing so the client is strongly typed at call
// sites. Rows mirror app/types/db.ts; Insert/Update are permissive partials.
import type {
  AppUser,
  AppSettings,
  TimePreset,
  PresetSlot,
  ScheduleEvent,
  Schedule,
  SwapRequest,
  RecruitApplication,
  CoverAgreement,
  SwapHistory,
  AppNotification,
  PushSubscription,
} from './db'

type Table<Row> = {
  Row: Row & Record<string, unknown>
  Insert: Partial<Row> & Record<string, unknown>
  Update: Partial<Row> & Record<string, unknown>
  Relationships: []
}

export interface Database {
  public: {
    Tables: {
      users: Table<AppUser>
      app_settings: Table<AppSettings>
      time_presets: Table<TimePreset>
      preset_slots: Table<PresetSlot>
      events: Table<ScheduleEvent>
      schedules: Table<Schedule>
      swap_requests: Table<SwapRequest>
      recruit_applications: Table<RecruitApplication>
      cover_agreements: Table<CoverAgreement>
      swap_history: Table<SwapHistory>
      notifications: Table<AppNotification>
      push_subscriptions: Table<PushSubscription>
    }
    Views: Record<string, never>
    Functions: {
      accept_swap: { Args: { p_request_id: string }; Returns: void }
      reject_swap: { Args: { p_request_id: string }; Returns: void }
      approve_recruit: { Args: { p_application_id: string }; Returns: void }
      dismiss_cover: { Args: { p_id: string }; Returns: void }
      promote_placeholder: {
        Args: { p_placeholder_id: string; p_real_id: string }
        Returns: void
      }
      publish_month: { Args: { p_month: string }; Returns: void }
      current_user_id: { Args: Record<string, never>; Returns: string }
      is_admin: { Args: Record<string, never>; Returns: boolean }
    }
    Enums: Record<string, never>
    CompositeTypes: Record<string, never>
  }
}
