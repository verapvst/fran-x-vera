-- Fase 3: equipas automáticas por noite, presença pelo BoozeFeed, reações e ajustes ao programa.
-- Corre DEPOIS de schema.sql e fase2.sql, no SQL Editor do Supabase. Pode ser corrido mais do que uma vez.
--
-- Como funciona:
--  * O primeiro post que uma pessoa faz numa noite mete-a numa equipa (Vera ou Fran), a mais pequena nessa noite.
--  * As equipas renovam-se todas as noites. A noite vai das 08:00 às 08:00 (hora de Lisboa).
--  * Pontos = bebidas + horas na festa (primeiro ao último post da noite) + challenges aprovados.
--  * Pontuação da equipa = pontos totais ÷ pessoas da equipa nessa noite.

-- 1. Programa: sem Work Day nem Recovery Day, "The Finale" passa a "Discoteca" ------------------------
delete from events where id in ('e4', 'e7');
update events set title = 'DISCOTECA', place = null where id = 'e11';

-- 2. A Fran e a Vera também jogam no BoozeFeed (nos challenges não) ---------------------------------
drop policy if exists "posts_insert" on posts;
create policy "posts_insert" on posts for insert to authenticated with check (user_id = auth.uid());

-- a hora do post é sempre a do servidor (ninguém inventa horas para ganhar pontos de presença)
create or replace function posts_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare d drinks; n int;
begin
  if now() < get_feed_unlock() then raise exception 'O BoozeFeed ainda está fechado.'; end if;
  new.user_id := auth.uid();
  new.created_at := now();
  select * into d from drinks where id = new.drink_id;
  if not found then raise exception 'Bebida inválida'; end if;
  new.points := d.points;
  if d.kind = 'care' then
    select count(*) into n from posts p join drinks k on k.id = p.drink_id
      where p.user_id = new.user_id and k.kind = 'care' and p.created_at > now() - interval '12 hours';
    if n >= 1 then raise exception 'Limite: o check de chegada a casa conta uma vez por noite.'; end if;
  else
    select count(*) into n from posts p join drinks k on k.id = p.drink_id
      where p.user_id = new.user_id and k.kind = 'drink' and p.created_at > now() - interval '1 hour';
    if n >= 2 then raise exception 'Limite: no máximo 2 bebidas por hora. Bebe água e volta já.'; end if;
  end if;
  return new;
end $$;

-- 3. Noites e presença ----------------------------------------------------------------------------
create or replace function night_of(ts timestamptz) returns date
language sql stable as $$ select ((ts at time zone 'Europe/Lisbon') - interval '8 hours')::date $$;

-- pontos por hora na festa (muda aqui se quiseres: update app_settings set value = '8' where key = 'presence_points_per_hour')
insert into app_settings values ('presence_points_per_hour', '5') on conflict (key) do nothing;
create or replace function presence_rate() returns numeric
language sql stable security definer set search_path = public as $$
  select coalesce((select value::numeric from app_settings where key = 'presence_points_per_hour'), 5)
$$;

-- primeiro e último post de cada pessoa em cada noite; as horas contam no máximo 12
create or replace view night_presence with (security_invoker = true) as
  select x.user_id, x.night,
         min(x.created_at) as first_at, max(x.created_at) as last_at,
         round(least(extract(epoch from (max(x.created_at) - min(x.created_at))) / 3600.0, 12)::numeric, 1) as hours,
         floor(least(extract(epoch from (max(x.created_at) - min(x.created_at))) / 3600.0, 12) * presence_rate())::int as points
    from (select user_id, created_at, night_of(created_at) as night from posts) x
   group by x.user_id, x.night;

-- equipa de cada player em cada noite. Só se escreve pelo trigger e pelas funções abaixo.
create table if not exists night_teams (
  night date not null,
  user_id uuid not null references profiles(id) on delete cascade,
  team text not null check (team in ('vera', 'fran')),
  assigned_at timestamptz not null default now(),
  primary key (night, user_id)
);
alter table night_teams enable row level security;
drop policy if exists "night_teams_read" on night_teams;
create policy "night_teams_read" on night_teams for select to anon, authenticated using (true);

-- o primeiro post da noite mete o player na equipa mais pequena (empate: Vera)
create or replace function posts_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare n date; v int; f int;
begin
  if not exists (select 1 from profiles where id = new.user_id and role = 'player') then return new; end if;
  n := night_of(new.created_at);
  perform pg_advisory_xact_lock(hashtext('night_teams_' || n::text));
  if exists (select 1 from night_teams where night = n and user_id = new.user_id) then return new; end if;
  select count(*) filter (where team = 'vera'), count(*) filter (where team = 'fran') into v, f from night_teams where night = n;
  insert into night_teams (night, user_id, team) values (n, new.user_id, case when v <= f then 'vera' else 'fran' end);
  return new;
end $$;
drop trigger if exists posts_ai on posts;
create trigger posts_ai after insert on posts for each row execute function posts_after_insert();

