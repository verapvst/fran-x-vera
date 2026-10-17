-- Fase 12: challenges para toda a gente (todos os players com conta, tenham ou não postado esta noite). Corre no SQL Editor. Pode ser corrido mais do que uma vez.
-- Os outros públicos ficam como estavam (só quem já postou esta noite). Tanto a Vera como a Fran (referees) podem usar qualquer público.
create or replace function assign_challenge(p_challenge uuid, p_audience text default 'tonight', p_users uuid[] default null, p_secret boolean default false) returns int
language plpgsql security definer set search_path = public as $$
declare c challenges; r record; tgt record; n int := 0;
begin
  if not is_ref() then raise exception 'Só as referees atribuem challenges.'; end if;
  if p_audience not in ('all', 'tonight', 'vera', 'fran', 'national', 'international', 'users') then raise exception 'Público inválido.'; end if;
  select * into c from challenges where id = p_challenge;
  if not found then raise exception 'Challenge inválido'; end if;
  for r in
    select x.id, x.team from (
      select pt.user_id as id, pt.team, pt.region from present_tonight() pt
       where p_audience <> 'all'
         and (p_audience = 'tonight'
              or (p_audience in ('vera', 'fran') and pt.team = p_audience)
              or (p_audience in ('national', 'international') and pt.region = p_audience)
              or (p_audience = 'users' and pt.user_id = any (coalesce(p_users, '{}'))))
      union all
      select p.id, tm.team, p.region from profiles p left join team_members tm on tm.user_id = p.id
       where p_audience = 'all' and p.role = 'player'
    ) x
    where not exists (select 1 from assignments a where a.challenge_id = c.id and a.user_id = x.id)
  loop
    select q.user_id as id, q.name into tgt from present_tonight() q
     where q.user_id <> r.id
     order by (q.team is distinct from r.team) desc, random() limit 1;
    insert into assignments (challenge_id, user_id, target_id, text, points, secret)
      values (c.id, r.id, tgt.id, replace(c.text, '[B]', coalesce(tgt.name, 'alguém')), c.points, coalesce(p_secret, false));
    n := n + 1;
  end loop;
  return n;
end $$;
grant execute on function assign_challenge(uuid, text, uuid[], boolean) to authenticated;
