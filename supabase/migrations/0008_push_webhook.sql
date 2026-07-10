-- ============================================================================
-- DeskMate — notifications INSERT → 웹 푸시 발송 트리거
--
--   notifications 행이 생기면 앱의 /api/push/send 라우트를 호출해 해당 유저의
--   모든 기기로 푸시를 보낸다. pg_net(net.http_post)으로 비동기 호출한다.
--
--   ⚠️ 실행 전 아래 두 placeholder를 본인 값으로 교체하세요:
--       __APP_URL__      예) https://deskmate.vercel.app   (끝에 / 없이)
--       __PUSH_SECRET__  .env 의 PUSH_WEBHOOK_SECRET 와 동일한 문자열
--   secret 이 담기므로 이 파일에 실제 값을 넣은 채로 커밋하지 마세요.
--
--   (대안) Supabase 대시보드 → Database → Webhooks 로 만들어도 됩니다:
--     table=notifications, event=INSERT, method=POST,
--     URL=https://__APP_URL__/api/push/send,
--     HTTP header  x-push-secret: __PUSH_SECRET__
--   대시보드 방식은 secret 을 SQL 파일에 남기지 않아 더 안전합니다.
-- ============================================================================

create extension if not exists pg_net with schema extensions;

create or replace function public.tg_notify_push()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  perform net.http_post(
    url     := '__APP_URL__/api/push/send',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-push-secret', '__PUSH_SECRET__'
               ),
    body    := jsonb_build_object('record', to_jsonb(new))
  );
  return new;
end;
$$;

drop trigger if exists trg_notifications_push on public.notifications;
create trigger trg_notifications_push
  after insert on public.notifications
  for each row execute function public.tg_notify_push();
