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
\set V  '00000000-0000-0000-0000-0000000000b1'
\set F  '00000000-0000-0000-0000-0000000000b2'
insert into auth.users(id,email,raw_user_meta_data) values
 (:'A1','a1@x','{"name":"Ana"}'),(:'A2','a2@x','{"name":"Bia"}'),(:'V','v@x','{"name":"Vera"}'),(:'F','f@x','{"name":"Fran"}');
update profiles set role = 'referee' where id in (:'V', :'F');
update app_settings set value = '2020-01-01T00:00:00+00:00' where key = 'feed_unlock';
-- migração: referees já existentes entram na equipa do nome
\i supabase/fase5.sql
select tt.eq('Vera is Team Vera','select team from team_members where user_id=''00000000-0000-0000-0000-0000000000b1''','vera');
select tt.eq('Fran is Team Fran','select team from team_members where user_id=''00000000-0000-0000-0000-0000000000b2''','fran');

-- primeiro post: a referee mantém a equipa; os players equilibram contando as referees
set role authenticated; select set_config('request.jwt.claim.sub',:'V',false);
select tt.chk('Vera posts (cocktail)',$$insert into posts(drink_id,photo_path) values('d_cock','b1/1.jpg')$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'F',false);
select tt.chk('Fran posts (beer)',$$insert into posts(drink_id,photo_path) values('d_beer20','b2/1.jpg')$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 posts (first player)',$$insert into posts(drink_id,photo_path) values('d_beer33','a1/1.jpg')$$,true);
reset role;
select tt.eq('A1 goes to Team Vera (1 vs 1 tonight, tie: fewer members, tie: Vera)','select team from team_members where user_id=''00000000-0000-0000-0000-0000000000a1''','vera');
set role authenticated; select set_config('request.jwt.claim.sub',:'A2',false);
select tt.chk('A2 posts',$$insert into posts(drink_id,photo_path) values('d_beer20','a2/1.jpg')$$,true);
reset role;
select tt.eq('A2 goes to Team Fran (Vera 2 tonight vs Fran 1)','select team from team_members where user_id=''00000000-0000-0000-0000-0000000000a2''','fran');
select tt.cnt('4 members','select 1 from team_members',4);
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('player cannot change referee team',$$select set_team('00000000-0000-0000-0000-0000000000b1','fran')$$,false);
reset role;
select tt.eq('team_totals Vera 2, Fran 2','select (select members from team_totals where team=''vera'')||''/''||(select members from team_totals where team=''fran'')','2/2');

-- detalhe dos pontos
update posts set created_at = timestamptz '2026-10-15 20:00:00+01' where user_id = :'A1';
insert into posts(user_id,drink_id,points,photo_path,created_at) values (:'A1','d_shot',10,'a1/2.jpg',timestamptz '2026-10-15 23:00:00+01');
update posts set created_at = timestamptz '2026-10-15 23:00:00+01' where photo_path = 'a1/2.jpg';
set role anon; select set_config('request.jwt.claim.sub','',false);
select tt.eq('Ana: drinks 12, presence 15 (3h x 5), challenges 0, total 27','select drink_points||''/''||presence_points||''/''||challenge_points||''/''||points from leaderboard where name=''Ana''','12/15/0/27');
select tt.eq('Ana hours 3.0','select hours::text from leaderboard where name=''Ana''','3.0');
select tt.eq('Vera shows her team on the leaderboard','select team from leaderboard where name=''Vera''','vera');
reset role;
select tt.eq('night board counts referees as team members (Team Vera: Ana + Vera)','select people::text from team_night_board where team=''vera'' and night = night_of(now())','1');
