-- ============================================================================
-- DeskMate — core schema
-- Postgres / Supabase. Run in the SQL editor or via `supabase db push`.
-- ============================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- users
--   Both real (auth-backed) and placeholder (임시) users live here.
--   Placeholder users have auth_id = null and cannot log in.
-- ---------------------------------------------------------------------------
create table if not exists public.users (
  id             uuid primary key default gen_random_uuid(),
  auth_id        uuid unique references auth.users (id) on delete set null,
  name           text not null,
  phone          text,
  role           text not null default 'user' check (role in ('user', 'admin')),
  is_placeholder boolean not null default false,
  push_token     text,
  created_at      timestamptz not null default now()
);
create index if not exists users_auth_id_idx on public.users (auth_id);
create index if not exists users_name_idx on public.users (lower(name));

-- ---------------------------------------------------------------------------
-- app_settings — single global row controlled by admins
-- ---------------------------------------------------------------------------
create table if not exists public.app_settings (
  id              int primary key default 1 check (id = 1),
  swap_pin_enabled boolean not null default false, -- 교환 불가(핀) 기능 ON/OFF
  updated_at       timestamptz not null default now()
);
insert into public.app_settings (id) values (1) on conflict do nothing;

-- ---------------------------------------------------------------------------
-- time presets  (하절기 / 동절기 ...)
-- ---------------------------------------------------------------------------
create table if not exists public.time_presets (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.preset_slots (
  id         uuid primary key default gen_random_uuid(),
  preset_id  uuid not null references public.time_presets (id) on delete cascade,
  slot_no    int not null,
  start_time time not null,
  end_time   time not null,
  unique (preset_id, slot_no)
);

-- ---------------------------------------------------------------------------
-- events — one working day. Grouped by month (YYYY-MM).
-- ---------------------------------------------------------------------------
create table if not exists public.events (
  id         uuid primary key default gen_random_uuid(),
  month      text not null,                 -- 'YYYY-MM'
  date       date not null,
  week_label text not null,                 -- '1주', '2주' ...
  type       text not null default '토요일', -- 근무 유형 (토요일 / 특별근무 ...)
  preset_id  uuid references public.time_presets (id) on delete set null,
  slot_count int not null default 4,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists events_month_idx on public.events (month, sort_order);

-- ---------------------------------------------------------------------------
-- schedules — a single assignment: (event, slot_no, position) -> user
--   Two people per slot => position in (1, 2).
-- ---------------------------------------------------------------------------
create table if not exists public.schedules (
  id         uuid primary key default gen_random_uuid(),
  month      text not null,
  event_id   uuid not null references public.events (id) on delete cascade,
  slot_no    int not null,
  position   int not null default 1 check (position in (1, 2)),
  user_id    uuid references public.users (id) on delete set null,
  is_pinned  boolean not null default false, -- 📌 교환 불가
  is_changed boolean not null default false, -- 교환으로 변경됨 배지
  created_at timestamptz not null default now(),
  unique (event_id, slot_no, position)
);
create index if not exists schedules_event_idx on public.schedules (event_id);
create index if not exists schedules_user_idx on public.schedules (user_id);
create index if not exists schedules_month_idx on public.schedules (month);

-- ---------------------------------------------------------------------------
-- swap_requests — direct (지정 교환) & recruit (교환 모집)
-- ---------------------------------------------------------------------------
create table if not exists public.swap_requests (
  id                   uuid primary key default gen_random_uuid(),
  type                 text not null check (type in ('direct', 'recruit')),
  requester_id         uuid not null references public.users (id) on delete cascade,
  target_user_id       uuid references public.users (id) on delete set null,
  requester_schedule_id uuid references public.schedules (id) on delete set null,
  target_schedule_id   uuid references public.schedules (id) on delete set null,
  message              text,
  status               text not null default 'pending'
                         check (status in ('pending','accepted','rejected','cancelled','completed')),
  created_at           timestamptz not null default now()
);
create index if not exists swap_requester_idx on public.swap_requests (requester_id);
create index if not exists swap_target_idx on public.swap_requests (target_user_id);
create index if not exists swap_status_idx on public.swap_requests (status);

-- ---------------------------------------------------------------------------
-- recruit_applications — 교환 모집 지원
-- ---------------------------------------------------------------------------
create table if not exists public.recruit_applications (
  id                   uuid primary key default gen_random_uuid(),
  request_id           uuid not null references public.swap_requests (id) on delete cascade,
  applicant_id         uuid not null references public.users (id) on delete cascade,
  applicant_schedule_id uuid references public.schedules (id) on delete set null,
  status               text not null default 'pending'
                         check (status in ('pending','approved','rejected')),
  created_at           timestamptz not null default now(),
  unique (request_id, applicant_id)
);
create index if not exists recruit_app_request_idx on public.recruit_applications (request_id);

-- ---------------------------------------------------------------------------
-- swap_history — audit of completed exchanges (per schedule cell)
-- ---------------------------------------------------------------------------
create table if not exists public.swap_history (
  id             uuid primary key default gen_random_uuid(),
  request_id     uuid references public.swap_requests (id) on delete set null,
  schedule_id    uuid references public.schedules (id) on delete set null,
  before_user_id uuid references public.users (id) on delete set null,
  after_user_id  uuid references public.users (id) on delete set null,
  completed_at   timestamptz not null default now()
);
create index if not exists swap_history_schedule_idx on public.swap_history (schedule_id);

-- ---------------------------------------------------------------------------
-- notifications — in-app notification centre (mirrors push payloads)
-- ---------------------------------------------------------------------------
create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users (id) on delete cascade,
  type       text not null,   -- swap_request | recruit_apply | swap_accepted | ...
  title      text not null,
  body       text,
  data       jsonb not null default '{}'::jsonb,
  is_read    boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications (user_id, is_read, created_at desc);
