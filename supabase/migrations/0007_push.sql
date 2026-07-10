-- ============================================================================
-- DeskMate — 웹 푸시(Web Push / VAPID) 구독 저장소
--   FCM 없이 표준 Web Push를 쓴다. 한 사용자가 여러 기기를 구독할 수 있으므로
--   (user_id, endpoint) 조합을 유니크로 둔다. 발송은 Nuxt 서버 라우트
--   (/api/push/send)가 notifications insert 웹훅을 받아 처리한다.
-- ============================================================================

create table if not exists public.push_subscriptions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users (id) on delete cascade,
  endpoint   text not null,
  p256dh     text,
  auth       text,
  created_at timestamptz not null default now(),
  unique (user_id, endpoint)
);

create index if not exists push_subs_user_idx on public.push_subscriptions (user_id);

alter table public.push_subscriptions enable row level security;

-- 본인 구독만 관리(추가/조회/삭제). current_user_id()는 auth.uid() → public.users.id 매핑.
drop policy if exists push_subs_own on public.push_subscriptions;
create policy push_subs_own on public.push_subscriptions
  for all to authenticated
  using (user_id = public.current_user_id())
  with check (user_id = public.current_user_id());
