-- FRAN x VERA: base de dados completa. Pode ser corrido mais do que uma vez sem estragar nada.

-- 1. Definicoes
create table if not exists app_settings (key text primary key, value text not null);
alter table app_settings enable row level security;  -- sem policies: ninguem le pela API
insert into app_settings values ('feed_unlock', '2026-10-15T19:00:00+01:00') on conflict (key) do nothing;

-- links de referee: um por pessoa, de uso unico (o token vai no link: SITE/#a=TOKEN)
create table if not exists admin_invites (token text primary key, name text not null, used boolean not null default false);
alter table admin_invites enable row level security;  -- sem policies: so as funcoes abaixo lhe tocam
insert into admin_invites (token, name)
select substr(replace(gen_random_uuid()::text, '-', ''), 1, 24), v.n
from (values ('Vera'), ('Fran')) as v(n)
where not exists (select 1 from admin_invites a where a.name = v.n);  -- tokens gerados ao acaso; le-os na tabela admin_invites

-- Quem ainda nao entrou (anon) pode LER plano, feed, ranking e ideias. Escrever exige perfil.

-- 2. Perfis
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  role text not null default 'player' check (role in ('player','referee')),
  avatar_path text,
  region text check (region in ('national','international')),
  created_at timestamptz not null default now()
);
alter table profiles enable row level security;
drop policy if exists "profiles_read" on profiles;
create policy "profiles_read" on profiles for select to anon, authenticated using (true);
-- sem policy de update: ninguem muda o proprio role. So claim_referee() o faz.

create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, name) values (new.id, coalesce(nullif(trim(new.raw_user_meta_data->>'name'), ''), 'Sem nome'));
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

create or replace function is_ref() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'referee')
$$;

-- chave pessoal de cada pessoa (o link). So a propria pessoa e as referees a leem.
create table if not exists member_keys (
  user_id uuid primary key references profiles(id) on delete cascade,
  link_key text not null,
  contact text
);
alter table member_keys enable row level security;
drop policy if exists "keys_read" on member_keys;
create policy "keys_read" on member_keys for select to authenticated using (user_id = auth.uid() or is_ref());

-- devolve o nome associado ao link de referee, ou null se for invalido ou ja usado
create or replace function check_admin_token(tok text) returns text
language sql stable security definer set search_path = public as $$
  select name from admin_invites where token = tok and not used
$$;

-- chamada logo a seguir a criar conta: guarda foto, link, contacto, regiao e (link de referee valido) promove a referee
create or replace function finish_signup(p_key text, p_contact text, p_region text, p_avatar text, p_token text) returns void
language plpgsql security definer set search_path = public as $$
declare is_admin boolean := false;
begin
  if auth.uid() is null then raise exception 'Sem sessao'; end if;
  if p_token is not null and p_token <> '' then
    update admin_invites set used = true where token = p_token and not used;
    if not found then raise exception 'Este link de referee é inválido ou já foi usado.'; end if;
    update profiles set role = 'referee' where id = auth.uid();
    is_admin := true;
  else
    if p_region is null or p_region not in ('national','international') then raise exception 'Escolhe nacional ou internacional'; end if;
    if p_contact is null or position('@' in p_contact) < 2 then raise exception 'Email inválido'; end if;
  end if;
  update profiles set avatar_path = p_avatar, region = p_region where id = auth.uid();
  insert into member_keys (user_id, link_key, contact) values (auth.uid(), p_key, nullif(trim(coalesce(p_contact,'')), ''))
    on conflict (user_id) do update set link_key = excluded.link_key, contact = excluded.contact;
end $$;

-- BoozeFeed: quando abre. Referees podem abrir ou fechar.
create or replace function get_feed_unlock() returns timestamptz
language sql stable security definer set search_path = public as $$
  select value::timestamptz from app_settings where key = 'feed_unlock'
$$;
create or replace function set_feed_unlock(ts timestamptz) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_ref() then raise exception 'So as referees'; end if;
  update app_settings set value = ts::text where key = 'feed_unlock';
end $$;

