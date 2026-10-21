import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/engine.dart';
import '../game/models.dart';
import '../game/data.dart';
import '../game/economy.dart';
import 'shield.dart';
import 'audio_service.dart';
import 'live_match_screen.dart';
import 'finances_screen.dart';
import 'marketplace_screen.dart';
import 'career_screen.dart';
import 'widgets.dart';

Team _team(GameState g, String id) => g.teamById(id);

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final hasSave = game.started;
    final saveInfo = !hasSave
        ? ''
        : game.userTeam != null
            ? '${game.career.name} • ${game.userTeam!.name} • ${game.seasonYear}'
            : '${game.career.name} • sem clube • ${game.seasonYear}';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_soccer, size: 80, color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                'FOOTBALL MANAGER\nBRASIL 2026',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),

              if (hasSave)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                       context.read<AudioService>().playButton();
                       Navigator.pushReplacement(
                         context,
                         MaterialPageRoute(builder: (_) => const HomeScreen())
                       );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('CONTINUAR CARREIRA'),
                  ),
                ),
              if (hasSave)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(saveInfo, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ),

              if (hasSave) const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                     context.read<AudioService>().playButton();
                     if (hasSave) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: kCard,
                            title: const Text('Sobrescrever Save?', style: TextStyle(color: Colors.white)),
                            content: const Text('Você perderá seu progresso atual.', style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await game.deleteSave();
                                  if (!context.mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const TeamSelectScreen()),
                                  );
                                },
                                child: const Text('Confirmar', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        );
                     } else {
                       Navigator.push(
                         context,
                         MaterialPageRoute(builder: (_) => const TeamSelectScreen()),
                       );
                     }
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('NOVA CARREIRA'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TeamSelectScreen extends StatefulWidget {
  const TeamSelectScreen({super.key});

  @override
  State<TeamSelectScreen> createState() => _TeamSelectScreenState();
}

class _TeamSelectScreenState extends State<TeamSelectScreen> {
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escolha seu Clube'), backgroundColor: kGreen),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome do técnico',
                hintText: 'Ex.: Wellington Leite',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: kClubs.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = kClubs[i];
                return ListTile(
                  leading: ClubShield(shortName: c.shortName, size: 32),
                  title: Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text('${c.state} • ${c.stadium} • Téc. atual: ${c.coach}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  trailing: Text('★' * c.stars, style: const TextStyle(color: Colors.amber)),
                  onTap: () {
                    context.read<AudioService>().playButton();
                    context.read<GameState>().startGame(c.shortName.toLowerCase(), coachName: _nameCtrl.text);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (_) => false,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final audio = context.watch<AudioService>();
    final team = game.userTeam;
    final muteButton = IconButton(
      icon: Icon(audio.muted ? Icons.volume_off : Icons.volume_up),
      onPressed: audio.toggleMute,
    );
    if (team == null) return _unemployed(context, game, muteButton);

    return Scaffold(
      appBar: AppBar(
        title: Text(team.name),
        backgroundColor: kGreen,
        actions: [muteButton],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: kCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ClubShield(shortName: team.shortName, size: 64),
                  const SizedBox(height: 8),
                  Text('★' * team.stars, style: const TextStyle(color: Colors.amber, fontSize: 20)),
                  const SizedBox(height: 8),
                  Text(
                    game.seasonFinished
                        ? 'Temporada ${game.seasonYear} encerrada!'
                        : 'Temporada ${game.seasonYear} • ${game.userPosition}º • ${team.points} pts',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text('${team.played} jogos • Estádio: ${team.stadium}', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text('Técnico: ${team.coach}', style: TextStyle(color: Colors.amber.shade300, fontSize: 13)),
                  Text('Meta: ${game.career.goal.label}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    'Caixa: ${formatMoney(team.balance)}',
                    style: TextStyle(color: team.balance >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _moraleIndicator('👥 Torcida', team.fanMorale, team.fanMoodStatus == FanMood.apoio ? Colors.green : team.fanMoodStatus == FanMood.protesto ? Colors.red : Colors.orange),
                      _moraleIndicator('📰 Imprensa', team.pressMorale, team.pressMoodStatus == PressMood.positivo ? Colors.green : team.pressMoodStatus == PressMood.critico ? Colors.red : Colors.orange),
                      _moraleIndicator('👔 Diretoria', game.career.boardConfidence, game.career.boardConfidence >= 60 ? Colors.green : game.career.boardConfidence <= 30 ? Colors.red : Colors.orange),
                    ],
                  ),
                  if (!game.seasonFinished) ...[
                    const SizedBox(height: 8),
                    Builder(builder: (context) {
                      final m = game.userMatchCurrent;
                      if (m == null) return const SizedBox.shrink();
                      final opp = _team(game, m.homeId == team.id ? m.awayId : m.homeId);
                      final casa = m.homeId == team.id;
                      return Text(
                        'Próximo: ${opp.name} (${casa ? 'casa' : 'fora'}) • Rodada ${m.round}',
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _menuButton(context, game.seasonFinished ? '🏆 Fim de Temporada' : '⚽ Rodada ${game.currentRound}', Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoundScreen()))),
          const SizedBox(height: 12),
          _menuButton(context, '👥 Elenco e Escalação', Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SquadScreen()))),
          const SizedBox(height: 12),
          _menuButton(context, '📊 Classificação', Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TableScreen()))),
          const SizedBox(height: 12),
          _menuButton(context, '💰 Finanças', Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancesScreen()))),
          const SizedBox(height: 12),
          _menuButton(
            context,
            game.incomingOffers.isEmpty ? '🔄 Mercado' : '🔄 Mercado (${game.incomingOffers.length} proposta${game.incomingOffers.length > 1 ? 's' : ''})',
            Colors.deepPurple,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketplaceScreen())),
          ),
          const SizedBox(height: 12),
          _menuButton(
            context,
            game.career.offers.isEmpty ? '👔 Carreira' : '👔 Carreira (${game.career.offers.length} convite${game.career.offers.length > 1 ? 's' : ''})',
            Colors.brown,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CareerScreen())),
          ),
          const SizedBox(height: 16),
          NewsCard(news: game.news),
        ],
      ),
    );
  }

  Widget _unemployed(BuildContext context, GameState game, Widget muteButton) {
    final c = game.career;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sem clube'),
        backgroundColor: Colors.grey.shade800,
        actions: [muteButton],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: kCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('👔', style: TextStyle(fontSize: 48)),
                  Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    game.seasonFinished
                        ? 'Temporada ${game.seasonYear} encerrada'
                        : 'Temporada ${game.seasonYear} • Rodada ${game.currentRound}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  meterBar('Reputação', c.reputation),
                  const SizedBox(height: 4),
                  const Text(
                    'Aguarde convites enquanto o campeonato segue. Clubes 5★ exigem reputação 75 e clubes 4★, 55.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          sectionTitle('CONVITES'),
          const JobOffersList(),
          const SizedBox(height: 16),
          _menuButton(context, game.seasonFinished ? '🏆 Fim de Temporada' : '⏩ Acompanhar Rodada ${game.currentRound}', Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoundScreen()))),
          const SizedBox(height: 12),
          _menuButton(context, '📊 Classificação', Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TableScreen()))),
          const SizedBox(height: 12),
          _menuButton(context, '👔 Carreira', Colors.brown, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CareerScreen()))),
          const SizedBox(height: 16),
          NewsCard(news: game.news),
        ],
      ),
    );
  }

  Widget _moraleIndicator(String label, int value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: color, width: 1)),
          child: Text('$value%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _menuButton(BuildContext context, String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: () {
          context.read<AudioService>().playButton();
          onTap();
        },
        child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class NewsCard extends StatelessWidget {
  final List<NewsItem> news;
  const NewsCard({super.key, required this.news});

  @override
  Widget build(BuildContext context) {
    if (news.isEmpty) return const SizedBox.shrink();
    return Card(
      color: kCard,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🗞️ Últimas notícias', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final n in news.take(6))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('R${n.round} • ${n.text}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }
}

class RoundScreen extends StatelessWidget {
  const RoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();

    if (game.seasonFinished) {
      final champ = game.champion;
      return Scaffold(
        appBar: AppBar(title: Text('Temporada ${game.seasonYear}'), backgroundColor: kGreen),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 64)),
              ClubShield(shortName: champ.shortName, size: 80),
              const SizedBox(height: 12),
              Text('CAMPEÃO ${game.seasonYear}', style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(champ.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              Text('${champ.points} pts • ${champ.wins} vitórias', style: const TextStyle(color: Colors.white70)),
              if (game.userTeam != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${game.userTeam!.name}: ${game.userPosition}º lugar • Meta: ${game.career.goal.label}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const Text(
                  'Antes de virar a temporada, renove contratos em Mercado › Meu Elenco.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    onPressed: () {
                      context.read<AudioService>().playButton();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TableScreen()));
                    },
                    child: const Text('Ver Classificação Final'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: () {
                      context.read<AudioService>().playButton();
                      game.startNewSeason();
                    },
                    child: Text('🔄 Iniciar Temporada ${game.seasonYear + 1}'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final matches = game.currentRoundMatches;
    final played = game.currentRoundPlayed;
    final lastRound = game.currentRound == game.totalRounds;
    return Scaffold(
      appBar: AppBar(title: Text('Rodada ${game.currentRound}'), backgroundColor: kGreen),
      body: Column(
        children: [
          Expanded(child: ListView(children: [for (final m in matches) _matchTile(game, m)])),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: played ? Colors.orange : Colors.green, foregroundColor: Colors.white),
                  onPressed: played
                      ? () {
                          context.read<AudioService>().playButton();
                          game.advanceRound();
                        }
                      : () {
                          context.read<AudioService>().playButton();
                          game.simulateOtherMatches();
                          if (game.userMatchCurrent == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LiveMatchScreen()),
                          ).then((_) {
                            if (game.currentRoundPlayed && context.mounted) {
                              _showPressConference(context, game);
                            }
                          });
                        },
                  child: Text(
                    played
                        ? (lastRound ? 'Encerrar temporada →' : 'Ir para Rodada ${game.currentRound + 1} →')
                        : '⚽ Simular Rodada ${game.currentRound}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPressConference(BuildContext context, GameState game) {
    final questions = game.generatePressConference();
    if (questions.isEmpty) return;
    showDialog(
      context: context,
      builder: (dlg) => PressConferenceDialog(questions: questions, game: game),
    );
  }

  Widget _matchTile(GameState game, Match m) {
    final home = _team(game, m.homeId);
    final away = _team(game, m.awayId);
    final isUser = m.homeId == game.userTeamId || m.awayId == game.userTeamId;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: isUser ? kGreen : kCard, borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ClubShield(shortName: home.shortName, size: 20),
            const SizedBox(width: 6),
            Expanded(child: Text(isUser && !m.isPlayed ? 'SEU JOGO →' : home.name, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 13))),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(6)),
              child: Text(m.isPlayed ? '${m.homeGoals} x ${m.awayGoals}' : 'vs', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: Text(away.name, style: const TextStyle(color: Colors.white, fontSize: 13))),
            const SizedBox(width: 6),
            ClubShield(shortName: away.shortName, size: 20),
          ],
        ),
      ),
    );
  }
}

