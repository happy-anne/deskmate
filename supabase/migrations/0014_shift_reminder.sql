-- ============================================================================
-- DeskMate — 근무 15분 전 리마인더 푸시
--   내 이름이 있는(배정된) 근무의 시작 15분 전에 알림을 넣는다.
--   notifications INSERT → 기존 trg_notifications_push 가 웹 푸시를 발송한다.
--   pg_cron 으로 매분 실행하며, 근무당 1회만 보내도록 중복을 막는다.
--
--   시작 시각 = 이벤트 날짜(e.date) + 프리셋 슬롯 시작시간(preset_slots.start_time)
--   앱 표준시는 한국(Asia/Seoul).
-- ============================================================================

create extension if not exists pg_cron;

create or replace function public.notify_upcoming_shifts()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, type, title, body, data)
  select
    s.user_id,
    'shift_reminder',
    '🗓️ 15분 후에 안내 근무가 있어요!',
    e.week_label || ' ' || s.slot_no || '번 · '
      || to_char(psl.start_time, 'HH24:MI') || ' 시작',
    jsonb_build_object('schedule_id', s.id, 'event_id', e.id)
  from public.schedules s
  join public.events e  on e.id = s.event_id
  join public.preset_slots psl
    on psl.preset_id = e.preset_id and psl.slot_no = s.slot_no
  join public.users u   on u.id = s.user_id and u.is_placeholder = false
  where e.is_published = true
    -- 아직 시작 전이고, 시작까지 15분 이하로 남은 근무.
    and ((e.date + psl.start_time) at time zone 'Asia/Seoul') > now()
    and ((e.date + psl.start_time) at time zone 'Asia/Seoul') - now()
        <= interval '15 minutes'
    -- 같은 근무는 1회만 (사용자·스케줄 기준 중복 방지).
    and not exists (
      select 1 from public.notifications n
      where n.user_id = s.user_id
        and n.type = 'shift_reminder'
        and n.data->>'schedule_id' = s.id::text
    );
end;
$$;

-- 매분 실행하도록 (재)등록.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'shift-reminders') then
    perform cron.unschedule('shift-reminders');
  end if;
end $$;
select cron.schedule('shift-reminders', '* * * * *', $$select public.notify_upcoming_shifts();$$);
