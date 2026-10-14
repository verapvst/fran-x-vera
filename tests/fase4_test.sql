create schema tt; grant usage on schema tt to anon, authenticated;
create function tt.chk(label text, q text, expect_ok boolean) returns text language plpgsql as $$
declare n int; begin
  begin execute q; get diagnostics n = row_count;
    return (case when expect_ok then 'PASS ' else 'FAIL(should have errored) ' end)||label||' rows='||n;
  exception when others then
    return (case when expect_ok then 'FAIL(error: '||sqlerrm||') ' else 'PASS ' end)||label||' ['||sqlerrm||']';
  end; end $$;
create function tt.cnt(label text, q text, expected int) returns text language plpgsql as $$
declare n int; begin execute 'select count(*) from ('||q||') s' into n;
  return (case when n = expected then 'PASS ' else 'FAIL ' end)||label||' got='||n||' expected='||expected; end $$;
create function tt.eq(label text, q text, expected text) returns text language plpgsql as $$
declare v text; begin execute q into v;
  return (case when v is not distinct from expected then 'PASS ' else 'FAIL ' end)||label||' got='||coalesce(v,'null')||' expected='||expected; end $$;
\set A1 '00000000-0000-0000-0000-0000000000a1'
\set A2 '00000000-0000-0000-0000-0000000000a2'
\set A3 '00000000-0000-0000-0000-0000000000a3'
\set A4 '00000000-0000-0000-0000-0000000000a4'
\set A5 '00000000-0000-0000-0000-0000000000a5'
\set V  '00000000-0000-0000-0000-0000000000b1'
\set F  '00000000-0000-0000-0000-0000000000b2'
insert into auth.users(id,email,raw_user_meta_data) values
 (:'A1','a1@x','{"name":"Ana"}'),(:'A2','a2@x','{"name":"Bia"}'),(:'A3','a3@x','{"name":"Carla"}'),(:'A4','a4@x','{"name":"Duarte"}'),(:'A5','a5@x','{"name":"Eva"}'),
 (:'V','v@x','{"name":"Vera"}'),(:'F','f@x','{"name":"Fran"}');
update profiles set role = 'referee' where id in (:'V', :'F');
update profiles set region = 'national' where id in (:'A1', :'A3', :'A5');
update profiles set region = 'international' where id in (:'A2', :'A4');
update app_settings set value = '2020-01-01T00:00:00+00:00' where key = 'feed_unlock';

