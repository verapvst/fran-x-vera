-- Ajustes de 14 outubro. Corre no Supabase, SQL Editor. Pode ser corrido mais do que uma vez.
-- 1. Plano mais simples: sem Work Day nem Recovery Day, e "The Finale" passa a "Discoteca"
delete from events where id in ('e4', 'e7');
update events set title = 'DISCOTECA', place = null where id = 'e11';

-- 2. A Fran e a Vera também jogam no BoozeFeed (nos challenges não)
drop policy if exists "posts_insert" on posts;
create policy "posts_insert" on posts for insert to authenticated with check (user_id = auth.uid());

create or replace view leaderboard with (security_invoker = true) as
  select p.name,
         (coalesce((select sum(po.points) from posts po where po.user_id = p.id), 0)
          + coalesce((select sum(a.points_awarded) from assignments a where a.user_id = p.id and a.status = 'approved'), 0))::int as points,
         (select count(*) from posts po where po.user_id = p.id)::int as posts,
         p.avatar_path, p.region, p.team,
         (select count(*) from assignments a where a.user_id = p.id and a.status = 'approved')::int as challenges
    from profiles p
   where p.role in ('player', 'referee');
