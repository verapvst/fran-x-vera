-- Novo programa (13 outubro): rally passa para sábado, bingo e pre-drinks saem, jantar de sexta entra.
-- Corre no Supabase, SQL Editor. Pode ser corrido mais do que uma vez.
-- Horas provisórias: jantar 19:00-23:00 e rally 20:00-00:00 (as horas antigas do rally e do bingo + pre-drinks).
-- O total oficial continua a dar 23h30. Se mudares as horas, o total muda e aparece no site.

-- quem tinha marcado o rally de sexta tem de voltar a escolher, agora é sábado
delete from rsvps where event_id = 'e5';

-- bingo e pre-drinks saem (apaga também as presenças marcadas neles)
delete from events where id in ('e8', 'e9');

insert into events (id, day, start_time, end_time, all_day, title, place, note, rule_text, official, sort) values
 ('e1','qui','19:00','23:30',false,'THE GRAND OPENING','Corner','Início oficial da festa, apresentação do conceito, equipas e jogo.',null,true,1),
 ('e2','sex','00:00','00:30',false,'23.',null,'Meia-noite da Fran. A Fran faz 23 anos.',null,true,2),
 ('e3','sex','00:30','02:00',false,'PRAIA NO PARQUE',null,null,null,true,3),
 ('e4','sex','02:00','18:00',false,'WORK DAY',null,'Dia normal de trabalho. Não é programação oficial da festa.',null,false,4),
 ('e12','sex','19:00','23:00',false,'JANTAR','Local a definir','O sítio depende de quantas pessoas alinharem. Diz já se vais, para a organização reservar mesa.',null,true,5),
 ('e6','sex','23:00','02:00',false,'BAIRRO ALTO + ZÉ DOS BOIS','Bairro Alto',null,null,true,6),
 ('e7','sab',null,null,true,'RECOVERY DAY',null,null,null,true,7),
 ('e5','sab','20:00','00:00',false,'RALLY TASCAS & CROQUETTE','Rota a definir','Um rally pelas tascas, com diferentes challenges e pontos ao longo do percurso.',null,true,8),
 ('e10','dom','00:00','00:30',false,'24.',null,'Meia-noite da Vera. A Vera faz 24 anos.',null,true,9),
 ('e11','dom','00:30','06:00',false,'THE FINALE','Discoteca',null,null,true,10)
on conflict (id) do update set
  day = excluded.day, start_time = excluded.start_time, end_time = excluded.end_time, all_day = excluded.all_day,
  title = excluded.title, place = excluded.place, note = excluded.note, rule_text = excluded.rule_text,
  official = excluded.official, sort = excluded.sort;
