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