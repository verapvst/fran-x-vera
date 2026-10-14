# FRAN × VERA · 23H30 DE FESTA

Site do fim de semana de aniversário (15 a 18 de outubro, Lisboa): plano com presenças, BoozeFeed, rankings, rally e challenges (em breve).

## Como está montado

* `site/` é o site (uma página `index.html`, sem build). O GitHub Pages publica só esta pasta.
* `supabase/schema.sql` é a base de dados base, com as regras de segurança. Pode ser corrido mais do que uma vez.
* `supabase/fase2.sql` acrescenta challenges com prova e a função da pontuação de equipa. Corre-o **depois** de `schema.sql`.
* `supabase/fase3.sql` acrescenta a presença, as reações e o programa final. Corre-o **depois** de `fase2.sql`.
* `supabase/fase4.sql` torna a equipa fixa, acrescenta os públicos e segredos dos challenges e o rally com notas. Corre-o **depois** de `fase3.sql`. Todos podem ser corridos mais do que uma vez. Sem a fase 4 o site funciona na mesma, mas as equipas continuam por noite (fase 3).
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

## Como funciona o jogo (fase 3)

* **Só se vota no jantar.** Ninguém se inscreve nos outros momentos. O Plano só tem o botão "Vou ao jantar".
* **Equipa fixa, atribuída no primeiro post de sempre.** Quem chega vai para a equipa com menos gente que já postou nessa noite (empate: a com menos membros; empate: Team Vera). Mantém-se nas noites todas. A noite vai das 08:00 às 08:00, hora de Lisboa. As referees não têm equipa mas jogam no BoozeFeed.
* **Pontos:** bebidas + horas na festa (5 pontos por hora entre o primeiro e o último post da noite, máximo 12 horas) + challenges aprovados. Para mudar o valor: `update app_settings set value = '8' where key = 'presence_points_per_hour';` (e `PRESENCE_RATE` em `site/index.html`, que só serve para o texto e o modo demonstração).
* **Pontuação da equipa:** pontos totais ÷ pessoas da equipa **que postaram nessa noite** (`team_score` em `supabase/fase2.sql`). O ranking mostra cada noite e o total.
* **Hora dos posts:** é sempre a do servidor, ninguém inventa horas.
* **Reações:** cada pessoa reage a cada foto com uma reação (fogo, cerveja, riso, beijo), e carregar outra vez tira-a.
* **Challenges:** as referees criam e entregam a quem já postou nessa noite: todos, uma equipa, nacionais, internacionais ou pessoas específicas (lista só de quem já postou), secretos ou à vista de todos. "Sortear" dá a cada pessoa presente um da lista que ainda não tenha recebido. "Avisar por email" envia um email a quem tem challenges novos (precisa do `apps-script/Code.gs` atualizado). A Vera valida a Team Fran e a Fran valida a Team Vera.
* **Rally:** as referees adicionam as paragens (Painel referee, Mais, Rally). Os players dão nota de 1 a 5 ao croquete e à tasca, e a página mostra o melhor croquete.
* **Painel referee:** Jantar (quem vai), Hoje (quem já postou, com a equipa e troca manual), Challenges, Validar, e Mais (Eventos, Pontos, Players, Rally).
* **Quem vê o quê:** só as referees veem quantas pessoas vão ao jantar. Provas por validar só aparecem ao próprio e às referees.
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
