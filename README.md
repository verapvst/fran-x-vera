# FRAN × VERA · A memória da festa

Site estático com a memória do fim de semana de aniversário (15 a 18 de outubro de 2026, Lisboa): vídeo, prémios, ranking, equipas e a galeria com todas as fotos.

* Endereço: https://verapvst.github.io/fran-x-vera/memoria/ (a página principal redireciona para lá).
* `site/memoria/` é o site (HTML, imagens e vídeo). Não tem base de dados nem servidor: os números estão em `data.js`.
* `site/index.html` só redireciona para `memoria/`.
* Publicação: cada push para `main` publica `site/` no GitHub Pages (`.github/workflows/pages.yml`).
* `arquivo/memoria-build/` tem os scripts que geraram as fotos, os prémios e o vídeo (ver `LEIA-ME.txt`).
* O código do jogo original (com Supabase) ficou guardado no ramo `arquivo-festa-v1`. O Supabase já foi apagado, por isso esse código já não funciona sem ser recriado.

## Tirar uma foto ou uma pessoa

1. Apaga `site/memoria/fotos/pNNN.jpg` e `site/memoria/thumbs/pNNN.webp` da foto em causa.
2. Remove o `pNNN` correspondente em `site/memoria/data.js` (lista `posts`) e refaz `site/memoria/fotos-todas.zip`.
3. Faz push. (A foto continua no histórico do Git, a não ser que o histórico seja reescrito.)

## Música do vídeo

"Shenzhen Nightlife", de FreePD (domínio público, CC0).
