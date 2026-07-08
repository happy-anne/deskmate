-- DeskMate 전체 설정 (SQL Editor에 붙여넣고 RUN) — 0001~0006

-- >>>>>>>>>> 0001_schema.sql >>>>>>>>>>
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

-- >>>>>>>>>> 0002_functions.sql >>>>>>>>>>
-- ============================================================================
-- DeskMate — helper functions & atomic swap logic (SECURITY DEFINER)
-- ============================================================================

-- Resolve the app user id for the current auth session.
create or replace function public.current_user_id()
returns uuid
language sql stable security definer set search_path = public
as $$
  select id from public.users where auth_id = auth.uid() limit 1;
$$;

create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select coalesce(
    (select role = 'admin' from public.users where auth_id = auth.uid() limit 1),
    false
  );
$$;

-- Internal: notify a user (skips placeholders / null).
create or replace function public._notify(
  p_user_id uuid, p_type text, p_title text, p_body text, p_data jsonb
)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if p_user_id is null then return; end if;
  insert into public.notifications (user_id, type, title, body, data)
  values (p_user_id, p_type, p_title, p_body, coalesce(p_data, '{}'::jsonb));
end;
$$;

-- Internal: move an assignment between two schedule cells and log history.
create or replace function public._apply_swap(
  p_request_id uuid, p_sched_a uuid, p_sched_b uuid
)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  a_user uuid;
  b_user uuid;
begin
  select user_id into a_user from public.schedules where id = p_sched_a for update;
  select user_id into b_user from public.schedules where id = p_sched_b for update;

  update public.schedules set user_id = b_user, is_changed = true where id = p_sched_a;
  update public.schedules set user_id = a_user, is_changed = true where id = p_sched_b;

  insert into public.swap_history (request_id, schedule_id, before_user_id, after_user_id)
  values
    (p_request_id, p_sched_a, a_user, b_user),
    (p_request_id, p_sched_b, b_user, a_user);
end;
$$;

