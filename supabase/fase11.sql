-- Fase 11: Rally Tascas por etapas. Corre no SQL Editor. Pode ser corrido mais do que uma vez.
-- * cada paragem tem estado: hidden (secreta), revealed (visível, notas fechadas), open (notas abertas), visited, skipped
-- * quem não é referee só vê paragens que não estão hidden (a regra está na base de dados, não só no ecrã)
-- * notas de 1 a 10, só em paragens open/visited; as médias só aparecem quando as referees revelam os resultados

-- 1. Paragens com localização e estado
alter table rally_stops
  add column if not exists address text check (char_length(address) <= 200),
  add column if not exists lat double precision check (lat between -90 and 90),
  add column if not exists lng double precision check (lng between -180 and 180),
  add column if not exists kind text not null default 'stop' check (kind in ('start','stop','final')),
  add column if not exists state text not null default 'hidden' check (state in ('hidden','revealed','open','visited','skipped')),
  add column if not exists time_label text check (char_length(time_label) <= 20),
  add column if not exists photo_url text check (photo_url is null or (photo_url ~ '^https://' and char_length(photo_url) <= 400));

drop policy if exists "rally_stops_read" on rally_stops;
create policy "rally_stops_read" on rally_stops for select to anon, authenticated using (state <> 'hidden' or is_ref());
-- (a política rally_stops_write da fase 4 mantém-se: só referees escrevem)

-- 2. Notas de 1 a 10, só quando a paragem está aberta, e cada pessoa só vê as suas
alter table rally_ratings drop constraint if exists rally_ratings_croquete_check;
alter table rally_ratings drop constraint if exists rally_ratings_tasca_check;
alter table rally_ratings add constraint rally_ratings_croquete_check check (croquete between 1 and 10);
alter table rally_ratings add constraint rally_ratings_tasca_check check (tasca between 1 and 10);

drop policy if exists "rally_ratings_read" on rally_ratings;
create policy "rally_ratings_read" on rally_ratings for select to authenticated using (user_id = auth.uid() or is_ref());
drop policy if exists "rally_ratings_insert" on rally_ratings;
create policy "rally_ratings_insert" on rally_ratings for insert to authenticated
  with check (user_id = auth.uid() and exists (select 1 from rally_stops s where s.id = stop_id and s.state in ('open','visited')));
drop policy if exists "rally_ratings_update" on rally_ratings;
create policy "rally_ratings_update" on rally_ratings for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and exists (select 1 from rally_stops s where s.id = stop_id and s.state in ('open','visited')));

-- 3. Resultados escondidos até as referees os revelarem
insert into app_settings values ('rally_results_public', 'false') on conflict (key) do nothing;
create or replace function rally_results_open() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select value = 'true' from app_settings where key = 'rally_results_public'), false)
$$;
create or replace function rally_set_results(p boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_ref() then raise exception 'Só as referees podem fazer isto.'; end if;
  insert into app_settings values ('rally_results_public', case when p then 'true' else 'false' end)
    on conflict (key) do update set value = excluded.value;
end $$;
grant execute on function rally_results_open() to anon, authenticated;
grant execute on function rally_set_results(boolean) to authenticated;

-- as médias só saem se os resultados estiverem revelados (ou se for referee); o número de notas é sempre público
drop view if exists rally_board;
create view rally_board with (security_invoker = false) as
  select s.id as stop_id, s.name, s.position,
         case when rally_results_open() or is_ref() then round(avg(r.croquete), 2) end as croquete,
         case when rally_results_open() or is_ref() then round(avg(r.tasca), 2) end as tasca,
         count(r.user_id)::int as votes
    from rally_stops s left join rally_ratings r on r.stop_id = s.id
   where s.state <> 'hidden' or is_ref()
   group by s.id, s.name, s.position;
grant select on rally_board to anon, authenticated;

-- 4. Primeira paragem (já visível, com as notas fechadas até chegarmos)
insert into rally_stops (position, name, note, address, lat, lng, kind, state, time_label)
select 1, 'Portugália Belém', 'Cervejaria à beira-rio. Croquete e imperial para começar.',
       'Av. Brasília, Edifício Espelho d''Água, 1400-038 Lisboa', 38.6938995, -9.2069216, 'start', 'revealed', '19:00'
 where not exists (select 1 from rally_stops where kind = 'start');