-- correção manual pelas referees
create or replace function set_night_team(p_user uuid, p_night date, p_team text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_ref() then raise exception 'Só as referees mudam equipas.'; end if;
  if p_team not in ('vera', 'fran') then raise exception 'Equipa inválida.'; end if;
  if not exists (select 1 from profiles where id = p_user and role = 'player') then raise exception 'Só players têm equipa.'; end if;
  insert into night_teams (night, user_id, team) values (p_night, p_user, p_team)
    on conflict (night, user_id) do update set team = excluded.team;
end $$;

-- 4. Pontuações -----------------------------------------------------------------------------------
drop view if exists team_board;  -- da fase 2 (equipas fixas)

create or replace view night_scores with (security_invoker = true) as
  select nt.night, nt.team, nt.user_id,
         coalesce((select sum(po.points) from posts po where po.user_id = nt.user_id and night_of(po.created_at) = nt.night), 0)::int as drink_points,
         coalesce((select np.points from night_presence np where np.user_id = nt.user_id and np.night = nt.night), 0)::int as presence_points,
         coalesce((select np.hours from night_presence np where np.user_id = nt.user_id and np.night = nt.night), 0) as hours,
         coalesce((select sum(a.points_awarded) from assignments a
                    where a.user_id = nt.user_id and a.status = 'approved'
                      and night_of(coalesce(a.submitted_at, a.created_at)) = nt.night), 0)::int as challenge_points
    from night_teams nt;

create or replace view team_night_board with (security_invoker = true) as
  select s.night, s.team,
         count(*)::int as people,
         sum(s.drink_points + s.presence_points + s.challenge_points)::int as points,
         sum(s.hours) as hours,
         team_score(sum(s.drink_points + s.presence_points + s.challenge_points), count(*)::int) as score
    from night_scores s
   group by s.night, s.team;

-- ranking individual: bebidas + presença + challenges aprovados (colunas novas no fim)
create or replace view leaderboard with (security_invoker = true) as
  select p.name,
         (coalesce((select sum(po.points) from posts po where po.user_id = p.id), 0)
          + coalesce((select sum(np.points) from night_presence np where np.user_id = p.id), 0)
          + coalesce((select sum(a.points_awarded) from assignments a where a.user_id = p.id and a.status = 'approved'), 0))::int as points,
         (select count(*) from posts po where po.user_id = p.id)::int as posts,
         p.avatar_path, p.region,
         (select nt.team from night_teams nt where nt.user_id = p.id order by nt.night desc limit 1) as team,
         (select count(*) from assignments a where a.user_id = p.id and a.status = 'approved')::int as challenges,
         coalesce((select sum(np.hours) from night_presence np where np.user_id = p.id), 0) as hours
    from profiles p
   where p.role in ('player', 'referee');

-- 5. Challenges: atribuídos a quem já tem equipa nessa noite (ou seja, já postou) -------------------
drop function if exists assign_challenge(uuid, text);
create or replace function assign_challenge(p_challenge uuid, p_night date default null) returns int
language plpgsql security definer set search_path = public as $$
declare c challenges; r record; tgt record; n int := 0; d date := coalesce(p_night, night_of(now()));
begin
  if not is_ref() then raise exception 'Só as referees atribuem challenges.'; end if;
  select * into c from challenges where id = p_challenge;
  if not found then raise exception 'Challenge inválido'; end if;
  for r in
    select nt.user_id as id, nt.team from night_teams nt
     where nt.night = d
       and not exists (select 1 from assignments a where a.challenge_id = c.id and a.user_id = nt.user_id)
  loop
    select pr.id, pr.name into tgt from night_teams nt join profiles pr on pr.id = nt.user_id
     where nt.night = d and nt.user_id <> r.id
     order by (nt.team is distinct from r.team) desc, random() limit 1;
    insert into assignments (challenge_id, user_id, target_id, text, points)
      values (c.id, r.id, tgt.id, replace(c.text, '[B]', coalesce(tgt.name, 'alguém')), c.points);
    n := n + 1;
  end loop;
  return n;
end $$;

-- a referee só valida a equipa contrária à sua, a da noite em que a prova foi enviada
create or replace function review_assignment(p_id uuid, p_approve boolean, p_points int default null) returns void
language plpgsql security definer set search_path = public as $$
declare a assignments; owner_team text; me text; pts int;
begin
  if not is_ref() then raise exception 'Só as referees validam.'; end if;
  select * into a from assignments where id = p_id;
  if not found then raise exception 'Prova não encontrada.'; end if;
  if a.status <> 'pending' then raise exception 'Esta prova já foi decidida ou ainda não foi enviada.'; end if;
  select team into owner_team from night_teams
   where user_id = a.user_id and night = night_of(coalesce(a.submitted_at, a.created_at));
  me := ref_team();
  if owner_team is null then raise exception 'Esta pessoa não tem equipa nessa noite.'; end if;
  if me is not null and me = owner_team then raise exception 'Só podes validar a equipa contrária à tua.'; end if;
  pts := case when p_approve then coalesce(p_points, a.points) else 0 end;
  if pts < 0 or pts > 500 then raise exception 'Pontos inválidos.'; end if;
  update assignments set status = case when p_approve then 'approved' else 'rejected' end,
         points_awarded = pts, validated_by = auth.uid(), validated_at = now()
   where id = p_id;
end $$;

-- 6. Reações às fotos (uma por pessoa e por post) --------------------------------------------------
create table if not exists reactions (
  post_id uuid not null references posts(id) on delete cascade,
  user_id uuid not null default auth.uid() references profiles(id) on delete cascade,
  kind text not null check (kind in ('fire', 'beer', 'laugh', 'kiss')),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
alter table reactions enable row level security;
drop policy if exists "reactions_read" on reactions;
create policy "reactions_read" on reactions for select to anon, authenticated using (true);
drop policy if exists "reactions_insert" on reactions;
create policy "reactions_insert" on reactions for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "reactions_delete" on reactions;
create policy "reactions_delete" on reactions for delete to authenticated using (user_id = auth.uid() or is_ref());

-- 7. Permissões -----------------------------------------------------------------------------------
grant select on night_teams, reactions, night_presence, night_scores, team_night_board, leaderboard to anon, authenticated;
grant insert, delete on reactions to authenticated;
grant execute on function night_of(timestamptz) to anon, authenticated;
grant execute on function set_night_team(uuid, date, text) to authenticated;
grant execute on function assign_challenge(uuid, date) to authenticated;
grant execute on function review_assignment(uuid, boolean, int) to authenticated;