-- EQUIPA FIXA: primeiro post de sempre decide
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 first post',$$insert into posts(drink_id,photo_path) values('d_beer20','a1/1.jpg')$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A2',false);
select tt.chk('A2 first post',$$insert into posts(drink_id,photo_path) values('d_cock','a2/1.jpg')$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A3',false);
select tt.chk('A3 first post',$$insert into posts(drink_id,photo_path) values('d_beer33','a3/1.jpg')$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'V',false);
select tt.chk('referee posts (no team)',$$insert into posts(drink_id,photo_path) values('d_beer20','b1/1.jpg')$$,true);
reset role;
select tt.cnt('3 members, referee has none','select 1 from team_members',3);
select tt.eq('A1 Team Vera (first)','select team from team_members where user_id=''00000000-0000-0000-0000-0000000000a1''','vera');
select tt.eq('A2 Team Fran (balances tonight)','select team from team_members where user_id=''00000000-0000-0000-0000-0000000000a2''','fran');
select tt.eq('A3 Team Vera (tie: fewer members)','select team from team_members where user_id=''00000000-0000-0000-0000-0000000000a3''','vera');

-- noites seguintes: a equipa mantém-se; quem chega novo equilibra
update posts set created_at = timestamptz '2026-10-15 20:00:00+01' where user_id in (:'A1', :'A2', :'A3', :'V');
set role authenticated; select set_config('request.jwt.claim.sub',:'A4',false);
select tt.chk('A4 arrives later (first post)',$$insert into posts(drink_id,photo_path) values('d_beer20','a4/1.jpg')$$,true);
reset role;
select tt.eq('A4 Team Fran (Vera has 2 members, Fran 1)','select team from team_members where user_id=''00000000-0000-0000-0000-0000000000a4''','fran');
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 posts again on a new night',$$insert into posts(drink_id,photo_path) values('d_beer20','a1/2.jpg')$$,true);
reset role;
select tt.eq('A1 still Team Vera','select team from team_members where user_id=''00000000-0000-0000-0000-0000000000a1''','vera');
select tt.cnt('4 members','select 1 from team_members',4);
set role authenticated; select set_config('request.jwt.claim.sub',:'A2',false);
select tt.chk('A2 cannot change own team',$$insert into team_members(user_id,team) values ('00000000-0000-0000-0000-0000000000a2','vera') on conflict (user_id) do update set team='vera'$$,false);
select tt.chk('A2 cannot call set_team',$$select set_team('00000000-0000-0000-0000-0000000000a2','vera')$$,false);
reset role;

-- pontuação por noite com equipa fixa
select tt.eq('15 Oct, Vera: 2 people, 3 points, 1.5','select people||''/''||points||''/''||score from team_night_board where night=date ''2026-10-15'' and team=''vera''','2/3/1.5');
select tt.eq('15 Oct, Fran: 1 person, 8 points, 8.0','select people||''/''||points||''/''||score from team_night_board where night=date ''2026-10-15'' and team=''fran''','1/8/8.0');
select set_config('request.jwt.claim.sub','',false); set role anon;
select tt.eq('anon sees team totals (Vera 2 members)','select members::text from team_totals where team=''vera''','2');
select tt.eq('leaderboard shows fixed team','select team from leaderboard where name=''Bia''','fran');
reset role;

-- quem posta esta noite
set role authenticated; select set_config('request.jwt.claim.sub',:'A2',false);
select tt.chk('A2 posts tonight',$$insert into posts(drink_id,photo_path) values('d_na','a2/2.jpg')$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A3',false);
select tt.chk('A3 posts tonight',$$insert into posts(drink_id,photo_path) values('d_beer20','a3/2.jpg')$$,true);
reset role;
select tt.cnt('4 present tonight (A1..A4), referee and A5 not','select 1 from present_tonight()',4);

-- CHALLENGES com público
set role authenticated; select set_config('request.jwt.claim.sub',:'V',false);
select tt.chk('Vera creates 5 challenges',$$insert into challenges(id,text,points) values
 ('c0000000-0000-0000-0000-000000000001','Convence a [B] a fazer uma pose',30),
 ('c0000000-0000-0000-0000-000000000002','Troca de casaco com alguém',20),
 ('c0000000-0000-0000-0000-000000000003','Dança com a [B]',15),
 ('c0000000-0000-0000-0000-000000000004','Seleciona uma música',10),
 ('c0000000-0000-0000-0000-000000000005','Brinda com a [B]',10)$$,true);
select tt.eq('audience fran = 2 (Bia, Duarte)',$$select assign_challenge('c0000000-0000-0000-0000-000000000001','fran')::text$$,'2');
select tt.eq('audience vera = 2 (Ana, Carla)',$$select assign_challenge('c0000000-0000-0000-0000-000000000002','vera')::text$$,'2');
select tt.eq('audience national = 2 present nationals (Ana, Carla; Eva did not post)',$$select assign_challenge('c0000000-0000-0000-0000-000000000003','national')::text$$,'2');
select tt.eq('audience international = 2',$$select assign_challenge('c0000000-0000-0000-0000-000000000004','international')::text$$,'2');
select tt.eq('picklist: Ana + Eva (Eva not present) = 1 only',$$select assign_challenge('c0000000-0000-0000-0000-000000000005','users', array['00000000-0000-0000-0000-0000000000a1'::uuid,'00000000-0000-0000-0000-0000000000a5'::uuid], true)::text$$,'1');
select tt.eq('same challenge again adds none',$$select assign_challenge('c0000000-0000-0000-0000-000000000001','fran')::text$$,'0');
select tt.chk('invalid audience fails',$$select assign_challenge('c0000000-0000-0000-0000-000000000001','toda a gente')$$,false);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('player cannot assign',$$select assign_challenge('c0000000-0000-0000-0000-000000000001','tonight')$$,false);
select tt.chk('player cannot draw',$$select draw_challenges()$$,false);
select tt.chk('player cannot mark notified',$$select mark_notified(array[gen_random_uuid()])$$,false);
reset role;
select tt.cnt('[B] replaced in all texts','select 1 from assignments where text like ''%[B]%''',0);
-- segredo: A2 não vê o desafio secreto da Ana, mas vê os públicos dos outros
set role authenticated; select set_config('request.jwt.claim.sub',:'A2',false);
select tt.cnt('A2 sees public ones (not the secret one)','select 1 from assignments where secret = false',8);
select tt.cnt('A2 does not see the secret one of Ana','select 1 from assignments where secret = true',0);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.cnt('Ana sees her secret one','select 1 from assignments where secret = true',1);
reset role;
select set_config('request.jwt.claim.sub','',false); set role anon;
select tt.cnt('anon sees public ones only','select 1 from assignments',8);
reset role;
-- sorteio
set role authenticated; select set_config('request.jwt.claim.sub',:'F',false);
select tt.chk('Fran draws challenges for everyone present',$$select draw_challenges(true)$$,true);
select tt.chk('Fran marks as notified',$$select mark_notified(array(select id from assignments limit 2))$$,true);
reset role;
select tt.cnt('notified = 2','select 1 from assignments where notified',2);

-- validação com equipa fixa
create table tt.ids as select (select id from assignments where user_id = :'A2' limit 1) as a2;
grant select on tt.ids to authenticated;
set role authenticated; select set_config('request.jwt.claim.sub',:'A2',false);
select tt.chk('A2 submits proof',$$select submit_proof((select a2 from tt.ids),'00000000-0000-0000-0000-0000000000a2/p1.jpg','image')$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'F',false);
select tt.chk('Fran cannot validate Team Fran (A2)',$$select review_assignment((select a2 from tt.ids), true, 10)$$,false);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'V',false);
select tt.chk('Vera validates Team Fran (A2)',$$select review_assignment((select a2 from tt.ids), true, 10)$$,true);
select tt.chk('Vera moves Bia to Team Vera',$$select set_team('00000000-0000-0000-0000-0000000000a2','vera')$$,true);
reset role;
select tt.eq('Bia is Team Vera now (all nights)','select team from team_members where user_id=''00000000-0000-0000-0000-0000000000a2''','vera');

-- RALLY
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('player cannot create stop',$$insert into rally_stops(name,position) values ('Tasca X',1)$$,false);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'V',false);
select tt.chk('referee creates stops',$$insert into rally_stops(id,name,position) values ('d0000000-0000-0000-0000-000000000001','Tasca do Zé',1),('d0000000-0000-0000-0000-000000000002','Croquetaria',2)$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 rates stop 1',$$insert into rally_ratings(stop_id,croquete,tasca) values ('d0000000-0000-0000-0000-000000000001',5,3)$$,true);
select tt.chk('rating out of range fails',$$insert into rally_ratings(stop_id,croquete,tasca) values ('d0000000-0000-0000-0000-000000000002',6,3)$$,false);
select tt.chk('A1 changes own rating',$$update rally_ratings set croquete = 4 where user_id = '00000000-0000-0000-0000-0000000000a1'$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A3',false);
select tt.chk('A3 rates stop 1',$$insert into rally_ratings(stop_id,croquete,tasca) values ('d0000000-0000-0000-0000-000000000001',2,3)$$,true);
select tt.chk('A3 cannot rate as someone else',$$insert into rally_ratings(stop_id,user_id,croquete,tasca) values ('d0000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-0000000000a1',5,5)$$,false);
reset role;
select set_config('request.jwt.claim.sub','',false); set role anon;
select tt.eq('anon sees board: stop 1 croquete avg 3.00, 2 votes','select croquete||''/''||votes from rally_board where name=''Tasca do Zé''','3.00/2');
select tt.cnt('anon cannot rate',$$select 1 where false$$,0);
select tt.chk('anon cannot insert rating',$$insert into rally_ratings(stop_id,user_id,croquete,tasca) values ('d0000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-0000000000a4',5,5)$$,false);
reset role;
