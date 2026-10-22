# football-manager-br

Jogo de gerenciamento de futebol no estilo Brasfoot, feito em Flutter: futebol brasileiro e mundial na temporada 2026, com elencos e técnicos atualizados em 20/10/2026.

## O que já está no jogo

| Área | Conteúdo |
|---|---|
| Mundo | 80 clubes brasileiros (Séries A–D 2026) + 152 clubes de 8 ligas do exterior (Inglaterra, Espanha, Itália, Alemanha, França, Portugal, Arábia Saudita e Argentina) + clubes sul-americanos das copas. Elencos reais (Wikipédia, out/2026); craques mundiais com notas próprias |
| Competições | Supercopa do Brasil, Recopa, estaduais e copas regionais, Séries A–C (4 sobem/4 descem), Série D em grupos regionais + mata-mata, Copa do Brasil, Libertadores e Sul-Americana (grupos reais de 2026), Liga dos Campeões, Copa Intercontinental e as 8 ligas estrangeiras |
| Partida | Pré-jogo com formação (4-4-2, 4-3-3, 4-5-1, 3-5-2, 3-4-3, 5-3-2), tática e titulares; jogo ao vivo com campinho 2D, narração com velocidade ajustável, cartões amarelos/vermelhos e suspensões, pênaltis (cobrador e goleiro pesam), gols de cabeça/falta/de fora da área, lesões, substituições, palestra, pênaltis e estatísticas (posse, finalizações) |
| Estatísticas | Artilharia por competição, assistências, notas, seleção da rodada, prêmios (Bola de Ouro, Artilheiro, Revelação, Técnico do ano) e recordes do clube |
| Clube | Marketing com 6 espaços de patrocínio (o presidente aceita ou recusa), finanças com custos proporcionais ao porte do clube, investimentos, treino (foco e intensidade), comissão técnica, categorias de base, olheiros (potencial), preço do ingresso e sócio-torcedor |
| Mercado | Janelas de transferência, compras no Brasil e no exterior, comissão de empresário, empréstimo com opção de compra, cláusula de revenda, agentes livres, negócios entre clubes da IA |
| Modos | Técnico (com convite para a Seleção Brasileira, Copa América e Copa do Mundo), Presidente, Jogador e Multiplayer local (2 a 4 técnicos) |
| Extras | Central de avisos na tela inicial, save versionado com backup automático e migração, 3 espaços de save com backup (exportar/importar), editor de clubes e jogadores, 20 conquistas, tutorial, dificuldade (fácil/normal/difícil), sons sintetizados e vibração |

Overall e idades dos jogadores são estimativas do jogo. Técnicos da Série D e dos clubes sul-americanos só de copa são fictícios.

## Assinatura do APK (atualizar sem desinstalar)

O build usa a chave guardada nos segredos do repositório (`ANDROID_KEYSTORE_BASE64` e `ANDROID_KEYSTORE_PASSWORD`, em *Settings › Secrets and variables › Actions*). Sem esses segredos, o APK sai com uma chave provisória e cada versão nova exige desinstalar a anterior.

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