class PressConferenceDialog extends StatefulWidget {
  final List<PressConference> questions;
  final GameState game;

  const PressConferenceDialog({super.key, required this.questions, required this.game});

  @override
  State<PressConferenceDialog> createState() => _PressConferenceDialogState();
}

class _PressConferenceDialogState extends State<PressConferenceDialog> {
  int currentQ = 0;
  String? feedback;
  bool answered = false;

  @override
  Widget build(BuildContext context) {
    if (currentQ >= widget.questions.length) {
      return AlertDialog(
        backgroundColor: kCard,
        title: const Text('📰 Coletiva Encerrada', style: TextStyle(color: Colors.white)),
        content: const Text('Obrigado pelas respostas!', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      );
    }

    final q = widget.questions[currentQ];
    final positive = feedback != null && feedback!.contains('(+');
    return AlertDialog(
      backgroundColor: kCard,
      title: Row(
        children: [
          const Text('📰', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(child: Text('Coletiva (${currentQ + 1}/${widget.questions.length})', style: const TextStyle(color: Colors.white))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q.question, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          if (!answered)
            ...List.generate(q.answers.length, (idx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, side: const BorderSide(color: Colors.white24), foregroundColor: Colors.white),
                  onPressed: () {
                    setState(() {
                      answered = true;
                      feedback = idx == q.correctIndex ? q.correctFeedback : q.wrongFeedback;
                      widget.game.applyPressAnswer(currentQ, idx);
                    });
                  },
                  child: Text(q.answers[idx]),
                ),
              );
            })
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: positive ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                feedback!,
                style: TextStyle(
                  color: positive ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      actions: [
        if (answered)
          TextButton(
            onPressed: () {
              setState(() {
                currentQ++;
                answered = false;
                feedback = null;
              });
            },
            child: const Text('Próxima Pergunta'),
          ),
      ],
    );
  }
}

class SquadScreen extends StatelessWidget {
  const SquadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final team = game.userTeam;
    if (team == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Elenco'), backgroundColor: kGreen),
        body: const Center(child: Text('Você está sem clube.', style: TextStyle(color: Colors.white70))),
      );
    }
    const order = ['GOL', 'ZAG', 'LAT', 'VOL', 'MEI', 'ATA'];
    final widgets = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(
          'Titulares: ${team.startingIds.length}/11 • Toque no jogador para colocar ou tirar do time. '
          'Com 11 titulares, o reserva entra no lugar do titular mais fraco da posição.',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ),
    ];
    for (final pos in order) {
      final list = team.squad.where((p) => p.position == pos).toList()
        ..sort((a, b) => b.overall.compareTo(a.overall));
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(pos, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 3)),
      ));
      for (final p in list) {
        final tit = team.startingIds.contains(p.id);
        widgets.add(ListTile(
          dense: true,
          onTap: () {
            final err = game.toggleStarter(p.id);
            if (err != null) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(err)));
            }
          },
          leading: overallAvatar(p),
          title: Row(
            children: [
              if (tit)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                  child: const Text('TIT', style: TextStyle(fontSize: 9, color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              if (p.injured)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Text('🚑', style: TextStyle(fontSize: 12)),
                ),
              if (p.onLoan)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Text('🔁', style: TextStyle(fontSize: 12)),
                ),
              Expanded(child: Text(p.name, style: const TextStyle(color: Colors.white))),
            ],
          ),
          subtitle: Text(
            '${p.position} • ${p.age} anos • ${formatMoney(p.wage)}/mês • até ${game.seasonYear + p.contractYears - 1}\n'
            '⚡${p.energy} • 😊${p.morale} • ⭐${p.xp}/${Player.xpToNext}'
            '${p.injured ? ' • lesionado (${game.roundsOut(p)} rod.)' : ''}',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ));
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Elenco - ${team.name}'),
        backgroundColor: kGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Escalação automática',
            onPressed: game.resetUserLineup,
          ),
        ],
      ),
      body: ListView(children: widgets),
    );
  }
}

