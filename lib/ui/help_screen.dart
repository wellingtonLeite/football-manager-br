import 'package:flutter/material.dart';
import 'widgets.dart';

/// Tutorial: como o jogo funciona, tela por tela.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const List<(String, String, String)> _topics = [
    ('🎮', 'Modos de carreira',
        'Técnico: você escala, escolhe tática e formação e joga ao vivo.\n'
        'Presidente: cuida do caixa, contrata técnicos, responde a crises e disputa a eleição a cada 3 anos.\n'
        'Jogador: cria um atleta de 16 a 20 anos e leva a carreira até a aposentadoria.'),
    ('📅', 'Calendário',
        'Cada temporada tem cerca de 70 datas: Supercopa e Recopa, estaduais, as 38 rodadas das ligas '
        'e, no meio da semana, Copa do Brasil, Libertadores, Sul-Americana e Liga dos Campeões. '
        'A Copa Intercontinental fecha o ano.'),
    ('⚽', 'Antes do jogo',
        'Em "Preparar o jogo" escolha a formação (4-4-2, 4-3-3...), a tática e os 11 titulares. '
        'Jogadores cansados (⚡ baixo), lesionados (🚑) ou suspensos (🟥) devem ficar de fora.'),
    ('🟨', 'Cartões',
        'Três amarelos ou um vermelho suspendem o jogador da próxima partida. '
        'Com um a menos em campo, o time perde força.'),
    ('🏆', 'Divisões e copas',
        'Séries A, B e C: 4 sobem e 4 descem. Série D: grupos regionais e mata-mata, e os semifinalistas sobem. '
        'Top 6 da Série A vão à Libertadores e os 7 seguintes à Sul-Americana.'),
    ('🔄', 'Mercado',
        'Compras e empréstimos só nas janelas (pré-temporada e meio do ano); agentes livres a qualquer hora. '
        'Dá para comprar de clubes do exterior (Inglaterra, Espanha, Itália, Alemanha, França, Portugal, Arábia e Argentina). '
        'Toda compra paga 5% de comissão ao empresário. Ao vender, uma cláusula de revenda garante parte da próxima venda. '
        'Use a busca (nome, posição, idade, preço) e a ordenação para achar reforços. Empréstimo: negocie a taxa e, '
        'se quiser, a opção de compra. Em Meu Elenco, dá para emprestar seus jogadores a clubes interessados. '
        'Na primeira temporada, Libertadores e Sul-Americana têm os classificados reais de 2026.'),
    ('🏟️', 'Clube',
        'Treino: foco e intensidade mudam evolução, energia e lesões. Comissão técnica: auxiliar, preparador e olheiro. '
        'Base: garotos de 15–19 anos; promova os melhores. Olheiros: revelam o potencial (teto) dos jogadores; toque no jogador encontrado para negociar. '
        'Ingressos e sócio-torcedor: preço alto = mais dinheiro por pessoa, menos público.'),
    ('💰', 'Finanças',
        'Receitas: TV, patrocínio, bilheteria, sócios, premiações e vendas. Despesas: salários, comissão técnica, '
        'estrutura e compras. Caixa negativo gera juros e derruba a moral. Premiações entram durante a temporada: '
        'bicho por vitória (liga e copas), cota por jogo na fase de grupos da Libertadores/Sul-Americana, 40% da '
        'premiação por posição no fim do 1º turno e o restante no fim do campeonato.'),
    ('📣', 'Marketing',
        'O departamento de marketing busca patrocinadores para 6 espaços (master, material esportivo, naming rights, '
        'costas, manga e calção). As luvas entram na hora e as parcelas todo mês. No Modo Presidente, você aceita ou '
        'recusa cada proposta; no Modo Técnico, a diretoria decide. Um diretor de marketing (Comissão) traz propostas melhores.'),
    ('👔', 'Técnico (Modo Presidente)',
        'Ao demitir o técnico, o auxiliar assume como interino e você escolhe o substituto na Presidência, '
        'vendo a nota e o salário de cada técnico livre.'),
    ('🇧🇷', 'Seleção Brasileira',
        'Técnicos com reputação alta recebem convite da CBF. Na Seleção você convoca até 26 brasileiros de qualquer liga, '
        'joga nas Datas FIFA e disputa a Copa América e a Copa do Mundo.'),
    ('💾', 'Saves e backup',
        'São 3 espaços de save. No ⋮ de cada um dá para exportar o backup (Drive, WhatsApp) e importar de volta. '
        'Exporte antes de reinstalar o app.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Como jogar'), backgroundColor: kGreen),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final (emoji, title, text) in _topics)
            Card(
              color: kCard,
              child: ExpansionTile(
                leading: Text(emoji, style: const TextStyle(fontSize: 24)),
                title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                iconColor: Colors.white70,
                collapsedIconColor: Colors.white54,
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [Text(text, style: const TextStyle(color: Colors.white70, height: 1.4))],
              ),
            ),
        ],
      ),
    );
  }
}
