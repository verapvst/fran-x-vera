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
grant execute on all functions in schema tt to anon, authenticated;
\set A1 '00000000-0000-0000-0000-0000000000a1'
\set A2 '00000000-0000-0000-0000-0000000000a2'
\set V  '00000000-0000-0000-0000-0000000000b1'
\set F  '00000000-0000-0000-0000-0000000000b2'
insert into auth.users(id,email,raw_user_meta_data) values
 (:'A1','a1@x','{"name":"Ana"}'),(:'A2','a2@x','{"name":"Bia"}'),(:'V','v@x','{"name":"Vera"}'),(:'F','f@x','{"name":"Fran"}');
select tt.cnt('trigger created 4 profiles','select 1 from profiles',4);

-- ANON
set role anon;
select tt.cnt('anon reads events','select 1 from events',10);
select tt.cnt('anon reads drinks','select 1 from drinks',10);
select tt.cnt('anon reads profiles','select 1 from profiles',4);
select tt.cnt('anon CANNOT read member_keys','select 1 from member_keys',0);
select tt.cnt('anon CANNOT read admin_invites','select 1 from admin_invites',0);
select tt.cnt('anon CANNOT read app_settings','select 1 from app_settings',0);
select tt.chk('anon cannot insert post',$$insert into posts(drink_id,photo_path) values('d_beer20','x/y.jpg')$$,false);
select tt.chk('anon cannot insert rsvp',$$insert into rsvps(event_id,user_id) values('e1','00000000-0000-0000-0000-0000000000a1')$$,false);
select tt.chk('anon cannot set unlock',$$select set_feed_unlock(now())$$,false);
select tt.chk('anon cannot finish_signup',$$select finish_signup('k.k','a@b.c','national','p',null)$$,false);
select tt.chk('anon can read unlock time',$$select get_feed_unlock()$$,true);
select tt.chk('anon check_admin_token valid',$$select check_admin_token('TOKEN_VERA')$$,true);
select tt.cnt('anon reads leaderboard (view)','select 1 from leaderboard',4);
reset role;

-- SIGNUPS
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 finish_signup missing region fails',$$select finish_signup('a1.keyA1','ana@x.pt',null,'a1/avatar.jpg',null)$$,false);
select tt.chk('A1 finish_signup bad email fails',$$select finish_signup('a1.keyA1','nope','national','a1/avatar.jpg',null)$$,false);
select tt.chk('A1 finish_signup ok',$$select finish_signup('a1.keyA1','ana@x.pt','national','a1/avatar.jpg',null)$$,true);
select tt.chk('A1 bogus admin token fails',$$select finish_signup('a1.keyA1','ana@x.pt','national','a1/avatar.jpg','deadbeef')$$,false);
select set_config('request.jwt.claim.sub',:'A2',false);
select tt.chk('A2 finish_signup ok',$$select finish_signup('a2.keyA2','bia@x.pt','international','a2/avatar.jpg',null)$$,true);
select set_config('request.jwt.claim.sub',:'V',false);
select tt.chk('Vera admin signup via token',$$select finish_signup('b1.keyV',null,null,'b1/avatar.jpg','TOKEN_VERA')$$,true);
select set_config('request.jwt.claim.sub',:'F',false);
select tt.chk('Fran cannot reuse Vera token',$$select finish_signup('b2.keyF',null,null,'b2/avatar.jpg','TOKEN_VERA')$$,false);
select tt.chk('Fran admin signup via own token',$$select finish_signup('b2.keyF',null,null,'b2/avatar.jpg','TOKEN_FRAN')$$,true);
reset role;
select tt.cnt('2 referees exist','select 1 from profiles where role=''referee''',2);
set role anon; select tt.chk('used token now invalid',$$select 1 where check_admin_token('TOKEN_VERA') is not null$$,true); reset role;
select tt.cnt('used token returns null','select 1 where check_admin_token(''TOKEN_VERA'') is not null',0);

-- PRIVILEGE ESCALATION
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 update own role (RLS blocks)',$$update profiles set role='referee' where id='00000000-0000-0000-0000-0000000000a1'$$,true);
select tt.cnt('A1 stays player','select 1 from profiles where id=''00000000-0000-0000-0000-0000000000a1'' and role=''player''',1);
select tt.chk('A1 update events blocked',$$update events set title='HACK' where id='e1'$$,true);
select tt.cnt('event title unchanged','select 1 from events where title=''HACK''',0);
select tt.chk('A1 cannot set unlock',$$select set_feed_unlock(now())$$,false);
select tt.cnt('A1 reads own member_key','select 1 from member_keys where user_id=''00000000-0000-0000-0000-0000000000a1''',1);
select tt.cnt('A1 CANNOT read others member_keys','select 1 from member_keys where user_id<>''00000000-0000-0000-0000-0000000000a1''',0);
select tt.chk('A1 update drinks blocked',$$update drinks set points=999 where id='d_shot'$$,true);
select tt.cnt('drink points unchanged','select 1 from drinks where points=999',0);

