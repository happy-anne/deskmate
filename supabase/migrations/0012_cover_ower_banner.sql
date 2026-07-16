-- ============================================================================
-- DeskMate — 대신하기 배너를 "갚을 사람"에게도 표시
--   기존엔 대신해준 사람(coverer)에게만 배너가 떴다. 갚을 사람(covered)이
--   먼저 챙겨 갚을 수 있도록 그쪽에도 배너를 띄운다.
--   단, 닫기(dismiss)는 역할별로 독립이어야 하므로 플래그를 하나 더 둔다.
--     dismissed          → 대신해준 사람(coverer)의 닫힘
--     covered_dismissed  → 갚을 사람(covered)의 닫힘
-- ============================================================================

alter table public.cover_agreements
  add column if not exists covered_dismissed boolean not null default false;

-- 호출자가 coverer면 dismissed를, covered면 covered_dismissed를 닫는다.
create or replace function public.dismiss_cover(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid := public.current_user_id();
begin
  update public.cover_agreements
     set dismissed         = case when coverer_id = me then true else dismissed end,
         covered_dismissed = case when covered_user_id = me then true else covered_dismissed end
   where id = p_id and (coverer_id = me or covered_user_id = me);
end; $$;
