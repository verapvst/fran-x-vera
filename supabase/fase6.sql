-- Fase 6: "Bebida forte" passa a fazer parte de "Cocktail". Corre no SQL Editor. Pode ser corrido mais do que uma vez.
-- Os posts que já eram "Bebida forte" passam a "Cocktail" e valem os pontos do cocktail.
update drinks set label = 'Cocktail', hint = 'mojito, spritz, gin tónico, whisky, vodka' where id = 'd_cock';
update posts set drink_id = 'd_cock', points = (select points from drinks where id = 'd_cock') where drink_id = 'd_hard';
delete from drinks where id = 'd_hard';
