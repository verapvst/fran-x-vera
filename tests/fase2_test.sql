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
grant execute on all functions in schema tt to anon, authenticated;
\set A1 '00000000-0000-0000-0000-0000000000a1'
\set A2 '00000000-0000-0000-0000-0000000000a2'
\set V  '00000000-0000-0000-0000-0000000000b1'
\set F  '00000000-0000-0000-0000-0000000000b2'
insert into auth.users(id,email,raw_user_meta_data) values
 (:'A1','a1@x','{"name":"Ana"}'),(:'A2','a2@x','{"name":"Bia"}'),(:'V','v@x','{"name":"Vera"}'),(:'F','f@x','{"name":"Fran"}');
update profiles set role = 'referee' where id in (:'V', :'F');

-- eventos que já não estão no programa mas servem de casos de teste (não oficial e dia inteiro)
insert into events(id,day,start_time,end_time,all_day,title,official,sort) values ('e4','sex','02:00','18:00',false,'WORK DAY',false,4),('e7','sab',null,null,true,'RECOVERY DAY',true,7) on conflict do nothing;

-- janela do check in (função pura, hora de Lisboa, outubro = UTC+1)
select tt.eq('check in abre 1h antes', $$select checkin_open(e, '2026-10-15 18:00:00+01') from events e where id='e1'$$, 'true');
select tt.eq('check in fechado 2h antes', $$select checkin_open(e, '2026-10-15 16:59:00+01') from events e where id='e1'$$, 'false');
select tt.eq('check in aberto até 1h depois (passa a meia-noite)', $$select checkin_open(e, '2026-10-16 00:30:00+01') from events e where id='e1'$$, 'true');
select tt.eq('check in fechado depois disso', $$select checkin_open(e, '2026-10-16 00:31:00+01') from events e where id='e1'$$, 'false');
select tt.eq('momento que passa a meia-noite (Zé dos Bois, 23:00-02:00)', $$select checkin_open(e, '2026-10-17 01:30:00+01') from events e where id='e6'$$, 'true');
select tt.eq('dia inteiro aberto durante o dia', $$select checkin_open(e, '2026-10-17 12:00:00+01') from events e where id='e7'$$, 'true');
select tt.eq('work day nunca tem check in', $$select checkin_open(e, '2026-10-16 10:00:00+01') from events e where id='e4'$$, 'false');
select tt.eq('team_score 100 / 4', $$select team_score(100, 4)::text$$, '25.0');
select tt.eq('team_score sem presentes é 0', $$select team_score(100, 0)::text$$, '0');

-- EQUIPAS
select set_config('request.jwt.claim.sub','',false); set role anon;
select tt.chk('anon cannot set teams',$$select set_teams('{}'::jsonb)$$,false);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('player cannot set teams',$$select set_teams('{"00000000-0000-0000-0000-0000000000a1":"vera"}'::jsonb)$$,false);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'V',false);
select tt.chk('referee sets teams',$$select set_teams('{"00000000-0000-0000-0000-0000000000a1":"fran","00000000-0000-0000-0000-0000000000a2":"vera"}'::jsonb)$$,true);
select tt.chk('referee cannot set invalid team',$$select set_teams('{"00000000-0000-0000-0000-0000000000a1":"outra"}'::jsonb)$$,false);
select tt.eq('Vera is Team Vera', $$select ref_team()$$, 'vera');
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
update profiles set team='vera' where id='00000000-0000-0000-0000-0000000000a1';
reset role;
select tt.cnt('A1 is in Team Fran','select 1 from profiles where id=''00000000-0000-0000-0000-0000000000a1'' and team=''fran''',1);
select tt.cnt('referee profile team not touched','select 1 from profiles where role=''referee'' and team is not null',0);

