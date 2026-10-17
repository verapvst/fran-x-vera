-- Fase 11: Rally por etapas. Corre depois de schema.sql e fase2..fase10 (ver tests/README.md). Este ficheiro corre a fase 11 duas vezes.
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
\set R1 '00000000-0000-0000-0000-0000000000b1'
insert into auth.users(id,email,raw_user_meta_data) values (:'A1','a1@x','{"name":"Ana"}'),(:'A2','a2@x','{"name":"Bia"}'),(:'R1','r1@x','{"name":"Ref"}');
update profiles set role = 'referee' where id = :'R1';
\i supabase/fase11.sql
\i supabase/fase11.sql
select tt.cnt('so ha uma paragem de inicio depois de correr duas vezes','select 1 from rally_stops where kind=''start''',1);
select tt.eq('a Portugalia vem visivel e com as notas fechadas','select state from rally_stops where kind=''start''','revealed');
-- visitante sem conta
set role anon;
select tt.cnt('anon ve a paragem revelada','select 1 from rally_stops',1);
select tt.cnt('anon ve a paragem no rally_board','select 1 from rally_board',1);
select tt.chk('anon nao escreve paragens',$$insert into rally_stops(name) values ('x')$$,false);
reset role;
-- referee acrescenta uma paragem secreta
set role authenticated; select set_config('request.jwt.claim.sub',:'R1',false);
select tt.chk('referee acrescenta paragem secreta',$$insert into rally_stops(position,name,address,lat,lng,state,time_label) values (2,'Tosco','R. Alcântara 14A',38.7061,-9.1757,'hidden','20:15')$$,true);
select tt.cnt('referee ve as duas paragens','select 1 from rally_stops',2);
select tt.cnt('referee ve as duas no rally_board','select 1 from rally_board',2);
reset role; select set_config('request.jwt.claim.sub','',false);
create table tt.hid as select id from rally_stops where name='Tosco'; grant select on tt.hid to authenticated;
set role anon;
select tt.cnt('anon continua a ver so uma (a secreta nao vaza)','select 1 from rally_stops',1);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.cnt('convidado ve so uma paragem','select 1 from rally_stops',1);
select tt.chk('convidado nao escreve paragens',$$insert into rally_stops(name) values ('x')$$,false);
select tt.chk('convidado nao muda estado (0 linhas atualizadas)',$$update rally_stops set state='open'$$,true);
reset role;
select tt.cnt('estado nao mudou','select 1 from rally_stops where state=''open''',0);
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('nota fechada: convidado nao avalia paragem so revelada',$$insert into rally_ratings(stop_id,croquete,tasca) select id,9,8 from rally_stops where kind='start'$$,false);
reset role;
-- referee abre as notas da Portugalia
set role authenticated; select set_config('request.jwt.claim.sub',:'R1',false);
select tt.chk('referee abre as notas',$$update rally_stops set state='open' where kind='start'$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('convidado avalia 9 e 8',$$insert into rally_ratings(stop_id,croquete,tasca) select id,9,8 from rally_stops where kind='start'$$,true);
select tt.chk('nota 11 e recusada',$$update rally_ratings set croquete=11$$,false);
select tt.chk('nota 0 e recusada',$$update rally_ratings set tasca=0$$,false);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A2',false);
select tt.chk('outro convidado avalia 7 e 6',$$insert into rally_ratings(stop_id,croquete,tasca) select id,7,6 from rally_stops where kind='start'$$,true);
select tt.cnt('cada um so ve a sua nota','select 1 from rally_ratings',1);
select tt.chk('nao avalia paragem secreta (mesmo sabendo o id)',$$insert into rally_ratings(stop_id,croquete,tasca) select id,5,5 from tt.hid$$,false);
reset role;
select tt.cnt('referee ve as duas notas (como superuser)','select 1 from rally_ratings',2);
-- medias escondidas
select set_config('request.jwt.claim.sub','',false);
set role anon;
select tt.eq('anon ve 2 notas no total','select votes::text from rally_board',2::text);
select tt.eq('anon nao ve a media do croquete','select croquete::text from rally_board',null);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.eq('convidado nao ve a media enquanto esta escondida','select croquete::text from rally_board',null);
select tt.chk('convidado nao revela resultados',$$select rally_set_results(true)$$,false);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'R1',false);
select tt.eq('referee ve a media ao vivo (8)','select croquete::text from rally_board where name=''Portugália Belém''','8.00');
select tt.chk('referee revela os resultados',$$select rally_set_results(true)$$,true);
reset role;
set role anon;
select set_config('request.jwt.claim.sub','',false);
select tt.eq('depois de revelar, anon ve a media 8','select croquete::text from rally_board','8.00');
select tt.eq('rally_results_open e true','select rally_results_open()::text','true');
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'R1',false);
select tt.chk('referee volta a esconder',$$select rally_set_results(false)$$,true);
reset role;
select tt.eq('resultados escondidos outra vez','select rally_results_open()::text','false');
-- estados
set role authenticated; select set_config('request.jwt.claim.sub',:'R1',false);
select tt.chk('referee marca visitada',$$update rally_stops set state='visited' where kind='start'$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('numa paragem visitada ainda se pode mudar a nota',$$update rally_ratings set croquete=10$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'R1',false);
select tt.chk('referee ignora a paragem',$$update rally_stops set state='skipped' where kind='start'$$,true);
reset role;
set role authenticated; select set_config('request.jwt.claim.sub',:'A1',false);
select tt.chk('numa paragem ignorada ja nao se muda a nota',$$update rally_ratings set croquete=1$$,false);
reset role;
-- dados seguros
set role authenticated; select set_config('request.jwt.claim.sub',:'R1',false);
select tt.chk('foto javascript: e recusada',$$update rally_stops set photo_url='javascript:alert(1)' where name='Tosco'$$,false);
select tt.chk('foto http (sem s) e recusada',$$update rally_stops set photo_url='http://x.pt/a.jpg' where name='Tosco'$$,false);
select tt.chk('foto https e aceite',$$update rally_stops set photo_url='https://x.pt/a.jpg' where name='Tosco'$$,true);
select tt.chk('estado invalido e recusado',$$update rally_stops set state='abc' where name='Tosco'$$,false);
select tt.chk('latitude fora do intervalo e recusada',$$update rally_stops set lat=100 where name='Tosco'$$,false);
select tt.chk('referee apaga paragem (e as notas dela)',$$delete from rally_stops where kind='start'$$,true);
reset role;
select tt.cnt('notas apagadas em cascata','select 1 from rally_ratings',0);
