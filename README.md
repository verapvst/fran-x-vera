# FRAN × VERA · 23H30 DE FESTA

Site do fim de semana de aniversário (15 a 18 de outubro, Lisboa): plano com presenças, BoozeFeed, rankings, rally e challenges (em breve).

## Como está montado

* `site/` é o site (uma página `index.html`, sem build). O GitHub Pages publica só esta pasta.
* `supabase/schema.sql` é a base de dados base, com as regras de segurança. Pode ser corrido mais do que uma vez.
* `supabase/fase2.sql` acrescenta equipas, check in, challenges com prova e ranking de equipas. Corre-o **depois** de `schema.sql`, também pode ser corrido mais do que uma vez. Sem ele o site funciona na mesma, só sem a Fase 2.
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

## Fase 2: como funciona

* **Equipas:** no painel referee, separador Equipas, "Gerar equipas" equilibra por momento (o que cada pessoa marcou no Plano), tamanho e Nacional/Internacional. Há pré-visualização e podes trocar pessoas antes de confirmar.
* **Check in:** o player carrega no botão do momento, de 1 hora antes até 1 hora depois (a base de dados confirma a hora). As referees fazem check in por quem se esqueceu.
* **Challenges:** as referees escrevem o challenge (`[B]` vira o nome de outra pessoa presente) e atribuem-no a todos os que fizeram check in num momento. O player envia foto ou vídeo (máx. 25 MB). A Vera valida a Team Fran e a Fran valida a Team Vera, e isto é imposto na base de dados.
* **Pontuação da equipa:** pontos totais ÷ pessoas com pelo menos um check in (`team_score` em `supabase/fase2.sql`, e `teamScore` em `site/index.html`).
* **Quem vê o quê:** só as referees veem quantas pessoas vão a cada momento. Provas por validar só aparecem ao próprio e às referees. Provas aprovadas aparecem a todos em "Provas da festa".
* **Nota:** o bucket `proofs` é público como o das selfies: quem tiver o link direto de uma prova consegue vê-la.

## Regras do BoozeFeed (estão na base de dados, não só no site)

* Os pontos vêm da tabela `drinks`. Ninguém consegue inventar pontos.
* Fechado até quinta, 15 de outubro, às 19:00.
* Máximo de 2 bebidas por hora por pessoa. "Cheguei a casa" vale 15, uma vez por noite.
* As referees também jogam no BoozeFeed e aparecem no ranking individual (nos challenges não participam).

## Notas honestas

* Quem tiver o link pessoal de alguém entra como essa pessoa.
* O bucket das selfies é público: quem tiver o link direto de uma foto consegue vê-la.
* O feed atualiza sozinho a cada 30 segundos e quando abres o separador.
* Os projetos gratuitos do Supabase pausam depois de uma semana sem atividade e não têm backups. Exporta os dados depois da festa se quiseres guardá-los.
