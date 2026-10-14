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
\set V  '00000000-0000-0000-0000-0000000000b1'
\set F  '00000000-0000-0000-0000-0000000000b2'
insert into auth.users(id,email,raw_user_meta_data) values
 (:'A1','a1@x','{"name":"Ana"}'),(:'A2','a2@x','{"name":"Bia"}'),(:'A3','a3@x','{"name":"Carla"}'),(:'V','v@x','{"name":"Vera"}'),(:'F','f@x','{"name":"Fran"}');
update profiles set role = 'referee' where id in (:'V', :'F');
update app_settings set value = '2020-01-01T00:00:00+00:00' where key = 'feed_unlock';

-- função da noite: das 08:00 às 08:00 (hora de Lisboa)
select tt.eq('01:00 de sexta é noite de quinta', $$select night_of(timestamptz '2026-10-16 01:00:00+01')::text$$, '2026-10-15');
select tt.eq('07:59 ainda é a noite anterior', $$select night_of(timestamptz '2026-10-16 07:59:00+01')::text$$, '2026-10-15');
select tt.eq('08:01 já é o dia seguinte', $$select night_of(timestamptz '2026-10-16 08:01:00+01')::text$$, '2026-10-16');

-- POSTS: equipa automática no primeiro post da noite
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 posts (first of the night)',$$insert into posts(drink_id,photo_path) values('d_beer20','a1/1.jpg')$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A2',false);
select tt.chk('A2 posts a cocktail',$$insert into posts(drink_id,photo_path) values('d_cock','a2/1.jpg')$$,true);
select tt.chk('A2 tries to forge post time (2020)',$$insert into posts(drink_id,photo_path,created_at) values('d_na','a2/2.jpg',timestamptz '2020-01-01')$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A3',false);
select tt.chk('A3 posts',$$insert into posts(drink_id,photo_path) values('d_beer33','a3/1.jpg')$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'V',false);
select tt.chk('Vera (referee) posts too',$$insert into posts(drink_id,photo_path) values('d_beer20','b1/1.jpg')$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 second post same night',$$insert into posts(drink_id,photo_path) values('d_shot','a1/2.jpg')$$,true);
reset role;
select tt.cnt('3 players have a team, referee has none','select 1 from night_teams',3);
select tt.eq('A1 (first) is Team Vera','select team from night_teams where user_id=''00000000-0000-0000-0000-0000000000a1''','vera');
select tt.eq('A2 (second) is Team Fran','select team from night_teams where user_id=''00000000-0000-0000-0000-0000000000a2''','fran');
select tt.eq('A3 (third, tie) is Team Vera','select team from night_teams where user_id=''00000000-0000-0000-0000-0000000000a3''','vera');
select tt.cnt('forged post time ignored (server time used)','select 1 from posts where created_at < timestamptz ''2025-01-01''',0);

-- permissões
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('player cannot insert night_teams directly',$$insert into night_teams(night,user_id,team) values (current_date,'00000000-0000-0000-0000-0000000000a1','fran')$$,false);
select tt.chk('player cannot set_night_team',$$select set_night_team('00000000-0000-0000-0000-0000000000a1', current_date, 'fran')$$,false);
reset role;
select set_config('request.jwt.claim.sub','',false); set role anon;
select tt.cnt('anon reads night_teams','select 1 from night_teams',3);
reset role;

-- horas e pontos de presença (datas fixas para o teste ser sempre igual)
update posts set created_at = timestamptz '2026-10-15 19:30:00+01' where user_id = :'A1' and drink_id = 'd_beer20';
update posts set created_at = timestamptz '2026-10-15 23:30:00+01' where user_id = :'A1' and drink_id = 'd_shot';
update posts set created_at = timestamptz '2026-10-15 20:00:00+01' where user_id = :'A2' and drink_id = 'd_cock';
update posts set created_at = timestamptz '2026-10-16 01:00:00+01' where user_id = :'A2' and drink_id = 'd_na';
update posts set created_at = timestamptz '2026-10-15 21:00:00+01' where user_id in (:'A3', :'V');
update night_teams set night = date '2026-10-15';
select tt.eq('A1 hours (19:30 to 23:30)','select hours::text from night_presence where user_id=''00000000-0000-0000-0000-0000000000a1''','4.0');
select tt.eq('A1 presence points = 4h x 5','select points::text from night_presence where user_id=''00000000-0000-0000-0000-0000000000a1''','20');
select tt.eq('A2 hours (crosses midnight, same night)','select hours::text from night_presence where user_id=''00000000-0000-0000-0000-0000000000a2''','5.0');
select tt.eq('A3 single post = 0 hours','select hours::text from night_presence where user_id=''00000000-0000-0000-0000-0000000000a3''','0.0');
select tt.eq('Team Vera: 2 people, 33 points, 4h, score 16.5','select people||''/''||points||''/''||hours||''/''||score from team_night_board where team=''vera''','2/33/4.0/16.5');
select tt.eq('Team Fran: 1 person, 32 points, 5h, score 32.0','select people||''/''||points||''/''||hours||''/''||score from team_night_board where team=''fran''','1/32/5.0/32.0');
update app_settings set value = '10' where key = 'presence_points_per_hour';
select tt.eq('rate is configurable (10/h): A1 = 40','select points::text from night_presence where user_id=''00000000-0000-0000-0000-0000000000a1''','40');
update app_settings set value = '5' where key = 'presence_points_per_hour';
select set_config('request.jwt.claim.sub','',false); set role anon;
select tt.eq('anon reads leaderboard: Ana = 31 points, 4h','select points||''/''||hours from leaderboard where name=''Ana''','31/4.0');
select tt.eq('referee appears on leaderboard (beer = 1 point)','select points::text from leaderboard where name=''Vera''','1');
select tt.eq('leaderboard shows Ana team','select team from leaderboard where name=''Ana''','vera');
select tt.cnt('anon reads team_night_board','select 1 from team_night_board',2);
reset role;

-- REAÇÕES
create table tt.p2 as select id from posts where user_id = :'A2' and drink_id = 'd_cock';
grant select on tt.p2 to authenticated, anon;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 reacts to A2 post',$$insert into reactions(post_id,kind) values ((select id from tt.p2),'fire')$$,true);
select tt.chk('A1 cannot react twice to the same post',$$insert into reactions(post_id,kind) values ((select id from tt.p2),'beer')$$,false);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A3',false);
select tt.chk('invalid reaction kind fails',$$insert into reactions(post_id,kind) values ((select id from tt.p2),'poop')$$,false);
select tt.chk('A3 deleting others reactions affects no rows',$$delete from reactions$$,true);
reset role;
select tt.cnt('reaction still there','select 1 from reactions',1);
select set_config('request.jwt.claim.sub','',false); set role anon;
select tt.cnt('anon reads reactions','select 1 from reactions',1);
select tt.chk('anon cannot react',$$insert into reactions(post_id,kind) values ((select id from tt.p2),'fire')$$,false);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 removes own reaction',$$delete from reactions where user_id='00000000-0000-0000-0000-0000000000a1'$$,true);
reset role;
select tt.cnt('reaction gone','select 1 from reactions',0);

-- CHALLENGES por noite
set role authenticated; select set_config('request.jwt.claim.sub',:'V',false);
select tt.chk('Vera creates challenge',$$insert into challenges(id,text,points) values('11111111-1111-1111-1111-111111111111','Convence a [B] a fazer uma pose',30)$$,true);
select tt.eq('assigns to everyone with a team that night (3, not referees)',$$select assign_challenge('11111111-1111-1111-1111-111111111111', date '2026-10-15')::text$$,'3');
select tt.eq('assigning again adds none',$$select assign_challenge('11111111-1111-1111-1111-111111111111', date '2026-10-15')::text$$,'0');
select tt.eq('nobody on a night without posts',$$select assign_challenge('11111111-1111-1111-1111-111111111111', date '2026-10-20')::text$$,'0');
select tt.chk('Vera moves Carla to Team Fran',$$select set_night_team('00000000-0000-0000-0000-0000000000a3', date '2026-10-15', 'fran')$$,true);
reset role;
select tt.eq('Carla is Team Fran now','select team from night_teams where user_id=''00000000-0000-0000-0000-0000000000a3''','fran');
create table tt.ids as select (select id from assignments where user_id = :'A1') as a1;
grant select on tt.ids to authenticated;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 submits proof',$$select submit_proof((select a1 from tt.ids),'00000000-0000-0000-0000-0000000000a1/p1.jpg','image')$$,true);
reset role;
update assignments set submitted_at = timestamptz '2026-10-15 22:00:00+01' where status = 'pending';
set role authenticated; select set_config('request.jwt.claim.sub',:'V',false);
select tt.chk('Vera cannot validate Team Vera (A1)',$$select review_assignment((select a1 from tt.ids), true, 30)$$,false);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'F',false);
select tt.chk('Fran validates A1 (Team Vera that night)',$$select review_assignment((select a1 from tt.ids), true, 30)$$,true);
reset role;
select tt.eq('challenge points count in the night board (31 + 30)','select points::text from team_night_board where team=''vera''','61');