class TableScreen extends StatelessWidget {
  const TableScreen({super.key});

  Color? _zoneColor(int idx) {
    if (idx < 4) return Colors.green.withValues(alpha: 0.25);
    if (idx < 6) return Colors.teal.withValues(alpha: 0.20);
    if (idx >= 16) return Colors.red.withValues(alpha: 0.25);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final table = game.standings;
    return Scaffold(
      appBar: AppBar(title: Text('Série A ${game.seasonYear}'), backgroundColor: kGreen),
      body: ListView.builder(
        itemCount: table.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(flex: 1, child: Text('#', style: TextStyle(color: Colors.white54))),
                  Expanded(flex: 5, child: Text('Clube', style: TextStyle(color: Colors.white54))),
                  Expanded(flex: 1, child: Text('P', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))),
                  Expanded(flex: 1, child: Text('J', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))),
                  Expanded(flex: 1, child: Text('SG', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))),
                ],
              ),
            );
          }
          if (index == table.length + 1) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🟩 Verde: Libertadores (G4)', style: TextStyle(color: Colors.white70)),
                  Text('🟦 Azul: Sul-Americana (5º-6º)', style: TextStyle(color: Colors.white70)),
                  Text('🟥 Vermelho: Rebaixamento (Z4)', style: TextStyle(color: Colors.white70)),
                ],
              ),
            );
          }
          final i = index - 1;
          final t = table[i];
          final isUser = t.id == game.userTeamId;
          return Container(
            color: _zoneColor(i),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: isUser ? Colors.amber : Colors.grey.shade800,
                child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              title: Row(
                children: [
                  ClubShield(shortName: t.shortName, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isUser ? '${t.name} (VOCÊ)' : t.name,
                      style: TextStyle(color: Colors.white, fontWeight: isUser ? FontWeight.bold : FontWeight.normal),
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 32, child: Text('${t.points}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  SizedBox(width: 24, child: Text('${t.played}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
                  SizedBox(width: 32, child: Text('${t.goalDifference > 0 ? '+' : ''}${t.goalDifference}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