-- CHECK IN
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('player check in on non-official event fails',$$insert into checkins(event_id) values('e4')$$,false);
select tt.chk('player check in outside window fails (e1 is in 2026-10-15)',$$insert into checkins(event_id) values('e1')$$, (now() between timestamptz '2026-10-15 18:00:00+01' and timestamptz '2026-10-16 00:30:00+01'));
select tt.chk('player cannot check in someone else',$$insert into checkins(event_id,user_id) values('e7','00000000-0000-0000-0000-0000000000a2')$$, (now() between timestamptz '2026-10-17 00:00:00+01' - interval '1 hour' and timestamptz '2026-10-18 00:00:00+01' + interval '1 hour'));
reset role;
delete from checkins;
set role authenticated; select set_config('request.jwt.claim.sub',:'V',false);
select tt.chk('referee checks in A1 (any time)',$$insert into checkins(event_id,user_id) values('e1','00000000-0000-0000-0000-0000000000a1')$$,true);
select tt.chk('referee checks in A2 (any time)',$$insert into checkins(event_id,user_id) values('e1','00000000-0000-0000-0000-0000000000a2')$$,true);
reset role;
select set_config('request.jwt.claim.sub','',false); set role anon; select tt.cnt('anon reads checkins','select 1 from checkins',2);
select tt.chk('anon cannot insert checkin',$$insert into checkins(event_id,user_id) values('e1','00000000-0000-0000-0000-0000000000a1')$$,false);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('player cannot delete checkin',$$delete from checkins where user_id='00000000-0000-0000-0000-0000000000a2'$$,true);
reset role;
select tt.cnt('...and nothing was deleted','select 1 from checkins',2);

-- CHALLENGES
select set_config('request.jwt.claim.sub','',false); set role anon; select tt.cnt('anon cannot read challenge templates','select 1 from challenges',0); reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('player cannot create challenge',$$insert into challenges(text,points) values('x',10)$$,false);
select tt.chk('player cannot assign',$$select assign_challenge(gen_random_uuid(),'e1')$$,false);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'V',false);
select tt.chk('referee creates challenge',$$insert into challenges(id,text,points) values('11111111-1111-1111-1111-111111111111','Convence a [B] a fazer uma pose',30)$$,true);
select tt.chk('referee rejects challenge over 500 points',$$insert into challenges(text,points) values('x',501)$$,false);
select tt.chk('referee assigns to everyone checked in at e1',$$select assign_challenge('11111111-1111-1111-1111-111111111111','e1')$$,true);
select tt.chk('assigning again does not duplicate',$$select assign_challenge('11111111-1111-1111-1111-111111111111','e1')$$,true);
select tt.cnt('referee sees 2 assignments','select 1 from assignments',2);
reset role;
select tt.cnt('exactly 2 assignments exist','select 1 from assignments',2);
select tt.cnt('[B] was replaced by the other player name','select 1 from assignments where text not like ''%[B]%'' and (text like ''%Ana%'' or text like ''%Bia%'')',2);
select tt.cnt('target is the other player (opposite team)','select 1 from assignments a where a.target_id <> a.user_id',2);
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.cnt('A1 sees only own assignment','select 1 from assignments',1);
reset role;
select set_config('request.jwt.claim.sub','',false); set role anon; select tt.cnt('anon sees no assignments yet','select 1 from assignments',0); reset role;

-- PROVAS
create table tt.ids as select (select id from assignments where user_id='00000000-0000-0000-0000-0000000000a1') as a1;
grant select on tt.ids to authenticated;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('A1 uploads proof to own folder',$$insert into storage.objects(bucket_id,name) values('proofs','00000000-0000-0000-0000-0000000000a1/p1.jpg')$$,true);
select tt.chk('A1 upload to other folder fails',$$insert into storage.objects(bucket_id,name) values('proofs','00000000-0000-0000-0000-0000000000a2/p1.jpg')$$,false);
update assignments set status='approved', points_awarded=500;
select tt.cnt('A1 direct update changed nothing','select 1 from assignments where status=''approved''',0);
select tt.chk('A1 submit proof with someone else''s path fails',$$select submit_proof((select id from assignments where user_id='00000000-0000-0000-0000-0000000000a1'),'00000000-0000-0000-0000-0000000000a2/p1.jpg','image')$$,false);
select tt.chk('A1 submit proof with bad type fails',$$select submit_proof((select id from assignments where user_id='00000000-0000-0000-0000-0000000000a1'),'00000000-0000-0000-0000-0000000000a1/p1.jpg','audio')$$,false);
select tt.chk('A1 submits proof',$$select submit_proof((select id from assignments where user_id='00000000-0000-0000-0000-0000000000a1'),'00000000-0000-0000-0000-0000000000a1/p1.jpg','image')$$,true);
select tt.chk('A1 cannot submit twice while pending',$$select submit_proof((select id from assignments where user_id='00000000-0000-0000-0000-0000000000a1'),'00000000-0000-0000-0000-0000000000a1/p2.jpg','image')$$,false);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A2',false);
select tt.cnt('A2 sees only own assignment (A1 pending proof is hidden)','select 1 from assignments',1);
select tt.chk('A2 cannot submit A1''s challenge',$$select submit_proof((select a1 from tt.ids),'00000000-0000-0000-0000-0000000000a2/p9.jpg','image')$$,false);
select tt.chk('A2 submits own proof',$$select submit_proof((select id from assignments where user_id='00000000-0000-0000-0000-0000000000a2'),'00000000-0000-0000-0000-0000000000a2/p2.mp4','video')$$,true);
reset role;
select set_config('request.jwt.claim.sub','',false); set role anon; select tt.cnt('anon cannot see pending proofs','select 1 from assignments',0); reset role;