-- 3. Eventos
create table if not exists events (
  id text primary key,
  day text not null check (day in ('qui','sex','sab','dom')),
  start_time text, end_time text,
  all_day boolean not null default false,
  title text not null, place text, note text, rule_text text,
  official boolean not null default true,
  sort int not null default 0
);
alter table events enable row level security;
drop policy if exists "events_read" on events;
create policy "events_read" on events for select to anon, authenticated using (true);
drop policy if exists "events_write" on events;
create policy "events_write" on events for all to authenticated using (is_ref()) with check (is_ref());

insert into events (id, day, start_time, end_time, all_day, title, place, note, rule_text, official, sort) values
 ('e1','qui','19:00','23:30',false,'THE GRAND OPENING','Corner','Início oficial da festa, apresentação do conceito, equipas e jogo.',null,true,1),
 ('e2','sex','00:00','00:30',false,'23.',null,'Momento de aniversário da Fran.',null,true,2),
 ('e3','sex','00:30','02:00',false,'PRAIA NO PARQUE',null,null,null,true,3),
 ('e4','sex','02:00','18:00',false,'WORK DAY',null,'Dia normal de trabalho. Não é programação oficial da festa.',null,false,4),
 ('e5','sex','19:00','23:00',false,'RALLY TASCAS & CROQUETTE','Belém → Bairro Alto','Um rally pelas tascas, com diferentes challenges e pontos ao longo do percurso.',null,true,5),
 ('e6','sex','23:00','02:00',false,'ZÉ DOS BOIS',null,null,null,true,6),
 ('e7','sab',null,null,true,'RECOVERY DAY',null,null,null,true,7),
 ('e8','sab','20:00','22:00',false,'BINGO',null,'Evento especial com sistema de pontuação próprio.','Linha: X pontos · Bingo: 100 pontos',true,8),
 ('e9','sab','22:00','00:00',false,'PRE-DRINKS',null,null,null,true,9),
 ('e10','dom','00:00','00:30',false,'24.',null,'Momento de aniversário da Vera.',null,true,10),
 ('e11','dom','00:30','06:00',false,'THE FINALE',null,null,null,true,11)
on conflict (id) do nothing;

-- 4. Quem vai a que momentos
create table if not exists rsvps (
  event_id text not null references events(id) on delete cascade,
  user_id uuid not null default auth.uid() references profiles(id) on delete cascade,
  primary key (event_id, user_id)
);
alter table rsvps enable row level security;
drop policy if exists "rsvps_read" on rsvps;
create policy "rsvps_read" on rsvps for select to anon, authenticated using (true);
drop policy if exists "rsvps_insert" on rsvps;
create policy "rsvps_insert" on rsvps for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "rsvps_delete" on rsvps;
create policy "rsvps_delete" on rsvps for delete to authenticated using (user_id = auth.uid());

-- 5. BoozeFeed: bebidas, posts, ranking
create table if not exists drinks (
  id text primary key,
  label text not null, hint text,
  points int not null,
  kind text not null default 'drink' check (kind in ('drink','care')),
  sort int not null default 0
);
alter table drinks enable row level security;
drop policy if exists "drinks_read" on drinks;
create policy "drinks_read" on drinks for select to anon, authenticated using (true);
drop policy if exists "drinks_update" on drinks;
create policy "drinks_update" on drinks for update to authenticated using (is_ref()) with check (is_ref());

insert into drinks (id, label, hint, points, kind, sort) values
 ('d_na','Sem álcool','água, sumo, 0%',-1,'drink',1),
 ('d_beer20','Cerveja 0,2 L','imperial, fino',1,'drink',2),
 ('d_beer33','Cerveja 0,33 L','garrafa pequena',2,'drink',3),
 ('d_beer50','Cerveja 0,5 L','caneca',4,'drink',4),
 ('d_sidra','Sidra garrafa','garrafa',3,'drink',5),
 ('d_wine','Vinho','tinto, branco, sangria',5,'drink',6),
 ('d_cock','Cocktail','mojito, spritz, gin tónico',8,'drink',7),
 ('d_shot','Shot','jäger, tequila, ginja',10,'drink',8),
 ('d_hard','Bebida forte','gin, vodka, whisky',12,'drink',9),
 ('d_home','Cheguei a casa','em segurança, 1 vez por noite',15,'care',10)
