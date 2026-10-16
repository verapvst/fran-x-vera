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
insert into auth.users(id,email,raw_user_meta_data) values (:'A1','a1@x','{"name":"Ana"}'),(:'A2','a2@x','{"name":"Bia"}'),(:'V','v@x','{"name":"Vera"}');
update profiles set role = 'referee' where id = :'V';
update app_settings set value = '2020-01-01T00:00:00+00:00' where key = 'feed_unlock';
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 beer 0.2L (1 point)',$$insert into posts(drink_id,photo_path) values('d_beer20','a1/1.jpg')$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A2',false);
select tt.chk('A2 beer 0.2L (1 point)',$$insert into posts(drink_id,photo_path) values('d_beer20','a2/1.jpg')$$,true);
select tt.chk('A2 cocktail',$$insert into posts(drink_id,photo_path) values('d_cock','a2/2.jpg')$$,true);
reset role;
\i supabase/fase8.sql
select tt.eq('before: A1 has 1 point','select points::text from leaderboard where name=''Ana''','1');
-- a Vera (referee) muda o valor da cerveja de 1 para 2
set role authenticated; select set_config('request.jwt.claim.sub',:'V',false);
select tt.chk('Vera changes beer 0.2L from 1 to 2',$$update drinks set points = 2 where id = 'd_beer20'$$,true);
reset role;
select tt.eq('old post of A1 now worth 2','select points::text from posts where photo_path=''a1/1.jpg''','2');
select tt.eq('old post of A2 now worth 2','select points::text from posts where photo_path=''a2/1.jpg''','2');
select tt.eq('cocktail post unchanged (8)','select points::text from posts where photo_path=''a2/2.jpg''','8');
select tt.eq('leaderboard Ana = 2','select points::text from leaderboard where name=''Ana''','2');
select tt.eq('leaderboard Bia = 10 (2 + 8)','select points::text from leaderboard where name=''Bia''','10');
select tt.eq('team night board follows (sum of both teams = 12)','select sum(points)::text from team_night_board','12');
-- um player não consegue mudar pontos
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 cannot change drink points (no rows)',$$update drinks set points = 999 where id = 'd_beer20'$$,true);
reset role;
select tt.eq('beer value still 2','select points::text from drinks where id=''d_beer20''','2');
-- novos posts usam o valor novo
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 posts another beer (2 hours? no: limit is per hour, one more is fine)',$$insert into posts(drink_id,photo_path) values('d_beer20','a1/2.jpg')$$,true);
reset role;
select tt.eq('new post worth 2','select points::text from posts where photo_path=''a1/2.jpg''','2');
