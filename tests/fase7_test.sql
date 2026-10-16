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
insert into auth.users(id,email,raw_user_meta_data) values (:'A1','a1@x','{"name":"Ana"}'),(:'A2','a2@x','{"name":"Bia"}');
update app_settings set value = '2020-01-01T00:00:00+00:00' where key = 'feed_unlock';
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 posts',$$insert into posts(drink_id,photo_path) values('d_beer20','a1/1.jpg')$$,true);
reset role;
create table tt.p as select id from posts limit 1;
grant select on tt.p to authenticated;
-- antes da migração: reação com a chave antiga
insert into reactions(post_id,user_id,kind) select id, :'A1', 'fire' from tt.p;
\i supabase/fase7.sql
select tt.eq('legacy key converted to emoji','select kind from reactions where user_id=''00000000-0000-0000-0000-0000000000a1''','🔥');
set role authenticated; select set_config('request.jwt.claim.sub',:'A2',false);
select tt.chk('A2 reacts with a keyboard emoji',$$insert into reactions(post_id,kind) values ((select id from tt.p),'🦄')$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 cannot add a second reaction to the same post (one per person)',$$insert into reactions(post_id,kind) values ((select id from tt.p),'👨‍👩‍👧‍👦')$$,false);
select tt.chk('A1 removes old and adds a flag emoji',$$delete from reactions where user_id='00000000-0000-0000-0000-0000000000a1'$$,true);
select tt.chk('A1 adds a flag emoji',$$insert into reactions(post_id,kind) values ((select id from tt.p),'🇵🇹')$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A2',false);
select tt.chk('empty reaction fails',$$insert into reactions(post_id,kind) values ((select id from tt.p),'')$$,false);
reset role;
select tt.cnt('2 reactions exist','select 1 from reactions',2);
select tt.chk('reaction longer than 16 characters is rejected',$$insert into reactions(post_id,user_id,kind) values ((select id from tt.p),'00000000-0000-0000-0000-0000000000a2','aaaaaaaaaaaaaaaaa')$$,false);
