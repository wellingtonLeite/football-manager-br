import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/engine.dart';
import '../game/models.dart';
import '../game/data.dart';
import 'shield.dart';

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
            onTap: () => context
                .read<GameState>()
                .startGame(c.shortName.toLowerCase()),
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
    final team = game.userTeam!;
    return Scaffold(
      appBar: AppBar(title: Text(team.name), backgroundColor: kGreen),
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
                        ? 'Temporada encerrada!'
                        : 'Posição: ${game.userPosition}º • ${team.points} pts',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _menuButton(
            context,
            game.seasonFinished
                ? '🏁 Ver Classificação Final'
                : '⚽ Rodada ${game.currentRound}',
            Colors.green,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => game.seasonFinished
                    ? const TableScreen()
                    : const RoundScreen(),
              ),
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
        onPressed: onTap,
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
    final matches = game.currentRoundMatches;
    final played = game.currentRoundPlayed;
    return Scaffold(
      appBar:
          AppBar(title: Text('Rodada ${game.currentRound}'), backgroundColor: kGreen),
      body: Column(
        children: [
          Expanded(
            child: ListView(children: [for (final m in matches) _matchTile(game, m)]),
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
                  onPressed: played ? game.advanceRound : game.simulateRound,
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
                home.name,
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
          title: Text(p.name, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            '${p.position} • ${p.age} anos',
            style: const TextStyle(color: Colors.white60),
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
      appBar:
          AppBar(title: const Text('Série A 2026'), backgroundColor: kGreen),
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
                      child: Text('#',
                          style: TextStyle(color: Colors.white54))),
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
                backgroundColor:
                    isUser ? Colors.amber : Colors.grey.shade800,
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
                          style:
                              const TextStyle(color: Colors.white70))),
                  SizedBox(
                      width: 32,
                      child: Text(
                          '${t.goalDifference > 0 ? '+' : ''}${t.goalDifference}',
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: Colors.white70))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
