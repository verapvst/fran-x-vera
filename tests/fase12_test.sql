-- Fase 12: challenges para toda a gente. Corre depois de schema.sql e fase2..fase10 (ver tests/README.md).
create schema tt; grant usage on schema tt to anon, authenticated;
create function tt.chk(label text, q text, expect_ok boolean) returns text language plpgsql as $$
declare n int; begin
  begin execute q; get diagnostics n = row_count;
    return (case when expect_ok then 'PASS ' else 'FAIL(should have errored) ' end)||label||' rows='||n;
  exception when others then
    return (case when expect_ok then 'FAIL(error: '||sqlerrm||') ' else 'PASS ' end)||label||' ['||sqlerrm||']';
  end; end $$;
create function tt.eq(label text, q text, expected text) returns text language plpgsql as $$
declare v text; begin execute q into v;
  return (case when v is not distinct from expected then 'PASS ' else 'FAIL ' end)||label||' got='||coalesce(v,'null')||' expected='||expected; end $$;
\set A1 '00000000-0000-0000-0000-0000000000a1'
\set A2 '00000000-0000-0000-0000-0000000000a2'
\set A3 '00000000-0000-0000-0000-0000000000a3'
\set R1 '00000000-0000-0000-0000-0000000000b1'
\set R2 '00000000-0000-0000-0000-0000000000b2'
insert into auth.users(id,email,raw_user_meta_data) values (:'A1','a1@x','{"name":"Ana"}'),(:'A2','a2@x','{"name":"Bia"}'),(:'A3','a3@x','{"name":"Cris"}'),(:'R1','r1@x','{"name":"Vera"}'),(:'R2','r2@x','{"name":"Fran"}');
update profiles set role = 'referee' where id in (:'R1', :'R2');
update app_settings set value = '2020-01-01T00:00:00+00:00' where key = 'feed_unlock';
-- só a Ana posta esta noite; a Bia e a Cris nunca postaram
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('Ana posta',$$insert into posts(drink_id,photo_path) values('d_beer20','a1/1.jpg')$$,true);
reset role;
\i supabase/fase12.sql
\i supabase/fase12.sql
insert into challenges(text, points) values ('Faz um brinde com [B]', 10), ('Dança 1 minuto', 10), ('Desafio so da Ana', 10);
create table tt.c as select id, text from challenges; grant select on tt.c to authenticated;
set role authenticated; select set_config('request.jwt.claim.sub',:'R1',false);
select tt.eq('Vera: "toda a gente" entrega aos 3 players (mesmo sem terem postado)','select assign_challenge((select id from tt.c where text like ''Faz um brinde%''), ''all'')::text','3');
select tt.eq('repetir nao duplica','select assign_challenge((select id from tt.c where text like ''Faz um brinde%''), ''all'')::text','0');
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'R2',false);
select tt.eq('Fran: tambem entrega a toda a gente','select assign_challenge((select id from tt.c where text like ''Dan%''), ''all'', null, true)::text','3');
select tt.eq('"tonight" continua so para quem postou','select assign_challenge((select id from tt.c where text like ''Desafio%''), ''tonight'')::text','1');
select tt.chk('publico invalido recusado',$$select assign_challenge((select id from tt.c limit 1), 'xpto')$$,false);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('convidado nao atribui',$$select assign_challenge((select id from tt.c limit 1), 'all')$$,false);
reset role;
select tt.eq('os 3 players tem o challenge do brinde','select count(*)::text from assignments where text like ''Faz um brinde%''','3');
select tt.eq('o [B] foi trocado por um nome (a Ana e a unica presente: para si propria nao pode ser outra pessoa)','select count(*)::text from assignments where text like ''%[B]%''','0');
select tt.eq('o challenge secreto ficou secreto','select count(*)::text from assignments where text like ''Dan%'' and secret','3');
