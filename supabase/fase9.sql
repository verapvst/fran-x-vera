-- Fase 9: pontos das bebidas proporcionais ao álcool (1 ponto ≈ 6 g de álcool). Corre no SQL Editor. Pode ser corrido mais do que uma vez.
-- Os posts já feitos passam a valer o valor novo (trigger da fase 8).
update drinks set points = v.p from (values
  ('d_na', 0), ('d_beer20', 1), ('d_beer33', 2), ('d_beer50', 4), ('d_sidra', 2),
  ('d_wine', 3), ('d_cock', 4), ('d_shot', 3), ('d_home', 5)
) as v(id, p) where drinks.id = v.id;

-- pontos por hora de presença: muda no painel Pontos (presence_points_per_hour = 1)
