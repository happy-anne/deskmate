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
