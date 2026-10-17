# Testes das regras de seguranca

`rls_test.sql` verifica, num Postgres local, quem pode ler e escrever o que (69 verificacoes: visitantes, convidados, referees, limite de bebidas, BoozeFeed fechado, links de referee de uso unico, fotos).
`stub.sql` simula as partes do Supabase que o SQL usa (`auth.uid()`, `storage`, papeis anon e authenticated).

Como correr (precisa de PostgreSQL 15 ou mais):

```
createdb fv_test
psql -d fv_test -f tests/stub.sql
psql -d fv_test -f supabase/schema.sql
TV=$(psql -d fv_test -Atc "select token from admin_invites where name='Vera'")
TF=$(psql -d fv_test -Atc "select token from admin_invites where name='Fran'")
sed "s/TOKEN_VERA/$TV/g; s/TOKEN_FRAN/$TF/g" tests/rls_test.sql | psql -d fv_test -At | grep -E "^(PASS|FAIL)"
```

Fase 2 (equipas, check in, challenges, validação, rankings): corre também `supabase/fase2.sql` e usa `tests/fase2_test.sql`:

```
psql -d fv_test -f supabase/fase2.sql
sed "s/TOKEN_VERA/$TV/g; s/TOKEN_FRAN/$TF/g" tests/fase2_test.sql | psql -d fv_test -At | grep -E "^(PASS|FAIL)"
```

Fase 3 (equipas por noite, presença, reações, challenges por noite): corre também `supabase/fase3.sql` e usa `tests/fase3_test.sql`:

```
psql -d fv_test -f supabase/fase3.sql
sed "s/TOKEN_VERA/$TV/g; s/TOKEN_FRAN/$TF/g" tests/fase3_test.sql | psql -d fv_test -At | grep -E "^(PASS|FAIL)"
```

Fase 4 (equipa fixa, públicos, segredos, rally): corre `supabase/fase4.sql` e usa `tests/fase4_test.sql`:

```
psql -d fv_test -f supabase/fase4.sql
sed "s/TOKEN_VERA/$TV/g; s/TOKEN_FRAN/$TF/g" tests/fase4_test.sql | psql -d fv_test -At | grep -E "^(PASS|FAIL)"
```

Fase 5 (referees nas equipas, detalhe dos pontos): `supabase/fase5.sql` e `tests/fase5_test.sql` (corre com a fase 2, 3 e 4 já aplicadas; o ficheiro de teste aplica a fase 5 por si).

Fase 8 (pontos de uma bebida mudam nos posts antigos): `tests/fase8_test.sql` (corre com as fases 2 a 5; o ficheiro de teste aplica a fase 8 por si).

Os testes de `fase2_test.sql` correm só com a fase 2, e os de `fase3_test.sql` só com a fase 2 e 3 (sem a fase 4), porque cada fase seguinte muda as equipas e o check in.

Tudo deve dizer PASS. Corre isto sempre que mudares `supabase/schema.sql`.
Isto NAO substitui testar num projeto Supabase real e em telemoveis reais.

Fase 11 (Rally por etapas: paragens secretas, notas de 1 a 10, resultados escondidos): corre `supabase/fase9.sql`, `supabase/fase10.sql` e usa `tests/fase11_test.sql` (que corre `supabase/fase11.sql` duas vezes). Precisa de uma base com `stub.sql`, `schema.sql` e `fase2` a `fase10` já corridos:

```
psql -d fv_test -At -f tests/fase11_test.sql | grep -E "^(PASS|FAIL)"
```
