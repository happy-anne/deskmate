-- ============================================================================
-- DeskMate — 대신하기 되갚기(repay) 실행
--   갚을 사람(covered)이 대신해준 사람(coverer)의 근무를 눌러 "대신 해주기"로
--   되갚기 요청을 보낸다. coverer가 수락하면 교환 없이 그 근무에 갚는 사람의
--   이름이 들어가고(단방향), 해당 대신하기 약속은 settled 처리된다.
-- ============================================================================

-- 1) 약속 정산 플래그
alter table public.cover_agreements
  add column if not exists settled boolean not null default false;

-- 2) swap_requests 에 repay 타입 + 약속 링크
--    기존 type CHECK 제약을 이름과 무관하게 찾아 제거한 뒤 새 값으로 재생성.
do $$
declare c record;
begin
  for c in
    select conname from pg_constraint
     where conrelid = 'public.swap_requests'::regclass and contype = 'c'
       and pg_get_constraintdef(oid) ilike '%type %any%'
  loop
    execute format('alter table public.swap_requests drop constraint %I', c.conname);
  end loop;
end $$;
alter table public.swap_requests
  add constraint swap_requests_type_check check (type in ('direct', 'recruit', 'repay'));
alter table public.swap_requests
  add column if not exists cover_id uuid references public.cover_agreements (id) on delete set null;

-- 3) 요청 생성 알림에 repay 분기 추가
create or replace function public.tg_notify_swap_request()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.type = 'direct' and new.target_user_id is not null then
    perform public._notify(new.target_user_id, 'swap_request', '새 교환 요청이 왔어요',
      coalesce((select name from public.users where id = new.requester_id), '동료') || '님이 근무 교환을 요청했어요',
      jsonb_build_object('request_id', new.id));

  elsif new.type = 'repay' and new.target_user_id is not null then
    perform public._notify(new.target_user_id, 'repay_request', '대신해주기 되갚기 요청이 들어왔어요',
      coalesce((select name from public.users where id = new.requester_id), '동료') || '님이 되갚기를 요청했어요',
      jsonb_build_object('request_id', new.id));

  elsif new.type = 'recruit' then
    insert into public.notifications (user_id, type, title, body, data)
    select u.id, 'recruit_open', '새 교환 모집이 올라왔어요',
           coalesce((select name from public.users where id = new.requester_id), '동료')
             || '님이 근무 교환을 구하고 있어요',
           jsonb_build_object('request_id', new.id)
    from public.users u
    where u.is_placeholder = false and u.id <> new.requester_id
      and (u.status = 'approved' or u.role = 'admin');
  end if;
  return new;
end; $$;

-- 4) 되갚기 수락 — 단방향 배정 + 약속 정산.
create or replace function public.accept_repay(p_request_id uuid)
returns void language plpgsql security definer set search_path = public
as $$
declare
  r public.swap_requests;
  me uuid := public.current_user_id();
  prev uuid;
begin
  select * into r from public.swap_requests where id = p_request_id for update;
  if not found then raise exception '요청을 찾을 수 없어요'; end if;
  if r.type <> 'repay' or r.target_user_id <> me then
    raise exception '이 요청을 수락할 권한이 없어요';
  end if;
  if r.status <> 'pending' then raise exception '이미 처리된 요청이에요'; end if;

  -- 내 근무를 되갚는 사람(requester)에게 배정.
  select user_id into prev from public.schedules where id = r.target_schedule_id for update;
  update public.schedules set user_id = r.requester_id, is_changed = true
   where id = r.target_schedule_id;

  insert into public.swap_history (request_id, schedule_id, before_user_id, after_user_id)
  values (r.id, r.target_schedule_id, prev, r.requester_id);

  if r.cover_id is not null then
    update public.cover_agreements set settled = true where id = r.cover_id;
  end if;

  update public.swap_requests set status = 'completed' where id = p_request_id;

  perform public._notify(r.requester_id, 'repay_done', '되갚기가 완료됐어요',
    coalesce((select name from public.users where id = me), '상대') || '님이 되갚기를 수락했어요',
    jsonb_build_object('request_id', p_request_id));
end; $$;
