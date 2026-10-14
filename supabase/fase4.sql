-- Fase 4: equipa fixa para todas as noites, challenges com público e secretos, rally com notas.
-- Corre DEPOIS de schema.sql, fase2.sql e fase3.sql, no SQL Editor do Supabase. Pode ser corrido mais do que uma vez.
--
--  * A equipa é atribuída no primeiro post de sempre e mantém-se nas noites todas.
--  * Os pontos de cada noite dividem-se pelas pessoas da equipa que postaram nessa noite.

-- 1. Equipa fixa --------------------------------------------------------------------------------
create table if not exists team_members (
  user_id uuid primary key references profiles(id) on delete cascade,
  team text not null check (team in ('vera', 'fran')),
  assigned_at timestamptz not null default now()
);
alter table team_members enable row level security;
drop policy if exists "team_members_read" on team_members;
create policy "team_members_read" on team_members for select to anon, authenticated using (true);

-- quem já tinha equipa numa noite (fase 3) fica com a da primeira noite
do $$ begin
  if to_regclass('public.night_teams') is not null then
    insert into team_members (user_id, team, assigned_at)
      select distinct on (user_id) user_id, team, assigned_at from night_teams order by user_id, night
    on conflict (user_id) do nothing;
  end if;
end $$;

-- nova pessoa: vai para a equipa com menos gente que já postou esta noite; empate: a com menos membros; empate: Vera
create or replace function posts_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare n date; vt int; ft int; vm int; fm int; t text;
begin
  if not exists (select 1 from profiles where id = new.user_id and role = 'player') then return new; end if;
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

