-- Fase 2: equipas, check in, challenges com prova, validação pela referee da equipa contrária, ranking de equipas.
-- Corre DEPOIS de schema.sql, no SQL Editor do Supabase. Pode ser corrido mais do que uma vez.

-- 0. Só as referees veem quantas pessoas vão a cada momento (cada pessoa vê só as suas escolhas)
drop policy if exists "rsvps_read" on rsvps;
create policy "rsvps_read" on rsvps for select to authenticated using (user_id = auth.uid() or is_ref());

-- 1. Equipas -------------------------------------------------------------------------------------
alter table profiles add column if not exists team text check (team in ('vera', 'fran'));

-- a equipa de uma referee é a do nome dela: a Vera é Team Vera, a Fran é Team Fran
create or replace function ref_team() returns text
language sql stable security definer set search_path = public as $$
  select case lower(name) when 'vera' then 'vera' when 'fran' then 'fran' else null end
    from profiles where id = auth.uid() and role = 'referee'
$$;

-- recebe {"<user_id>": "vera" | "fran", ...}. Só referees. Só mexe em players.
create or replace function set_teams(p_teams jsonb) returns int
language plpgsql security definer set search_path = public as $$
declare n int := 0; k text; v text;
begin
  if not is_ref() then raise exception 'Só as referees criam equipas.'; end if;
  for k, v in select key, value from jsonb_each_text(p_teams) loop
    if v not in ('vera', 'fran') then raise exception 'Equipa inválida: %', v; end if;
    update profiles set team = v where id = k::uuid and role = 'player';
    n := n + 1;
  end loop;
  return n;
end $$;

-- 2. Check in -------------------------------------------------------------------------------------
create table if not exists checkins (
  event_id text not null references events(id) on delete cascade,
  user_id uuid not null default auth.uid() references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);
alter table checkins enable row level security;
drop policy if exists "checkins_read" on checkins;
create policy "checkins_read" on checkins for select to anon, authenticated using (true);
drop policy if exists "checkins_insert" on checkins;
create policy "checkins_insert" on checkins for insert to authenticated
  with check (is_ref() or (user_id = auth.uid()));
drop policy if exists "checkins_delete" on checkins;
create policy "checkins_delete" on checkins for delete to authenticated using (is_ref());

-- início e fim reais de um momento, em hora de Lisboa. Dia inteiro = 00:00 às 24:00.
create or replace function event_window(e events) returns tstzrange
language plpgsql stable set search_path = public as $$
declare d date; s timestamp; f timestamp;
begin
  d := case e.day when 'qui' then date '2026-10-15' when 'sex' then date '2026-10-16'
                   when 'sab' then date '2026-10-17' else date '2026-10-18' end;
  if e.all_day or e.start_time is null or e.end_time is null then
    s := d::timestamp; f := s + interval '1 day';
  else
    s := d + e.start_time::time; f := d + e.end_time::time;
    if f <= s then f := f + interval '1 day'; end if;
  end if;
  return tstzrange(s at time zone 'Europe/Lisbon', f at time zone 'Europe/Lisbon');
end $$;

-- check in aberto: 1 hora antes do início até 1 hora depois do fim
create or replace function checkin_open(e events, at timestamptz) returns boolean
language sql stable set search_path = public as $$
  select e.official and at >= lower(event_window(e)) - interval '1 hour'
                    and at <= upper(event_window(e)) + interval '1 hour'
$$;

-- players só fazem check in com o momento a decorrer. Referees podem sempre (por exemplo, para quem se esqueceu).
create or replace function checkins_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare e events;
begin
  select * into e from events where id = new.event_id;
  if not found then raise exception 'Momento inválido'; end if;
  if is_ref() then return new; end if;
  new.user_id := auth.uid();
  if not e.official then raise exception 'Este momento não tem check in.'; end if;
  if not checkin_open(e, now()) then raise exception 'O check in só abre perto da hora do momento.'; end if;
  return new;
end $$;
drop trigger if exists checkins_bi on checkins;
create trigger checkins_bi before insert on checkins for each row execute function checkins_before_insert();