on conflict (id) do nothing;

create table if not exists posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references profiles(id) on delete cascade,
  drink_id text not null references drinks(id),
  points int not null default 0,
  caption text check (char_length(caption) <= 120),
  photo_path text not null,
  created_at timestamptz not null default now()
);
create index if not exists posts_user_time on posts (user_id, created_at desc);
alter table posts enable row level security;
drop policy if exists "posts_read" on posts;
create policy "posts_read" on posts for select to anon, authenticated using (true);
drop policy if exists "posts_insert" on posts;
create policy "posts_insert" on posts for insert to authenticated with check (user_id = auth.uid() and not is_ref());
drop policy if exists "posts_delete" on posts;
create policy "posts_delete" on posts for delete to authenticated using (user_id = auth.uid() or is_ref());

-- pontos vem sempre da tabela drinks (o cliente nao decide) e limites de seguranca
create or replace function posts_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare d drinks; n int;
begin
  if now() < get_feed_unlock() then raise exception 'O BoozeFeed ainda está fechado.'; end if;
  new.user_id := auth.uid();
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
drop trigger if exists posts_bi on posts;
create trigger posts_bi before insert on posts for each row execute function posts_before_insert();

create or replace view leaderboard with (security_invoker = true) as
  select p.name, coalesce(sum(po.points), 0)::int as points, count(po.id)::int as posts, p.avatar_path, p.region
  from profiles p left join posts po on po.user_id = p.id
  where p.role = 'player'
  group by p.id, p.name;

-- 6. Ideias de challenges
create table if not exists challenge_ideas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references profiles(id) on delete cascade,
  text text not null check (char_length(text) between 1 and 240),
  created_at timestamptz not null default now()
);
alter table challenge_ideas enable row level security;
drop policy if exists "ideas_read" on challenge_ideas;
create policy "ideas_read" on challenge_ideas for select to anon, authenticated using (true);
drop policy if exists "ideas_insert" on challenge_ideas;
create policy "ideas_insert" on challenge_ideas for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "ideas_delete" on challenge_ideas;
create policy "ideas_delete" on challenge_ideas for delete to authenticated using (user_id = auth.uid() or is_ref());

-- 7. Selfies (bucket publico: quem tiver o link da foto consegue ve-la)
insert into storage.buckets (id, name, public) values ('selfies', 'selfies', true) on conflict (id) do nothing;
update storage.buckets set file_size_limit = 2097152, allowed_mime_types = array['image/jpeg'] where id = 'selfies';  -- max 2 MB, so JPEG
drop policy if exists "selfies_insert" on storage.objects;
create policy "selfies_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'selfies' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "selfies_delete" on storage.objects;
create policy "selfies_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'selfies' and ((storage.foldername(name))[1] = auth.uid()::text or is_ref()));

-- 8. Permissoes de acesso (GRANTs). Projetos novos do Supabase nao dao acesso automatico
-- as tabelas: sem isto a API responde "permission denied". As regras RLS acima continuam a decidir quem ve e faz o que.
grant usage on schema public to anon, authenticated;
grant select on profiles, events, rsvps, drinks, posts, challenge_ideas, leaderboard to anon, authenticated;
grant select on member_keys to authenticated;
grant insert, update, delete on events to authenticated;
grant insert, delete on rsvps to authenticated;
grant update on drinks to authenticated;
grant insert, delete on posts to authenticated;
grant insert, delete on challenge_ideas to authenticated;
grant execute on function is_ref() to anon, authenticated;
grant execute on function check_admin_token(text) to anon, authenticated;
grant execute on function get_feed_unlock() to anon, authenticated;
grant execute on function finish_signup(text, text, text, text, text) to authenticated;
grant execute on function set_feed_unlock(timestamptz) to authenticated;
