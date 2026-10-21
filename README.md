# football-manager-br

Jogo de gerenciamento de futebol no estilo Brasfoot, feito em Flutter: Série A 2026, com elencos e técnicos atualizados em 20/10/2026.

## O que já está no jogo

| Fase | Conteúdo |
|---|---|
| 1–3 | 20 clubes reais, elencos, calendário turno/returno, tabela e escudos desenhados em código |
| 4 | Partida ao vivo com narração, táticas, IA reativa, 5 substituições e palestra no intervalo |
| 5 | XP e evolução, energia, moral e força condicionada |
| 6 | Vibração, moral da torcida, coletiva de imprensa |
| 7 | Save/load automático e tela inicial com "Continuar Carreira" |
| 8 | **Finanças**: caixa, folha mensal, bilheteria, premiações, patrocínio renegociável, cotas de TV, investimentos (CT, estádio, DM), gráfico e extrato |
| 9 | **Mercado**: contratar (proposta, salário, luvas e anos de contrato), multa rescisória, empréstimo, agentes livres, lista de transferências, propostas da IA, renovação e rescisão |
| 10A | **Carreira de técnico**: reputação, metas da diretoria, confiança, demissão, convites de outros clubes e histórico |
| Extra | Lesões (reduzidas pelo DM), escalação manual, base revelando jovens, aposentadorias e Palmarès das temporadas |

Ainda não feitos: Modo Presidente (10B), Modo Jogador (10C), Séries B/C/D, estaduais, Copa do Brasil, Libertadores e Sul-Americana.

## Gerar o APK pelo GitHub

1. Cada push na branch `main` (ou `master`) dispara o workflow **Build Football Manager APK**. Ele também pode ser iniciado à mão em *Actions → Run workflow*.
2. Quando terminar, baixe o artefato `football-manager-br-release` na página da execução. O arquivo `app-release.apk` vem dentro do zip.

O upload pelo site do GitHub **ignora arquivos e pastas que começam com ponto** (`.github`, `.gitignore`...). Por isso o workflow em `.github/workflows/build-apk.yml` só chama o script `ci/build.sh`:

| Arquivo | Para que serve | Dá para atualizar pelo site? |
|---|---|---|
| `ci/build.sh` | passos do build: dependências, análise, APK e testes | sim |
| `ci/flutter_version` | versão do Flutter usada no build (hoje 3.47.7) | sim |
| `.github/workflows/build-apk.yml` | só aciona o script | não: só por git ou pelo editor do site |

O APK é publicado antes dos testes, então um teste falhando não impede o download do APK.

## Rodar localmente

```bash
flutter pub get
flutter test
flutter run
```
