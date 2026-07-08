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
