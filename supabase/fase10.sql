-- Fase 10: sem limite de bebidas por hora. Continua só o limite do "cheguei a casa" (1 por noite). Corre no SQL Editor. Pode ser corrido mais do que uma vez.
create or replace function posts_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare d drinks; n int;
begin
  if now() < get_feed_unlock() then raise exception 'O BoozeFeed ainda está fechado.'; end if;
  new.user_id := auth.uid();
  new.created_at := now();
  select * into d from drinks where id = new.drink_id;
  if not found then raise exception 'Bebida inválida'; end if;
  new.points := d.points;
  if d.kind = 'care' then
    select count(*) into n from posts p join drinks k on k.id = p.drink_id
      where p.user_id = new.user_id and k.kind = 'care' and p.created_at > now() - interval '12 hours';
    if n >= 1 then raise exception 'Limite: o check de chegada a casa conta uma vez por noite.'; end if;
  end if;
  return new;
end $$;
