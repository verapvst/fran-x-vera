-- Fase 7: reagir com qualquer emoji do teclado. Corre depois de fase3.sql, no SQL Editor. Pode ser corrido mais do que uma vez.
-- A reação passa a guardar o próprio emoji. As antigas ('fire', 'beer', 'laugh', 'kiss') convertem-se.
alter table reactions drop constraint if exists reactions_kind_check;
update reactions set kind = case kind when 'fire' then '🔥' when 'beer' then '🍻' when 'laugh' then '😂' when 'kiss' then '💋' else kind end;
alter table reactions add constraint reactions_kind_check check (char_length(kind) between 1 and 16);
