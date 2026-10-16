-- Fase 5: a Vera joga na Team Vera e a Fran na Team Fran; o ranking mostra o detalhe dos pontos.
-- Corre DEPOIS de fase4.sql, no SQL Editor do Supabase. Pode ser corrido mais do que uma vez.

-- 1. As referees entram na equipa do seu nome (contam para os pontos e para o número de pessoas da equipa)
insert into team_members (user_id, team)
  select id, lower(name) from profiles where role = 'referee' and lower(name) in ('vera', 'fran')
on conflict (user_id) do update set team = excluded.team;

-- o trigger do primeiro post: referees vão para a equipa do nome, players para a equipa com menos gente
create or replace function posts_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare n date; vt int; ft int; vm int; fm int; t text; r text; nm text;
begin
  select role, lower(name) into r, nm from profiles where id = new.user_id;
  if r = 'referee' then
    if nm in ('vera', 'fran') then
      insert into team_members (user_id, team) values (new.user_id, nm) on conflict (user_id) do nothing;
    end if;
    return new;
  end if;
  if r is distinct from 'player' then return new; end if;
  perform pg_advisory_xact_lock(hashtext('team_members'));
  if exists (select 1 from team_members where user_id = new.user_id) then return new; end if;
  n := night_of(new.created_at);
  select count(distinct tm.user_id) filter (where tm.team = 'vera'), count(distinct tm.user_id) filter (where tm.team = 'fran')
    into vt, ft
    from team_members tm join posts p on p.user_id = tm.user_id and night_of(p.created_at) = n;
  select count(*) filter (where team = 'vera'), count(*) filter (where team = 'fran') into vm, fm from team_members;
  t := case when vt < ft then 'vera' when ft < vt then 'fran' when vm <= fm then 'vera' else 'fran' end;
  insert into team_members (user_id, team) values (new.user_id, t);
  return new;
end $$;

-- 2. Ranking com o detalhe: bebidas, horas na festa e challenges
create or replace view leaderboard with (security_invoker = true) as
  select p.name,
         (coalesce((select sum(po.points) from posts po where po.user_id = p.id), 0)
          + coalesce((select sum(np.points) from night_presence np where np.user_id = p.id), 0)
          + coalesce((select sum(a.points_awarded) from assignments a where a.user_id = p.id and a.status = 'approved'), 0))::int as points,
         (select count(*) from posts po where po.user_id = p.id)::int as posts,
         p.avatar_path, p.region,
         (select tm.team from team_members tm where tm.user_id = p.id) as team,
         (select count(*) from assignments a where a.user_id = p.id and a.status = 'approved')::int as challenges,
         coalesce((select sum(np.hours) from night_presence np where np.user_id = p.id), 0) as hours,
         coalesce((select sum(po.points) from posts po where po.user_id = p.id), 0)::int as drink_points,
         coalesce((select sum(np.points) from night_presence np where np.user_id = p.id), 0)::int as presence_points,
         coalesce((select sum(a.points_awarded) from assignments a where a.user_id = p.id and a.status = 'approved'), 0)::int as challenge_points
    from profiles p
   where p.role in ('player', 'referee');

grant select on leaderboard to anon, authenticated;
