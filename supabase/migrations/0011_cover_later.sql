-- ============================================================================
-- DeskMate — "대신해주고 나중에 바꾸기" (deferred cover)
--   상대가 이번 달 어떤 근무로도 맞교환이 안 되는 경우, 지원자가 근무를 걸지
--   않고 "대신하기"로 지원한다(applicant_schedule_id = null, is_deferred).
--   모집자가 승인하면 한방향으로 근무가 지원자에게 배정되고, 되갚음(다음 달)
--   약속을 cover_agreements 에 기록한다. 다음 달 스케줄 상단 배너로 안내한다.
-- ============================================================================

-- 1) 지원에 "대신하기" 표시 컬럼
alter table public.recruit_applications
  add column if not exists is_deferred boolean not null default false;

-- 2) 되갚음 약속 기록
create table if not exists public.cover_agreements (
  id              uuid primary key default gen_random_uuid(),
  request_id      uuid references public.swap_requests (id) on delete set null,
  coverer_id      uuid not null references public.users (id) on delete cascade, -- 대신해준 사람
  covered_user_id uuid not null references public.users (id) on delete cascade, -- 되갚을 사람(모집자)
  schedule_id     uuid references public.schedules (id) on delete set null,     -- 이번 달 대신 맡은 근무
  cover_month     text not null,   -- 대신한 달 'YYYY-MM'
  return_month    text not null,   -- 되갚음 달(다음 달) 'YYYY-MM'
  dismissed       boolean not null default false,
  created_at      timestamptz not null default now()
);
create index if not exists cover_coverer_idx on public.cover_agreements (coverer_id, dismissed);

alter table public.cover_agreements enable row level security;

-- 당사자(대신해준 사람 / 되갚을 사람) 또는 관리자만 조회.
drop policy if exists cover_select on public.cover_agreements;
create policy cover_select on public.cover_agreements for select to authenticated
  using (
    coverer_id = public.current_user_id()
    or covered_user_id = public.current_user_id()
    or public.is_admin()
  );
-- insert/update 는 security definer 함수(approve_recruit / dismiss_cover)로만.

-- 3) 배너 닫기: 대신해준 본인만 dismissed 처리.
create or replace function public.dismiss_cover(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.cover_agreements set dismissed = true
   where id = p_id and coverer_id = public.current_user_id();
end; $$;

-- 4) approve_recruit — deferred 지원이면 한방향 배정 + 약속 기록.
create or replace function public.approve_recruit(p_application_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  app public.recruit_applications;
  r public.swap_requests;
  me uuid := public.current_user_id();
  cov_month text;
begin
  select * into app from public.recruit_applications where id = p_application_id for update;
  if not found then raise exception '지원 내역을 찾을 수 없어요'; end if;

  select * into r from public.swap_requests where id = app.request_id for update;
  if r.requester_id <> me then raise exception '모집 작성자만 승인할 수 있어요'; end if;
  if r.status <> 'pending' then raise exception '이미 마감된 모집이에요'; end if;

  if app.is_deferred then
    -- 모집자 근무를 지원자에게 한방향 배정.
    select e.month into cov_month
      from public.schedules s join public.events e on e.id = s.event_id
      where s.id = r.requester_schedule_id;
    cov_month := coalesce(cov_month, to_char(now(), 'YYYY-MM'));

    update public.schedules
       set user_id = app.applicant_id, is_changed = true
     where id = r.requester_schedule_id;

    insert into public.swap_history (request_id, schedule_id, before_user_id, after_user_id)
    values (r.id, r.requester_schedule_id, r.requester_id, app.applicant_id);

    insert into public.cover_agreements
      (request_id, coverer_id, covered_user_id, schedule_id, cover_month, return_month)
    values (
      r.id, app.applicant_id, r.requester_id, r.requester_schedule_id, cov_month,
      to_char((cov_month || '-01')::date + interval '1 month', 'YYYY-MM')
    );
  else
    perform public._apply_swap(r.id, r.requester_schedule_id, app.applicant_schedule_id);
  end if;

  update public.recruit_applications set status = 'approved' where id = p_application_id;
  update public.recruit_applications set status = 'rejected'
    where request_id = r.id and id <> p_application_id and status = 'pending';
  update public.swap_requests set status = 'completed' where id = r.id;

  perform public._notify(app.applicant_id, 'recruit_approved', '모집에 승인됐어요',
    case when app.is_deferred
         then '대신하기로 한 근무가 확정됐어요. 다음 달에 되갚아요.'
         else '지원하신 교환 모집이 승인됐어요' end,
    jsonb_build_object('request_id', r.id));
end;
$$;
