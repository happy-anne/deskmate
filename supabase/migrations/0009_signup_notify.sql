-- ============================================================================
-- DeskMate — 신규 가입 승인 요청 시 관리자 알림
--   비관리자 실사용자가 status='pending' 으로 가입하면 모든 관리자에게
--   "새 가입 승인 요청" 알림을 넣는다. notifications INSERT → 기존 push 트리거가
--   이어받아 인앱 알림 + 웹 푸시가 함께 나간다.
-- ============================================================================

create or replace function public.tg_notify_admin_signup()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  -- 실사용자의 '승인 대기' 상태에만 반응 (임시/이미 승인 제외).
  if new.is_placeholder or new.status is distinct from 'pending' then
    return new;
  end if;

  insert into public.notifications (user_id, type, title, body, data)
  select a.id, 'signup_pending', '새 가입 승인 요청',
         new.name || '님이 가입 승인을 기다리고 있어요',
         jsonb_build_object('user_id', new.id, 'name', new.name)
  from public.users a
  where a.role = 'admin' and a.is_placeholder = false;

  return new;
end;
$$;

drop trigger if exists trg_notify_admin_signup on public.users;
create trigger trg_notify_admin_signup
  after insert on public.users
  for each row execute function public.tg_notify_admin_signup();

-- 트리거 생성 이전에 이미 승인 대기 중인 가입자에 대한 backfill (중복 방지).
insert into public.notifications (user_id, type, title, body, data)
select a.id, 'signup_pending', '새 가입 승인 요청',
       p.name || '님이 가입 승인을 기다리고 있어요',
       jsonb_build_object('user_id', p.id, 'name', p.name)
from public.users a
cross join public.users p
where a.role = 'admin' and a.is_placeholder = false
  and p.is_placeholder = false and p.status = 'pending'
  and not exists (
    select 1 from public.notifications n
    where n.user_id = a.id and n.type = 'signup_pending'
      and n.data->>'user_id' = p.id::text
  );
