# FRAN × VERA · 23H30 DE FESTA

Site do fim de semana de aniversário (15 a 18 de outubro, Lisboa): plano com presenças, BoozeFeed, rankings, rally e challenges (em breve).

## Como está montado

* `site/` é o site (uma página `index.html`, sem build). O GitHub Pages publica só esta pasta.
* `supabase/schema.sql` é a base de dados toda, com as regras de segurança. Pode ser corrido mais do que uma vez.
* `tests/` tem os testes das regras de segurança.
* Contas, dados e fotos ficam no Supabase. O site fala diretamente com ele e as regras da base de dados decidem quem pode ver e fazer o quê.

## Publicar uma alteração

1. Edita os ficheiros em `site/`.
2. `git add -A`, `git commit -m "mensagem"`, `git push`.
3. Em cerca de 1 minuto o GitHub Pages atualiza (separador Actions). O browser pode guardar a versão antiga 10 minutos: recarrega com Ctrl+Shift+R ou acrescenta `?v=2` ao endereço.

O endereço é `https://verapvst.github.io/fran-x-vera/`. O Pages está configurado em Settings, Pages, Source: GitHub Actions (o workflow é `.github/workflows/pages.yml`).

## Supabase: o que tem de estar certo

* Authentication, Sign In / Providers, Email: **Confirm email desligado** e **Allow new users to sign up ligado**.
* Authentication, Rate Limits: sign-ups e sign-ins a 300 por 5 minutos, token refreshes a 600.
* Authentication, URL Configuration: Site URL é o endereço do site.
* SQL Editor: `supabase/schema.sql` corrido uma vez (inclui as permissões de acesso, os `GRANT`).
* Os dois links de referee estão na tabela `admin_invites` (cada um serve uma vez). **Nunca os ponhas no GitHub.**

## Segredos

* `site/config.js` tem o URL e a chave **publishable** do Supabase. Pode estar no GitHub: é pública por desenho.
* Nunca ponhas aqui a chave `secret` / `service_role`, nem tokens de referee, nem ficheiros `.env`.

## Regras do BoozeFeed (estão na base de dados, não só no site)

* Os pontos vêm da tabela `drinks`. Ninguém consegue inventar pontos.
* Fechado até quinta, 15 de outubro, às 19:00.
* Máximo de 2 bebidas por hora por pessoa. "Cheguei a casa" vale 15, uma vez por noite.
* As referees não aparecem no ranking.

## Notas honestas

* Quem tiver o link pessoal de alguém entra como essa pessoa.
* O bucket das selfies é público: quem tiver o link direto de uma foto consegue vê-la.
* O feed atualiza sozinho a cada 30 segundos e quando abres o separador.
* Os projetos gratuitos do Supabase pausam depois de uma semana sem atividade e não têm backups. Exporta os dados depois da festa se quiseres guardá-los.