-- correção manual pelas referees (muda a equipa para as noites todas)
create or replace function set_team(p_user uuid, p_team text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_ref() then raise exception 'Só as referees mudam equipas.'; end if;
  if p_team not in ('vera', 'fran') then raise exception 'Equipa inválida.'; end if;
  if not exists (select 1 from profiles where id = p_user and role = 'player') then raise exception 'Só players têm equipa.'; end if;
  insert into team_members (user_id, team) values (p_user, p_team)
    on conflict (user_id) do update set team = excluded.team;
end $$;

-- 2. Pontuações (a equipa é fixa, as pessoas contam em cada noite em que postam) ----------------------
create or replace view leaderboard with (security_invoker = true) as
  select p.name,
         (coalesce((select sum(po.points) from posts po where po.user_id = p.id), 0)
          + coalesce((select sum(np.points) from night_presence np where np.user_id = p.id), 0)
          + coalesce((select sum(a.points_awarded) from assignments a where a.user_id = p.id and a.status = 'approved'), 0))::int as points,
         (select count(*) from posts po where po.user_id = p.id)::int as posts,
         p.avatar_path, p.region,
         (select tm.team from team_members tm where tm.user_id = p.id) as team,
         (select count(*) from assignments a where a.user_id = p.id and a.status = 'approved')::int as challenges,
         coalesce((select sum(np.hours) from night_presence np where np.user_id = p.id), 0) as hours
    from profiles p
   where p.role in ('player', 'referee');

drop view if exists night_scores cascade;  -- leva consigo team_night_board
create view night_scores with (security_invoker = true) as
  select np.night, tm.team, np.user_id,
         coalesce((select sum(po.points) from posts po where po.user_id = np.user_id and night_of(po.created_at) = np.night), 0)::int as drink_points,
         np.points::int as presence_points,
         np.hours as hours,
         coalesce((select sum(a.points_awarded) from assignments a
                    where a.user_id = np.user_id and a.status = 'approved'
                      and night_of(coalesce(a.submitted_at, a.created_at)) = np.night), 0)::int as challenge_points
    from night_presence np join team_members tm on tm.user_id = np.user_id;

create view team_night_board with (security_invoker = true) as
  select s.night, s.team,
         count(*)::int as people,
         sum(s.drink_points + s.presence_points + s.challenge_points)::int as points,
         sum(s.hours) as hours,
         team_score(sum(s.drink_points + s.presence_points + s.challenge_points), count(*)::int) as score
    from night_scores s
   group by s.night, s.team;

create or replace view team_totals with (security_invoker = true) as
  select team, count(*)::int as members from team_members group by team;

drop function if exists set_night_team(uuid, date, text);
drop table if exists night_teams;

-- 3. Challenges: público, secretos, sorteio -------------------------------------------------------
alter table assignments add column if not exists secret boolean not null default false;
alter table assignments add column if not exists notified boolean not null default false;

-- só se vê: o que já foi aprovado, o que é teu, o que não é secreto (ou se és referee)
drop policy if exists "assignments_read" on assignments;
create policy "assignments_read" on assignments for select to anon, authenticated
  using (status = 'approved' or user_id = auth.uid() or is_ref() or secret = false);

-- quem já postou esta noite (só players)
create or replace function present_tonight() returns table (user_id uuid, name text, team text, region text)
language sql stable security definer set search_path = public as $$
  select p.id, p.name, tm.team, p.region
    from profiles p
    join team_members tm on tm.user_id = p.id
   where p.role = 'player'
     and exists (select 1 from posts po where po.user_id = p.id and night_of(po.created_at) = night_of(now()))
$$;

-- entrega um challenge. Público: 'tonight' (todos os que postaram), 'vera', 'fran', 'national', 'international', 'users' (lista)
-- Só quem postou esta noite recebe. [B] no texto vira o nome de outra pessoa presente (de preferência da equipa contrária).
drop function if exists assign_challenge(uuid, date);
create or replace function assign_challenge(p_challenge uuid, p_audience text default 'tonight', p_users uuid[] default null, p_secret boolean default false) returns int
language plpgsql security definer set search_path = public as $$
declare c challenges; r record; tgt record; n int := 0;
begin
  if not is_ref() then raise exception 'Só as referees atribuem challenges.'; end if;
  if p_audience not in ('tonight', 'vera', 'fran', 'national', 'international', 'users') then raise exception 'Público inválido.'; end if;
  select * into c from challenges where id = p_challenge;
  if not found then raise exception 'Challenge inválido'; end if;
  for r in
    select pt.user_id as id, pt.team from present_tonight() pt
     where (p_audience = 'tonight'
            or (p_audience in ('vera', 'fran') and pt.team = p_audience)
            or (p_audience in ('national', 'international') and pt.region = p_audience)
            or (p_audience = 'users' and pt.user_id = any (coalesce(p_users, '{}'))))
       and not exists (select 1 from assignments a where a.challenge_id = c.id and a.user_id = pt.user_id)
  loop
    select q.user_id as id, q.name into tgt from present_tonight() q
     where q.user_id <> r.id
     order by (q.team is distinct from r.team) desc, random() limit 1;
    insert into assignments (challenge_id, user_id, target_id, text, points, secret)
      values (c.id, r.id, tgt.id, replace(c.text, '[B]', coalesce(tgt.name, 'alguém')), c.points, coalesce(p_secret, false));
    n := n + 1;
  end loop;
  return n;
end $$;

-- sorteio: cada pessoa presente recebe um challenge da lista que ainda não tenha recebido
create or replace function draw_challenges(p_secret boolean default true) returns int
language plpgsql security definer set search_path = public as $$
declare r record; c challenges; tgt record; n int := 0;
begin
  if not is_ref() then raise exception 'Só as referees sorteiam challenges.'; end if;
  for r in select pt.user_id as id, pt.team from present_tonight() pt loop
    select * into c from challenges ch
     where not exists (select 1 from assignments a where a.challenge_id = ch.id and a.user_id = r.id)
     order by random() limit 1;
    if not found then continue; end if;
    select q.user_id as id, q.name into tgt from present_tonight() q
     where q.user_id <> r.id order by (q.team is distinct from r.team) desc, random() limit 1;
    insert into assignments (challenge_id, user_id, target_id, text, points, secret)
      values (c.id, r.id, tgt.id, replace(c.text, '[B]', coalesce(tgt.name, 'alguém')), c.points, coalesce(p_secret, false));
    n := n + 1;
  end loop;
  return n;
end $$;

-- a referee só valida a equipa contrária à sua
create or replace function review_assignment(p_id uuid, p_approve boolean, p_points int default null) returns void
language plpgsql security definer set search_path = public as $$
declare a assignments; owner_team text; me text; pts int;
begin
  if not is_ref() then raise exception 'Só as referees validam.'; end if;
  select * into a from assignments where id = p_id;
  if not found then raise exception 'Prova não encontrada.'; end if;
  if a.status <> 'pending' then raise exception 'Esta prova já foi decidida ou ainda não foi enviada.'; end if;
  select team into owner_team from team_members where user_id = a.user_id;
  me := ref_team();
  if owner_team is null then raise exception 'Esta pessoa ainda não tem equipa.'; end if;
  if me is not null and me = owner_team then raise exception 'Só podes validar a equipa contrária à tua.'; end if;
  pts := case when p_approve then coalesce(p_points, a.points) else 0 end;
  if pts < 0 or pts > 500 then raise exception 'Pontos inválidos.'; end if;
  update assignments set status = case when p_approve then 'approved' else 'rejected' end,
         points_awarded = pts, validated_by = auth.uid(), validated_at = now()
   where id = p_id;
end $$;

-- marcar como avisados por email
create or replace function mark_notified(p_ids uuid[]) returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if not is_ref() then raise exception 'Só as referees.'; end if;
  update assignments set notified = true where id = any (p_ids);
  get diagnostics n = row_count;
  return n;
end $$;

-- 4. Rally: paragens e notas --------------------------------------------------------------------
create table if not exists rally_stops (
  id uuid primary key default gen_random_uuid(),
  position int not null default 0,
  name text not null check (char_length(name) between 1 and 80),
  note text check (char_length(note) <= 160),
  created_at timestamptz not null default now()
);
alter table rally_stops enable row level security;
drop policy if exists "rally_stops_read" on rally_stops;
create policy "rally_stops_read" on rally_stops for select to anon, authenticated using (true);
drop policy if exists "rally_stops_write" on rally_stops;
create policy "rally_stops_write" on rally_stops for all to authenticated using (is_ref()) with check (is_ref());

create table if not exists rally_ratings (
  stop_id uuid not null references rally_stops(id) on delete cascade,
  user_id uuid not null default auth.uid() references profiles(id) on delete cascade,
  croquete int not null check (croquete between 1 and 5),
  tasca int not null check (tasca between 1 and 5),
  created_at timestamptz not null default now(),
  primary key (stop_id, user_id)
);
alter table rally_ratings enable row level security;
drop policy if exists "rally_ratings_read" on rally_ratings;
create policy "rally_ratings_read" on rally_ratings for select to anon, authenticated using (true);
drop policy if exists "rally_ratings_insert" on rally_ratings;
create policy "rally_ratings_insert" on rally_ratings for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "rally_ratings_update" on rally_ratings;
create policy "rally_ratings_update" on rally_ratings for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "rally_ratings_delete" on rally_ratings;
create policy "rally_ratings_delete" on rally_ratings for delete to authenticated using (user_id = auth.uid() or is_ref());

create or replace view rally_board with (security_invoker = true) as
  select s.id as stop_id, s.name, s.position,
         round(avg(r.croquete), 2) as croquete, round(avg(r.tasca), 2) as tasca, count(r.user_id)::int as votes
    from rally_stops s left join rally_ratings r on r.stop_id = s.id
   group by s.id, s.name, s.position;

-- 5. Permissões -----------------------------------------------------------------------------------
grant select on team_members, team_totals, night_scores, team_night_board, leaderboard, rally_stops, rally_ratings, rally_board to anon, authenticated;
grant insert, update, delete on rally_stops to authenticated;
grant insert, update, delete on rally_ratings to authenticated;
grant execute on function set_team(uuid, text) to authenticated;
grant execute on function present_tonight() to authenticated;
grant execute on function assign_challenge(uuid, text, uuid[], boolean) to authenticated;
grant execute on function draw_challenges(boolean) to authenticated;
grant execute on function review_assignment(uuid, boolean, int) to authenticated;
grant execute on function mark_notified(uuid[]) to authenticated;
