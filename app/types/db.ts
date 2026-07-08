// Shared row types mirroring the Supabase schema (see supabase/migrations).

export type Role = 'user' | 'admin'

export interface AppUser {
  id: string
  auth_id: string | null
  name: string
  phone: string | null
  role: Role
  status: 'pending' | 'approved' | 'rejected'
  is_placeholder: boolean
  push_token: string | null
  created_at: string
}

export interface AppSettings {
  id: number
  swap_pin_enabled: boolean
  updated_at: string
}

export interface TimePreset {
  id: string
  name: string
  created_at: string
  slots?: PresetSlot[]
}

export interface PresetSlot {
  id: string
  preset_id: string
  slot_no: number
  start_time: string // 'HH:MM:SS'
  end_time: string
}

export interface ScheduleEvent {
  id: string
  month: string
  date: string
  week_label: string
  type: string
  preset_id: string | null
  slot_count: number
  sort_order: number
  is_published: boolean
  created_at: string
}

export interface Schedule {
  id: string
  month: string
  event_id: string
  slot_no: number
  position: number
  user_id: string | null
  is_pinned: boolean
  is_changed: boolean
  created_at: string
  user?: Pick<AppUser, 'id' | 'name'> | null
}

export type SwapType = 'direct' | 'recruit'
export type SwapStatus =
  | 'pending'
  | 'accepted'
  | 'rejected'
  | 'cancelled'
  | 'completed'

export interface SwapRequest {
  id: string
  type: SwapType
  requester_id: string
  target_user_id: string | null
  requester_schedule_id: string | null
  target_schedule_id: string | null
  message: string | null
  status: SwapStatus
  created_at: string
}

export interface RecruitApplication {
  id: string
  request_id: string
  applicant_id: string
  applicant_schedule_id: string | null
  status: 'pending' | 'approved' | 'rejected'
  created_at: string
}

export interface SwapHistory {
  id: string
  request_id: string | null
  schedule_id: string | null
  before_user_id: string | null
  after_user_id: string | null
  completed_at: string
}

export interface AppNotification {
  id: string
  user_id: string
  type: string
  title: string
  body: string | null
  data: Record<string, unknown>
  is_read: boolean
  created_at: string
}