-- VALIDAÇÃO (a referee da equipa contrária)
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('player cannot review',$$select review_assignment((select id from assignments where user_id='00000000-0000-0000-0000-0000000000a1'), true, 30)$$,false);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'F',false);
select tt.chk('Fran cannot validate Team Fran (A1)',$$select review_assignment((select id from assignments where user_id='00000000-0000-0000-0000-0000000000a1'), true, 30)$$,false);
select tt.chk('Fran cannot give more than 500',$$select review_assignment((select id from assignments where user_id='00000000-0000-0000-0000-0000000000a2'), true, 501)$$,false);
select tt.chk('Fran validates Team Vera (A2): rejected',$$select review_assignment((select id from assignments where user_id='00000000-0000-0000-0000-0000000000a2'), false)$$,true);
select tt.chk('Fran cannot decide twice',$$select review_assignment((select id from assignments where user_id='00000000-0000-0000-0000-0000000000a2'), true, 10)$$,false);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'V',false);
select tt.chk('Vera cannot validate Team Vera',$$select review_assignment((select id from assignments where user_id='00000000-0000-0000-0000-0000000000a2'), true, 10)$$,false);
select tt.chk('Vera validates Team Fran (A1), 25 points',$$select review_assignment((select id from assignments where user_id='00000000-0000-0000-0000-0000000000a1'), true, 25)$$,true);
reset role;
select tt.eq('A1 got 25 points','select points_awarded::text from assignments where user_id=''00000000-0000-0000-0000-0000000000a1''','25');
select tt.eq('A2 rejected, 0 points','select status||points_awarded from assignments where user_id=''00000000-0000-0000-0000-0000000000a2''','rejected0');
select set_config('request.jwt.claim.sub','',false); set role anon;
select tt.cnt('anon now sees the approved one','select 1 from assignments',1);
select tt.eq('leaderboard counts challenge points for A1','select points::text from leaderboard where name=''Ana''','25');
select tt.eq('leaderboard shows A1 team','select team from leaderboard where name=''Ana''','fran');
select tt.eq('team_board Fran: 25 points, 1 present, score 25.0','select points||''/''||present||''/''||score from team_board where team=''fran''','25/1/25.0');
select tt.eq('team_board Vera: 0 points, 1 present, score 0.0','select points||''/''||present||''/''||score from team_board where team=''vera''','0/1/0.0');
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A2',false);
select tt.chk('A2 can resubmit after a rejection',$$select submit_proof((select id from assignments where user_id='00000000-0000-0000-0000-0000000000a2'),'00000000-0000-0000-0000-0000000000a2/p3.jpg','video')$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'F',false);
select tt.chk('referee can delete an assignment',$$delete from assignments where user_id='00000000-0000-0000-0000-0000000000a2'$$,true);
reset role;
select tt.cnt('...and it is gone','select 1 from assignments where user_id=''00000000-0000-0000-0000-0000000000a2''',0);

-- RSVPs: só as referees veem quem vai a quê
insert into rsvps(event_id,user_id) values ('e1','00000000-0000-0000-0000-0000000000a1'),('e1','00000000-0000-0000-0000-0000000000a2'),('e3','00000000-0000-0000-0000-0000000000a2');
select set_config('request.jwt.claim.sub','',false); set role anon;
select tt.cnt('anon sees no rsvps','select 1 from rsvps',0);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.cnt('A1 sees only own rsvps','select 1 from rsvps',1);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'V',false);
select tt.cnt('referee sees all rsvps','select 1 from rsvps',3);
reset role;
