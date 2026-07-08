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
