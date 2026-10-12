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

Tudo deve dizer PASS. Corre isto sempre que mudares `supabase/schema.sql`.
Isto NAO substitui testar num projeto Supabase real e em telemoveis reais.
