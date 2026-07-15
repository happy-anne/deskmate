-- ============================================================================
-- DeskMate — 교환 모집(recruit) 등록 시 다른 사용자에게 알림
--   기존 tg_notify_swap_request 는 direct(지정 교환)일 때 상대에게만 알렸다.
--   여기에 recruit(교환 모집) 분기를 추가해, 모집이 열리면 본인을 제외한
--   승인된 실사용자 전원에게 "새 교환 모집" 알림을 보낸다.
--   notifications INSERT → 기존 push 트리거가 이어받아 인앱 + 웹 푸시가 나간다.
-- ============================================================================

create or replace function public.tg_notify_swap_request()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.type = 'direct' and new.target_user_id is not null then
    perform public._notify(new.target_user_id, 'swap_request', '새 교환 요청이 왔어요',
      coalesce((select name from public.users where id = new.requester_id), '동료') || '님이 근무 교환을 요청했어요',
      jsonb_build_object('request_id', new.id));

  elsif new.type = 'recruit' then
    insert into public.notifications (user_id, type, title, body, data)
    select u.id, 'recruit_open', '새 교환 모집이 올라왔어요',
           coalesce((select name from public.users where id = new.requester_id), '동료')
             || '님이 근무 교환을 구하고 있어요',
           jsonb_build_object('request_id', new.id)
    from public.users u
    where u.is_placeholder = false
      and u.id <> new.requester_id
      and (u.status = 'approved' or u.role = 'admin');
  end if;
  return new;
end; $$;

-- 함수 교체로 기존 트리거가 새 정의를 사용한다(트리거 재생성 불필요).