-- 3. Challenges -----------------------------------------------------------------------------------
-- modelos criados pelas referees. "[B]" no texto é substituído pelo nome de outra pessoa presente.
create table if not exists challenges (
  id uuid primary key default gen_random_uuid(),
  text text not null check (char_length(text) between 1 and 240),
  points int not null default 10 check (points between 0 and 500),
  created_at timestamptz not null default now()
);
alter table challenges enable row level security;
drop policy if exists "challenges_ref" on challenges;
create policy "challenges_ref" on challenges for all to authenticated using (is_ref()) with check (is_ref());

-- um challenge entregue a uma pessoa. Guarda também a prova e a decisão da referee.
create table if not exists assignments (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid references challenges(id) on delete set null,
  event_id text references events(id) on delete set null,
  user_id uuid not null references profiles(id) on delete cascade,
  target_id uuid references profiles(id) on delete set null,
  text text not null,
  points int not null check (points between 0 and 500),
  status text not null default 'open' check (status in ('open', 'pending', 'approved', 'rejected')),
  media_path text,
  media_type text check (media_type in ('image', 'video')),
  submitted_at timestamptz,
  validated_by uuid references profiles(id) on delete set null,
  validated_at timestamptz,
  points_awarded int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists assignments_user on assignments (user_id, created_at desc);
alter table assignments enable row level security;
-- quem vê o quê: o próprio, as referees, e toda a gente só vê o que já foi aprovado. Provas por validar nunca aparecem a outros.
drop policy if exists "assignments_read" on assignments;
create policy "assignments_read" on assignments for select to anon, authenticated
  using (status = 'approved' or user_id = auth.uid() or is_ref());
drop policy if exists "assignments_delete" on assignments;
create policy "assignments_delete" on assignments for delete to authenticated using (is_ref());

-- as referees entregam um modelo a todos os players com check in num momento
create or replace function assign_challenge(p_challenge uuid, p_event text) returns int
language plpgsql security definer set search_path = public as $$
declare c challenges; r record; tgt profiles; n int := 0; t text;
begin
  if not is_ref() then raise exception 'Só as referees atribuem challenges.'; end if;
  select * into c from challenges where id = p_challenge;
  if not found then raise exception 'Challenge inválido'; end if;
  for r in
    select p.id, p.name, p.team from checkins k join profiles p on p.id = k.user_id
     where k.event_id = p_event and p.role = 'player'
       and not exists (select 1 from assignments a where a.challenge_id = c.id and a.user_id = p.id)
  loop
    select p.* into tgt from checkins k join profiles p on p.id = k.user_id
     where k.event_id = p_event and p.role = 'player' and p.id <> r.id
     order by (p.team is distinct from r.team) desc, random() limit 1;
    t := replace(c.text, '[B]', coalesce(tgt.name, 'alguém'));
    insert into assignments (challenge_id, event_id, user_id, target_id, text, points)
      values (c.id, p_event, r.id, tgt.id, t, c.points);
    n := n + 1;
  end loop;
  return n;
end $$;

-- o player envia a prova (o ficheiro já foi para o bucket "proofs", na pasta dele)
create or replace function submit_proof(p_id uuid, p_path text, p_type text) returns void
language plpgsql security definer set search_path = public as $$
declare a assignments;
begin
  if auth.uid() is null then raise exception 'Sem sessão'; end if;
  select * into a from assignments where id = p_id and user_id = auth.uid();
  if not found then raise exception 'Challenge não encontrado.'; end if;
  if a.status not in ('open', 'rejected') then raise exception 'Já enviaste a prova deste challenge.'; end if;
  if p_type not in ('image', 'video') then raise exception 'Tipo de ficheiro inválido.'; end if;
  if split_part(p_path, '/', 1) <> auth.uid()::text then raise exception 'Caminho inválido.'; end if;
  update assignments set status = 'pending', media_path = p_path, media_type = p_type,
         submitted_at = now(), validated_by = null, validated_at = null, points_awarded = 0
   where id = p_id;
end $$;

-- a referee decide. Só valida provas da equipa contrária à sua (a Vera valida a Team Fran e vice-versa).
create or replace function review_assignment(p_id uuid, p_approve boolean, p_points int default null) returns void
language plpgsql security definer set search_path = public as $$
declare a assignments; owner_team text; me text; pts int;
begin
  if not is_ref() then raise exception 'Só as referees validam.'; end if;
  select * into a from assignments where id = p_id;
  if not found then raise exception 'Prova não encontrada.'; end if;
  if a.status <> 'pending' then raise exception 'Esta prova já foi decidida ou ainda não foi enviada.'; end if;
  select team into owner_team from profiles where id = a.user_id;
  me := ref_team();
  if owner_team is null then raise exception 'Esta pessoa ainda não tem equipa.'; end if;
  if me is not null and me = owner_team then
    raise exception 'Só podes validar a equipa contrária à tua.';
  end if;
  pts := case when p_approve then coalesce(p_points, a.points) else 0 end;
  if pts < 0 or pts > 500 then raise exception 'Pontos inválidos.'; end if;
  update assignments set status = case when p_approve then 'approved' else 'rejected' end,
         points_awarded = pts, validated_by = auth.uid(), validated_at = now()
   where id = p_id;
end $$;

-- 4. Provas (foto e vídeo). Bucket público como o das selfies: quem tiver o link direto consegue ver. ------
insert into storage.buckets (id, name, public) values ('proofs', 'proofs', true) on conflict (id) do nothing;
update storage.buckets set file_size_limit = 26214400,
  allowed_mime_types = array['image/jpeg', 'video/mp4', 'video/quicktime', 'video/webm'] where id = 'proofs';
drop policy if exists "proofs_insert" on storage.objects;
create policy "proofs_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'proofs' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "proofs_delete" on storage.objects;
create policy "proofs_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'proofs' and ((storage.foldername(name))[1] = auth.uid()::text or is_ref()));

-- 5. Rankings --------------------------------------------------------------------------------------
-- fórmula única da pontuação de equipa: pontos totais ÷ pessoas com pelo menos um check in
create or replace function team_score(p_points numeric, p_present int) returns numeric
language sql immutable as $$
  select case when coalesce(p_present, 0) <= 0 then 0 else round(p_points / p_present, 1) end
$$;

-- ranking individual: bebidas + challenges aprovados (as colunas novas ficam no fim)
create or replace view leaderboard with (security_invoker = true) as
  select p.name,
         (coalesce((select sum(po.points) from posts po where po.user_id = p.id), 0)
          + coalesce((select sum(a.points_awarded) from assignments a where a.user_id = p.id and a.status = 'approved'), 0))::int as points,
         (select count(*) from posts po where po.user_id = p.id)::int as posts,
         p.avatar_path, p.region, p.team,
         (select count(*) from assignments a where a.user_id = p.id and a.status = 'approved')::int as challenges
    from profiles p
   where p.role in ('player', 'referee');

create or replace view team_board with (security_invoker = true) as
  select t.team,
         count(*)::int as people,
         sum(t.points)::int as points,
         count(*) filter (where t.present)::int as present,
         team_score(sum(t.points), (count(*) filter (where t.present))::int) as score
    from (
      select p.id, p.team,
             (coalesce((select sum(po.points) from posts po where po.user_id = p.id), 0)
              + coalesce((select sum(a.points_awarded) from assignments a where a.user_id = p.id and a.status = 'approved'), 0)) as points,
             exists (select 1 from checkins k where k.user_id = p.id) as present
        from profiles p
       where p.role = 'player' and p.team is not null
    ) t
   group by t.team;

-- 6. Permissões ------------------------------------------------------------------------------------
grant select on checkins, assignments, team_board, leaderboard to anon, authenticated;
grant select, insert, update, delete on challenges to authenticated;
grant insert, delete on checkins to authenticated;
grant delete on assignments to authenticated;
grant execute on function ref_team() to authenticated;
grant execute on function set_teams(jsonb) to authenticated;
grant execute on function assign_challenge(uuid, text) to authenticated;
grant execute on function submit_proof(uuid, text, text) to authenticated;
grant execute on function review_assignment(uuid, boolean, int) to authenticated;
grant execute on function team_score(numeric, int) to anon, authenticated;
grant execute on function checkin_open(events, timestamptz) to anon, authenticated;
