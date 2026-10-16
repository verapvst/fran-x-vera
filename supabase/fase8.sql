-- Fase 8: mudar os pontos de uma bebida atualiza também os posts que já foram feitos. Corre no SQL Editor. Pode ser corrido mais do que uma vez.

-- quando o valor de uma bebida muda, todos os posts dessa bebida passam a valer o valor novo
create or replace function drinks_sync_points() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update posts set points = new.points where drink_id = new.id and points is distinct from new.points;
  return new;
end $$;
drop trigger if exists drinks_points_sync on drinks;
create trigger drinks_points_sync after update of points on drinks
  for each row when (old.points is distinct from new.points) execute function drinks_sync_points();

-- acerta já os posts que ficaram com um valor antigo (por exemplo, depois de mudares de 1 para 2 antes desta fase)
update posts p set points = d.points from drinks d where d.id = p.drink_id and p.points is distinct from d.points;
