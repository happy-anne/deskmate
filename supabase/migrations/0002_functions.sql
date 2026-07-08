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
