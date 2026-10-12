# FRAN × VERA · 23H30 DE FESTA

Site do fim de semana de aniversário (15 a 18 de outubro, Lisboa): plano com presenças, BoozeFeed, rankings, challenges (em breve) e painel de referees.

## Como está montado

* `site/`: o site (uma página `index.html`, sem build). É a única pasta que a Netlify publica.
* `supabase/schema.sql`: toda a base de dados, regras de segurança incluídas. Pode ser corrida mais do que uma vez.
* `tests/`: testes das regras de segurança.
* Dados, contas e fotos ficam no Supabase. O site fala diretamente com o Supabase, e as regras da base de dados decidem quem pode ver e fazer o quê.

O que muda sem publicar nada novo: eventos, pontos das bebidas, hora de abertura do BoozeFeed, apagar posts (tudo pelo painel Referee).
O que precisa de publicar: o aspeto e funcionalidades do site (editar ficheiros em `site/`, commit, push; a Netlify publica sozinha em cerca de 30 segundos).

## Passos para pôr online, por ordem

### A. Supabase

1. **Project URL.** No projeto, Project Settings, API (ou o botão Connect): copia o **Project URL** (`https://xxxx.supabase.co`) e confirma que a chave publishable é a que está em `site/config.js`.
2. **Desligar a confirmação de email.** Authentication, Sign In / Providers, Email: ativo, com **Confirm email desligado**. Em Authentication, Sign In / Providers (ou Settings), confirma que **Allow new users to sign up** está ligado. Anonymous sign-ins pode ficar desligado.
3. **Limites de login.** Authentication, Rate Limits: sobe "Rate limit for sign-ups and sign-ins" (por IP, por defeito 30 em 5 minutos) para 300, e o limite de token refresh para 600. Na festa todos usam o mesmo wifi, logo o mesmo IP. Se estes campos não estiverem editáveis no teu plano, diz-me.
4. **Base de dados.** SQL Editor, New query, cola o conteúdo de `supabase/schema.sql`, Run. Deve dizer "Success. No rows returned". Se aparecer um erro, copia-o e manda-mo (pode correr-se outra vez sem problema).
5. **Conferir.** Table Editor: `events` com 11 linhas, `drinks` com 10, `admin_invites` com 2 (Vera e Fran). Storage: bucket `selfies` (public). Copia os dois **tokens** da tabela `admin_invites`: não os ponhas no GitHub nem em mensagens públicas.

### B. Site

1. Em `site/config.js`, cola o Project URL em `SUPABASE_URL`. Guarda.
2. `git add -A`, `git commit`, `git push` (a Netlify publica sozinha).

### C. Netlify

1. app.netlify.com, Add new site, Import an existing project, GitHub, repositório `fran-x-vera`, branch `main`. Build command: vazio. Publish directory: `site` (o `netlify.toml` já o define). Deploy.
2. Site configuration, Change site name: por exemplo `fran-x-vera`.
3. De volta ao Supabase, Authentication, URL Configuration: Site URL = o endereço da Netlify.

### D. Testar (10 minutos, num telemóvel)

1. Abre `ENDEREÇO/#a=TOKEN` com o teu token de Vera. O nome vem preenchido. Tira a selfie, Criar perfil. Guarda o link pessoal. A Fran faz o mesmo com o dela. Cada token só funciona uma vez.
2. Numa janela anónima, abre o endereço normal, cria um perfil de convidada (Nacional, email, selfie) e marca um evento no Plano.
3. Como referee, BoozeFeed, "Abrir agora". Como convidada, publica uma selfie. Confirma que aparece no feed e no ranking. Depois "Fechar até quinta 19:00" e apaga os posts de teste.

Se algo falhar, o site mostra a mensagem de erro. Copia-a e manda-ma.

## Regras do BoozeFeed (na base de dados, não só no site)

* Pontos vêm da tabela `drinks`: sem álcool −1, cerveja 0,2 L = 1, 0,33 L = 2, 0,5 L = 4, sidra garrafa 3, vinho 5, cocktail 8, shot 10, bebida forte 12, "Cheguei a casa" 15 (uma vez por noite).
* Máximo de 2 bebidas por hora por pessoa. Fechado até quinta às 19:00. As referees não jogam nem aparecem no ranking.

## Notas

* Quem tiver o link pessoal de alguém entra como essa pessoa. As referees podem copiar o link de qualquer convidado (Referee, Players) caso alguém o perca.
* O bucket das selfies é público: quem tiver o endereço direto de uma foto consegue vê-la.
* A chave `sb_publishable_...` é pública por desenho. **Nunca** coloques aqui a chave `sb_secret_...` nem a `service_role`.
* Acesso das referees por email e palavra-passe, reset de links e o sistema de challenges são os próximos passos e ainda não estão feitos.
