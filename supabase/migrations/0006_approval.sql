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