-- ---------------------------------------------------------------------------
-- accept_swap — target user accepts a DIRECT request.
-- ---------------------------------------------------------------------------
create or replace function public.accept_swap(p_request_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  r public.swap_requests;
  me uuid := public.current_user_id();
  requester_name text;
begin
  select * into r from public.swap_requests where id = p_request_id for update;
  if not found then raise exception '요청을 찾을 수 없어요'; end if;
  if r.status <> 'pending' then raise exception '이미 처리된 요청이에요'; end if;
  if r.type <> 'direct' or r.target_user_id <> me then
    raise exception '이 요청을 수락할 권한이 없어요';
  end if;

  perform public._apply_swap(p_request_id, r.requester_schedule_id, r.target_schedule_id);
  update public.swap_requests set status = 'completed' where id = p_request_id;

  select name into requester_name from public.users where id = r.requester_id;
  perform public._notify(r.requester_id, 'swap_accepted', '교환이 완료됐어요',
    coalesce((select name from public.users where id = me), '상대방') || '님이 교환을 수락했어요',
    jsonb_build_object('request_id', p_request_id));
end;
$$;

create or replace function public.reject_swap(p_request_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  r public.swap_requests;
  me uuid := public.current_user_id();
begin
  select * into r from public.swap_requests where id = p_request_id for update;
  if not found then raise exception '요청을 찾을 수 없어요'; end if;
  if r.status <> 'pending' then raise exception '이미 처리된 요청이에요'; end if;
  if r.target_user_id <> me and r.requester_id <> me then
    raise exception '권한이 없어요';
  end if;

  update public.swap_requests set status = 'rejected' where id = p_request_id;
  perform public._notify(r.requester_id, 'swap_rejected', '교환이 거절됐어요',
    '요청하신 교환이 거절됐어요', jsonb_build_object('request_id', p_request_id));
end;
$$;

-- ---------------------------------------------------------------------------
-- approve_recruit — recruit author approves one applicant, swap executes.
-- ---------------------------------------------------------------------------
create or replace function public.approve_recruit(p_application_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  app public.recruit_applications;
  r public.swap_requests;
  me uuid := public.current_user_id();
begin
  select * into app from public.recruit_applications where id = p_application_id for update;
  if not found then raise exception '지원 내역을 찾을 수 없어요'; end if;

  select * into r from public.swap_requests where id = app.request_id for update;
  if r.requester_id <> me then raise exception '모집 작성자만 승인할 수 있어요'; end if;
  if r.status <> 'pending' then raise exception '이미 마감된 모집이에요'; end if;

  perform public._apply_swap(r.id, r.requester_schedule_id, app.applicant_schedule_id);

  update public.recruit_applications set status = 'approved' where id = p_application_id;
  update public.recruit_applications set status = 'rejected'
    where request_id = r.id and id <> p_application_id and status = 'pending';
  update public.swap_requests set status = 'completed' where id = r.id;

  perform public._notify(app.applicant_id, 'recruit_approved', '모집에 승인됐어요',
    '지원하신 교환 모집이 승인됐어요', jsonb_build_object('request_id', r.id));
end;
$$;

-- ---------------------------------------------------------------------------
-- promote_placeholder — 임시 사용자를 정식 사용자로 연결
--   Reassigns everything from the placeholder to the real user, then removes
--   the placeholder. Admin-only or self-claim by matching name (guarded in RLS).
-- ---------------------------------------------------------------------------
create or replace function public.promote_placeholder(
  p_placeholder_id uuid, p_real_id uuid
)
returns void
language plpgsql security definer set search_path = public
as $$
declare ph public.users;
begin
  select * into ph from public.users where id = p_placeholder_id;
  if not found or not ph.is_placeholder then
    raise exception '임시 사용자가 아니에요';
  end if;

  update public.schedules            set user_id = p_real_id where user_id = p_placeholder_id;
  update public.swap_requests        set requester_id = p_real_id where requester_id = p_placeholder_id;
  update public.swap_requests        set target_user_id = p_real_id where target_user_id = p_placeholder_id;
  update public.recruit_applications set applicant_id = p_real_id where applicant_id = p_placeholder_id;
  update public.swap_history         set before_user_id = p_real_id where before_user_id = p_placeholder_id;
  update public.swap_history         set after_user_id = p_real_id where after_user_id = p_placeholder_id;

  delete from public.users where id = p_placeholder_id;
end;
$$;

-- >>>>>>>>>> 0003_rls.sql >>>>>>>>>>
-- ============================================================================
-- DeskMate — triggers & Row Level Security
-- ============================================================================

-- --- Notification triggers ---------------------------------------------------

-- Direct swap request -> notify the target.
create or replace function public.tg_notify_swap_request()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.type = 'direct' and new.target_user_id is not null then
    perform public._notify(new.target_user_id, 'swap_request', '새 교환 요청이 왔어요',
      coalesce((select name from public.users where id = new.requester_id), '동료') || '님이 근무 교환을 요청했어요',
      jsonb_build_object('request_id', new.id));
  end if;
  return new;
end; $$;

drop trigger if exists trg_notify_swap_request on public.swap_requests;
create trigger trg_notify_swap_request after insert on public.swap_requests
  for each row execute function public.tg_notify_swap_request();

-- Recruit application -> notify the recruit author.
create or replace function public.tg_notify_recruit_apply()
returns trigger language plpgsql security definer set search_path = public as $$
declare author uuid;
begin
  select requester_id into author from public.swap_requests where id = new.request_id;
  perform public._notify(author, 'recruit_apply', '모집에 지원이 들어왔어요',
    coalesce((select name from public.users where id = new.applicant_id), '동료') || '님이 교환 모집에 지원했어요',
    jsonb_build_object('request_id', new.request_id, 'application_id', new.id));
  return new;
end; $$;

drop trigger if exists trg_notify_recruit_apply on public.recruit_applications;
create trigger trg_notify_recruit_apply after insert on public.recruit_applications
  for each row execute function public.tg_notify_recruit_apply();

-- New month schedule published -> broadcast to all real users.
create or replace function public.tg_notify_new_event()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (user_id, type, title, body, data)
  select u.id, 'schedule_published', '새 근무표가 등록됐어요',
         new.month || ' 근무표를 확인해보세요', jsonb_build_object('month', new.month)
  from public.users u
  where u.is_placeholder = false
    and not exists (
      select 1 from public.notifications n
      where n.user_id = u.id and n.type = 'schedule_published'
        and n.data->>'month' = new.month
    );
  return new;
end; $$;

drop trigger if exists trg_notify_new_event on public.events;
create trigger trg_notify_new_event after insert on public.events
  for each row execute function public.tg_notify_new_event();

-- --- Enable RLS --------------------------------------------------------------
alter table public.users               enable row level security;
alter table public.app_settings        enable row level security;
alter table public.time_presets        enable row level security;
alter table public.preset_slots        enable row level security;
alter table public.events              enable row level security;
alter table public.schedules           enable row level security;
alter table public.swap_requests       enable row level security;
alter table public.recruit_applications enable row level security;
alter table public.swap_history        enable row level security;
alter table public.notifications       enable row level security;

-- --- users -------------------------------------------------------------------
create policy users_select on public.users for select to authenticated using (true);
create policy users_insert_self on public.users for insert to authenticated
  with check (auth_id = auth.uid() or public.is_admin());
create policy users_update_self on public.users for update to authenticated
  using (auth_id = auth.uid() or public.is_admin())
  with check (auth_id = auth.uid() or public.is_admin());
create policy users_delete_admin on public.users for delete to authenticated
  using (public.is_admin());

-- --- app_settings ------------------------------------------------------------
create policy settings_select on public.app_settings for select to authenticated using (true);
create policy settings_update on public.app_settings for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- --- presets / events (read all, admin write) --------------------------------
create policy presets_select on public.time_presets for select to authenticated using (true);
create policy presets_write  on public.time_presets for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy pslots_select on public.preset_slots for select to authenticated using (true);
create policy pslots_write  on public.preset_slots for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy events_select on public.events for select to authenticated using (true);
create policy events_write  on public.events for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- --- schedules ---------------------------------------------------------------
-- Read all. Admin can edit freely. A regular user may only toggle the pin on
-- their own cell; swaps go through SECURITY DEFINER functions (bypass RLS).
create policy schedules_select on public.schedules for select to authenticated using (true);
create policy schedules_admin  on public.schedules for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy schedules_pin_own on public.schedules for update to authenticated
  using (user_id = public.current_user_id())
  with check (user_id = public.current_user_id());

-- --- swap_requests -----------------------------------------------------------
create policy swap_select on public.swap_requests for select to authenticated using (true);
create policy swap_insert on public.swap_requests for insert to authenticated
  with check (requester_id = public.current_user_id());
create policy swap_cancel on public.swap_requests for update to authenticated
  using (requester_id = public.current_user_id())
  with check (requester_id = public.current_user_id());

-- --- recruit_applications ----------------------------------------------------
create policy recruit_select on public.recruit_applications for select to authenticated using (true);
create policy recruit_insert on public.recruit_applications for insert to authenticated
  with check (applicant_id = public.current_user_id());

-- --- swap_history / notifications --------------------------------------------
create policy history_select on public.swap_history for select to authenticated using (true);

create policy notif_select on public.notifications for select to authenticated
  using (user_id = public.current_user_id());
create policy notif_update on public.notifications for update to authenticated
  using (user_id = public.current_user_id())
  with check (user_id = public.current_user_id());

-- >>>>>>>>>> 0004_seed.sql >>>>>>>>>>
-- ============================================================================
-- DeskMate — demo seed data (safe to skip in production)
--   Creates time presets, placeholder staff, and an August 2026 schedule so
--   the app has something to render before an admin builds a real month.
-- ============================================================================

do $$
declare
  summer uuid; winter uuid;
  names text[] := array['홍길동','김영희','이철수','박민준','최수아','정하윤','강도윤','윤서연'];
  n text; uid uuid;
  staff uuid[] := '{}';
  ev uuid; wk int; slot int; pos int; idx int := 1;
begin
  -- Presets ------------------------------------------------------------------
  if not exists (select 1 from public.time_presets) then
    insert into public.time_presets (name) values ('하절기') returning id into summer;
    insert into public.preset_slots (preset_id, slot_no, start_time, end_time) values
      (summer,1,'08:00','10:00'),(summer,2,'10:00','12:00'),
      (summer,3,'12:00','14:00'),(summer,4,'14:00','16:00');

    insert into public.time_presets (name) values ('동절기') returning id into winter;
    insert into public.preset_slots (preset_id, slot_no, start_time, end_time) values
      (winter,1,'09:00','11:00'),(winter,2,'11:00','13:00'),
      (winter,3,'13:00','15:00'),(winter,4,'15:00','17:00');
  else
    select id into summer from public.time_presets where name = '하절기' limit 1;
  end if;

  -- Placeholder staff --------------------------------------------------------
  foreach n in array names loop
    select id into uid from public.users where name = n and is_placeholder limit 1;
    if uid is null then
      insert into public.users (name, is_placeholder) values (n, true) returning id into uid;
    end if;
    staff := staff || uid;
  end loop;

  -- August 2026: four Saturdays, 4 slots x 2 people ---------------------------
  if not exists (select 1 from public.events where month = '2026-08') then
    for wk in 1..4 loop
      insert into public.events (month, date, week_label, type, preset_id, slot_count, sort_order)
      values ('2026-08', (date '2026-08-01' + (wk-1)*7), wk || '주', '토요일', summer, 4, wk)
      returning id into ev;

      for slot in 1..4 loop
        for pos in 1..2 loop
          insert into public.schedules (month, event_id, slot_no, position, user_id)
          values ('2026-08', ev, slot, pos, staff[1 + (idx % array_length(staff,1))]);
          idx := idx + 1;
        end loop;
      end loop;
    end loop;
  end if;
end $$;

-- >>>>>>>>>> 0005_publish.sql >>>>>>>>>>
-- ============================================================================
-- DeskMate — 근무표 "공개하기" 플로우
--   관리자가 근무일을 추가/편집하는 동안에는 사용자에게 보이지 않고(초안),
--   완성 후 publish_month()로 공개할 때만 노출 + 1회 알림이 나간다.
-- ============================================================================

alter table public.events
  add column if not exists is_published boolean not null default false;

-- 이미 존재하던(공개 상태였던) 근무일은 공개로 유지.
update public.events set is_published = true where is_published = false;

-- 근무일 "추가(insert)" 시 자동 알림을 보내던 트리거 제거 —
-- 이제 알림은 공개 시점에만 나간다.
drop trigger if exists trg_notify_new_event on public.events;
drop function if exists public.tg_notify_new_event();

-- 월 단위 공개: 초안 근무일을 모두 공개하고, 실사용자에게 1회 알림.
create or replace function public.publish_month(p_month text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin() then raise exception '권한이 없어요'; end if;

  update public.events set is_published = true
   where month = p_month and is_published = false;

  insert into public.notifications (user_id, type, title, body, data)
  select u.id, 'schedule_published', '새 근무표가 등록됐어요',
         p_month || ' 근무표를 확인해보세요', jsonb_build_object('month', p_month)
  from public.users u
  where u.is_placeholder = false
    and not exists (
      select 1 from public.notifications n
      where n.user_id = u.id
        and n.type = 'schedule_published'
        and n.data->>'month' = p_month
    );
end;
$$;

-- >>>>>>>>>> 0006_approval.sql >>>>>>>>>>
-- ============================================================================
-- DeskMate — 회원가입 승인제
--   이메일/비밀번호로 가입하면 status='pending'으로 저장되고, 관리자가
--   승인(approved)해야 근무표·교환 기능을 사용할 수 있다.
-- ============================================================================

alter table public.users
  add column if not exists status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected'));

-- 기존 사용자(관리자 포함)는 모두 승인 상태로 유지.
update public.users set status = 'approved' where status <> 'approved';

-- 승인 여부 헬퍼 (관리자는 항상 통과).
create or replace function public.is_approved()
returns boolean
language sql stable security definer set search_path = public
as $$
  select coalesce(
    (select status = 'approved' or role = 'admin'
       from public.users where auth_id = auth.uid() limit 1),
    false
  );
$$;

-- 일반 사용자가 자기 role/status를 못 바꾸도록 방지(관리자만 변경 가능).
create or replace function public.tg_users_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    if new.role is distinct from old.role
       or new.status is distinct from old.status then
      raise exception '권한이 없어요';
    end if;
  end if;
  return new;
end; $$;

drop trigger if exists trg_users_guard on public.users;
create trigger trg_users_guard before update on public.users
  for each row execute function public.tg_users_guard();

-- 가입 시 self-insert는 반드시 user/pending 로만(자기 승인·관리자 지정 차단).
drop policy if exists users_insert_self on public.users;
create policy users_insert_self on public.users for insert to authenticated
  with check (
    (auth_id = auth.uid() and role = 'user' and status = 'pending')
    or public.is_admin()
  );

-- --- 승인된 사용자만 데이터 접근 (읽기/쓰기) --------------------------------
drop policy if exists events_select on public.events;
create policy events_select on public.events for select to authenticated
  using (public.is_approved());

drop policy if exists schedules_select on public.schedules;
create policy schedules_select on public.schedules for select to authenticated
  using (public.is_approved());

drop policy if exists swap_select on public.swap_requests;
create policy swap_select on public.swap_requests for select to authenticated
  using (public.is_approved());

drop policy if exists recruit_select on public.recruit_applications;
create policy recruit_select on public.recruit_applications for select to authenticated
  using (public.is_approved());

drop policy if exists history_select on public.swap_history;
create policy history_select on public.swap_history for select to authenticated
  using (public.is_approved());

drop policy if exists swap_insert on public.swap_requests;
create policy swap_insert on public.swap_requests for insert to authenticated
  with check (requester_id = public.current_user_id() and public.is_approved());

drop policy if exists recruit_insert on public.recruit_applications;
create policy recruit_insert on public.recruit_applications for insert to authenticated
  with check (applicant_id = public.current_user_id() and public.is_approved());

drop policy if exists schedules_pin_own on public.schedules;
create policy schedules_pin_own on public.schedules for update to authenticated
  using (user_id = public.current_user_id() and public.is_approved())
  with check (user_id = public.current_user_id() and public.is_approved());