-- FEED LOCKED
select tt.chk('A1 post while locked fails',$$insert into posts(drink_id,photo_path) values('d_beer20','a1/1.jpg')$$,false);
select set_config('request.jwt.claim.sub',:'V',false);
select tt.chk('Vera opens feed',$$select set_feed_unlock(now() - interval '1 minute')$$,true);
select tt.chk('Vera cannot post (referee)',$$insert into posts(drink_id,photo_path) values('d_beer20','b1/1.jpg')$$,false);
select tt.chk('Vera update event ok',$$update events set note='x' where id='e3'$$,true);
select tt.cnt('event updated','select 1 from events where note=''x''',1);
select tt.cnt('Vera reads all member_keys','select 1 from member_keys',4);
select tt.chk('Vera sets negative drink points',$$update drinks set points=-1 where id='d_na'$$,true);

-- POSTING
select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 post 1 ok',$$insert into posts(drink_id,photo_path,points) values('d_beer20','a1/1.jpg',999)$$,true);
select tt.cnt('points forced from drinks table','select 1 from posts where points=1 and user_id=''00000000-0000-0000-0000-0000000000a1''',1);
select tt.chk('A1 post 2 ok',$$insert into posts(drink_id,photo_path) values('d_shot','a1/2.jpg')$$,true);
select tt.chk('A1 post 3 within hour fails',$$insert into posts(drink_id,photo_path) values('d_beer20','a1/3.jpg')$$,false);
select tt.chk('A1 care ok',$$insert into posts(drink_id,photo_path) values('d_home','a1/4.jpg')$$,true);
select tt.chk('A1 care twice fails',$$insert into posts(drink_id,photo_path) values('d_home','a1/5.jpg')$$,false);
select tt.chk('A1 spoof user_id ignored',$$insert into posts(user_id,drink_id,photo_path) values('00000000-0000-0000-0000-0000000000a2','d_na','a1/6.jpg')$$,false);
select set_config('request.jwt.claim.sub',:'A2',false);
select tt.chk('A2 post ok',$$insert into posts(drink_id,photo_path) values('d_na','a2/1.jpg')$$,true);
select tt.chk('A2 spoof user_id',$$insert into posts(user_id,drink_id,photo_path) values('00000000-0000-0000-0000-0000000000a1','d_beer20','a2/2.jpg')$$,true);
reset role;
select tt.cnt('spoofed post belongs to A2, not A1','select 1 from posts where photo_path=''a2/2.jpg'' and user_id=''00000000-0000-0000-0000-0000000000a2''',1);
set role authenticated; select set_config('request.jwt.claim.sub',:'A2',false);
select tt.chk('A2 delete A1 post blocked',$$delete from posts where photo_path='a1/1.jpg'$$,true);
select tt.cnt('A1 post still there','select 1 from posts where photo_path=''a1/1.jpg''',1);
select set_config('request.jwt.claim.sub',:'V',false);
select tt.chk('Vera deletes any post',$$delete from posts where photo_path='a1/1.jpg'$$,true);
select tt.cnt('post gone','select 1 from posts where photo_path=''a1/1.jpg''',0);
reset role;

-- LEADERBOARD
set role anon;
select tt.cnt('leaderboard shows 2 players, no referees','select 1 from leaderboard',2);
select tt.cnt('leaderboard Ana = 10+15 pts','select 1 from leaderboard where name=''Ana'' and points=25',1);
reset role;

-- RSVP + IDEAS
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 rsvp self ok',$$insert into rsvps(event_id,user_id) values('e1','00000000-0000-0000-0000-0000000000a1')$$,true);
select tt.chk('A1 rsvp for A2 fails',$$insert into rsvps(event_id,user_id) values('e1','00000000-0000-0000-0000-0000000000a2')$$,false);
select tt.chk('A1 idea ok',$$insert into challenge_ideas(text) values('trocar de casaco')$$,true);
select set_config('request.jwt.claim.sub',:'A2',false);
select tt.chk('A2 delete A1 idea blocked',$$delete from challenge_ideas$$,true);
select tt.cnt('idea still there','select 1 from challenge_ideas',1);

-- STORAGE
select set_config('request.jwt.claim.sub',:'A1',false);
insert into storage.buckets(id,name,public) values('selfies','selfies',true) on conflict do nothing;
select tt.chk('A1 upload to own folder',$$insert into storage.objects(bucket_id,name) values('selfies','00000000-0000-0000-0000-0000000000a1/x.jpg')$$,true);
select tt.chk('A1 upload to A2 folder fails',$$insert into storage.objects(bucket_id,name) values('selfies','00000000-0000-0000-0000-0000000000a2/x.jpg')$$,false);
reset role; set role anon;
select tt.chk('anon upload fails',$$insert into storage.objects(bucket_id,name) values('selfies','zzz/x.jpg')$$,false);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000a2',false);
select tt.chk('rsvp upsert DO UPDATE blocked without update policy (old client)',$$insert into rsvps(event_id,user_id) values('e3','00000000-0000-0000-0000-0000000000a2') on conflict (event_id,user_id) do update set event_id=excluded.event_id$$,true);
select tt.chk('rsvp insert twice (first)',$$insert into rsvps(event_id,user_id) values('e5','00000000-0000-0000-0000-0000000000a2')$$,true);
select tt.chk('rsvp second time DO UPDATE conflict',$$insert into rsvps(event_id,user_id) values('e5','00000000-0000-0000-0000-0000000000a2') on conflict (event_id,user_id) do update set event_id=excluded.event_id$$,false);
select tt.chk('rsvp second time DO NOTHING (new client)',$$insert into rsvps(event_id,user_id) values('e5','00000000-0000-0000-0000-0000000000a2') on conflict (event_id,user_id) do nothing$$,true);
reset role;
