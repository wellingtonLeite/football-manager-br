import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/engine.dart';
import '../game/models.dart';
import '../game/data.dart';
import 'shield.dart';
import 'live_match_screen.dart';
import 'audio_service.dart';

const Color kGreen = Color(0xFF1B5E20);

Team _team(GameState g, String id) => g.teams.firstWhere((t) => t.id == id);

Color _overallColor(int o) {
  if (o >= 82) return Colors.green;
  if (o >= 76) return Colors.orange;
  return Colors.red;
}

// --- NOVA TELA DE BOAS-VINDAS ---
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameState>();
    final hasSave = game.started; // Na verdade, checkamos via loadFromDisk no main, mas aqui assumimos estado inicial
    
    // Para saber se tem save real, verificamos se userTeamId não é nulo
    // Mas como o Main carregou o save, se 'started' for true, temos jogo.
    // Se for falso, mostramos opções.
    
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
              Text(
                'FOOTBALL MANAGER\nBRASIL 2026',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'RobotoCondensed', // Fallback padrão
                ),
              ),
              const SizedBox(height: 40),
              
              // Botão Continuar (se houver save)
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
                
              if (hasSave) const SizedBox(height: 16),

              // Botão Nova Carreira
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.5)),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                     context.read<AudioService>().playButton();
                     if (hasSave) {
                        // Confirmação de sobrescrever
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF263238),
                            title: const Text('Sobrescrever Save?', style: TextStyle(color: Colors.white)),
                            content: const Text('Você perderá seu progresso atual.', style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  game.deleteSave().then((_) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (_) => const TeamSelectScreen()),
                                    );
                                  });
                                },
                                child: const Text('Confirmar', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        );
                     } else {
                       Navigator.pushReplacement(
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

class TeamSelectScreen extends StatelessWidget {
  const TeamSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolha seu Clube'),
        backgroundColor: kGreen,
      ),
      body: ListView.separated(
        itemCount: kClubs.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final c = kClubs[i];
          return ListTile(
            leading: ClubShield(shortName: c.shortName, size: 32),
            title: Text(
              c.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${c.state} • ${c.stadium} • Téc: ${c.coach}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            trailing: Text('★' * c.stars,
                style: const TextStyle(color: Colors.amber)),
            onTap: () {
              context.read<AudioService>().playButton();
              context
                  .read<GameState>()
                  .startGame(c.shortName.toLowerCase());
            },
          );
        },
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
    final team = game.userTeam!;
    return Scaffold(
      appBar: AppBar(
        title: Text(team.name),
        backgroundColor: kGreen,
        actions: [
          IconButton(
            icon: Icon(audio.muted ? Icons.volume_off : Icons.volume_up),
            onPressed: audio.toggleMute,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF263238),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ClubShield(shortName: team.shortName, size: 64),
                  const SizedBox(height: 8),
                  Text(
                    '★' * team.stars,
                    style: const TextStyle(color: Colors.amber, fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    game.seasonFinished
                        ? 'Temporada ${game.seasonYear} encerrada!'
                        : 'Temporada ${game.seasonYear} • ${game.userPosition}º • ${team.points} pts',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    '${team.played} jogos • Estádio: ${team.stadium}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Técnico: ${team.coach}',
                    style: TextStyle(
                      color: Colors.amber.shade300,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _moraleIndicator('👥 Torcida', team.fanMorale, team.fanMoodStatus == FanMood.apoio ? Colors.green : team.fanMoodStatus == FanMood.protesto ? Colors.red : Colors.orange),
                      _moraleIndicator('📰 Imprensa', team.pressMorale, team.pressMoodStatus == PressMood.positivo ? Colors.green : team.pressMoodStatus == PressMood.critico ? Colors.red : Colors.orange),
                    ],
                  ),
                  if (!game.seasonFinished) ...[
                    const SizedBox(height: 8),
                    Builder(builder: (context) {
                      final m = game.userMatchCurrent;
                      if (m == null) return const SizedBox.shrink();
                      final opp = game.teams.firstWhere(
                          (t) => t.id == (m.homeId == team.id ? m.awayId : m.homeId));
                      final casa = m.homeId == team.id;
                      return Text(
                        'Próximo: ${opp.name} (${casa ? 'casa' : 'fora'}) • Rodada ${m.round}',
                        style: const TextStyle(
                            color: Colors.greenAccent, fontSize: 13),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _menuButton(
            context,
            game.seasonFinished
                ? '🏆 Fim de Temporada'
                : '⚽ Rodada ${game.currentRound}',
            Colors.green,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RoundScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _menuButton(
            context,
            '👥 Elenco',
            Colors.blue,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SquadScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _menuButton(
            context,
            '📊 Classificação',
            Colors.orange,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TableScreen()),
            ),
          ),
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
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1),
          ),
          child: Text(
            '$value%',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _menuButton(
      BuildContext context, String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          context.read<AudioService>().playButton();
          onTap();
        },
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
        appBar: AppBar(
          title: Text('Temporada ${game.seasonYear}'),
          backgroundColor: kGreen,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 64)),
              ClubShield(shortName: champ.shortName, size: 80),
              const SizedBox(height: 12),
              Text(
                'CAMPEÃO ${game.seasonYear}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                champ.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${champ.points} pts • ${champ.wins} vitórias',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      context.read<AudioService>().playButton();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TableScreen()),
                      );
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      context.read<AudioService>().playButton();
                      game.startNewSeason();
                    },
                    child: Text(
                      '🔄 Iniciar Temporada ${game.seasonYear + 1}',
                    ),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Rodada ${game.currentRound}'),
        backgroundColor: kGreen,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [for (final m in matches) _matchTile(game, m)],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: played ? Colors.orange : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: played
                      ? () {
                          context.read<AudioService>().playButton();
                          game.advanceRound();
                        }
                      : () {
                          context.read<AudioService>().playButton();
                          game.simulateOtherMatches();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LiveMatchScreen(),
                            ),
                          ).then((_) {
                            if (game.currentRoundPlayed) {
                              _showPressConference(context, game);
                            }
                          });
                        },
                  child: Text(
                    played
                        ? 'Ir para Rodada ${game.currentRound + 1} →'
                        : '⚽ Simular Rodada ${game.currentRound}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFF1B5E20) : const Color(0xFF263238),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ClubShield(shortName: home.shortName, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isUser && !m.isPlayed ? 'SEU JOGO →' : home.name,
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                m.isPlayed ? '${m.homeGoals} x ${m.awayGoals}' : 'vs',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Text(
                away.name,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
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

  const PressConferenceDialog({
    super.key,
    required this.questions,
    required this.game,
  });

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
        backgroundColor: const Color(0xFF263238),
        title: const Text('📰 Coletiva Encerrada',
            style: TextStyle(color: Colors.white)),
        content: const Text('Obrigado pelas respostas!',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      );
    }

    final q = widget.questions[currentQ];
    return AlertDialog(
      backgroundColor: const Color(0xFF263238),
      title: Row(
        children: [
          const Text('📰', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Coletiva (${currentQ + 1}/${widget.questions.length})',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.question,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          if (!answered)
            ...List.generate(q.answers.length, (idx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    side: BorderSide(color: Colors.white24),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      answered = true;
                      feedback = idx == q.correctIndex
                          ? q.correctFeedback
                          : q.wrongFeedback;
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
                color: feedback!.contains('+') || feedback!.contains('aprov') || feedback!.contains('respeit') || feedback!.contains('confia') || feedback!.contains('empat')
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                feedback!,
                style: TextStyle(
                  color: feedback!.contains('+') || feedback!.contains('aprov') || feedback!.contains('respeit') || feedback!.contains('confia') || feedback!.contains('empat')
                      ? Colors.greenAccent
                      : Colors.redAccent,
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
    final team = context.watch<GameState>().userTeam!;
    const order = ['GOL', 'ZAG', 'LAT', 'VOL', 'MEI', 'ATA'];
    final widgets = <Widget>[];
    for (final pos in order) {
      final list = team.squad.where((p) => p.position == pos).toList()
        ..sort((a, b) => b.overall.compareTo(a.overall));
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          pos,
          style: const TextStyle(
            color: Colors.greenAccent,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
      ));
      for (final p in list) {
        final tit = team.startingIds.contains(p.id);
        widgets.add(ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: _overallColor(p.overall),
            child: Text(
              '${p.overall}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Row(
            children: [
              if (tit)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'TIT',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Expanded(
                child: Text(p.name,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
          subtitle: Text(
            '${p.position} • ${p.age} anos\n⚡${p.energy} • 😊${p.morale} • ⭐${p.xp}/${Player.xpToNext}',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ));
      }
    }
    return Scaffold(
      appBar:
          AppBar(title: Text('Elenco - ${team.name}'), backgroundColor: kGreen),
      body: ListView(children: widgets),
    );
  }
}

class TableScreen extends StatelessWidget {
  const TableScreen({super.key});

  Color? _zoneColor(int idx) {
    if (idx < 4) return Colors.green.withOpacity(0.25);
    if (idx < 6) return Colors.teal.withOpacity(0.20);
    if (idx >= 16) return Colors.red.withOpacity(0.25);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final table = game.standings;
    return Scaffold(
      appBar: AppBar(
        title: Text('Série A ${game.seasonYear}'),
        backgroundColor: kGreen,
      ),
      body: ListView.builder(
        itemCount: table.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                      flex: 1,
                      child:
                          Text('#', style: TextStyle(color: Colors.white54))),
                  Expanded(
                      flex: 5,
                      child: Text('Clube',
                          style: TextStyle(color: Colors.white54))),
                  Expanded(
                      flex: 1,
                      child: Text('P',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54))),
                  Expanded(
                      flex: 1,
                      child: Text('J',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54))),
                  Expanded(
                      flex: 1,
                      child: Text('SG',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54))),
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
                  Text('🟩 Verde: Libertadores (G4)',
                      style: TextStyle(color: Colors.white70)),
                  Text('🟦 Azul: Sul-Americana (5º-6º)',
                      style: TextStyle(color: Colors.white70)),
                  Text('🟥 Vermelho: Rebaixamento (Z4)',
                      style: TextStyle(color: Colors.white70)),
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
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Row(
                children: [
                  ClubShield(shortName: t.shortName, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isUser ? '${t.name} (VOCÊ)' : t.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            isUser ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                      width: 32,
                      child: Text('${t.points}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold))),
                  SizedBox(
                      width: 24,
                      child: Text('${t.played}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70))),
                  SizedBox(
                      width: 32,
                      child: Text(
                          '${t.goalDifference > 0 ? '+' : ''}${t.goalDifference}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}