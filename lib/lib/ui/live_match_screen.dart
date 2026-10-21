import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/engine.dart';
import '../game/models.dart';
import 'shield.dart';

const Color _kGreen = Color(0xFF1B5E20);

const Map<Tactic, String> kTacticLabels = {
  Tactic.retranca: '🛡️ Retranca',
  Tactic.neutro: '⚖️ Neutro',
  Tactic.ofensivo: '⚔️ Ofensivo',
  Tactic.tudoOuNada: '🚨 Tudo ou Nada',
};

const Map<Tactic, String> kTacticDesc = {
  Tactic.retranca: 'Defende mais, ataca menos',
  Tactic.neutro: 'Postura equilibrada',
  Tactic.ofensivo: 'Ataca mais, cede espaços',
  Tactic.tudoOuNada: 'Risco total: muitos gols a favor e contra',
};

class LiveMatchScreen extends StatefulWidget {
  const LiveMatchScreen({super.key});

  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen> {
  late final GameState game;
  late final Match match;
  late final Team home;
  late final Team away;

  Timer? _timer;
  int minute = 0;
  int hg = 0;
  int ag = 0;
  int nextChunkStart = 0;
  bool finished = false;
  bool applied = false;
  Tactic tactic = Tactic.neutro;
  final List<MatchEvent> feed = [];
  final List<MatchEvent> pending = [];

  @override
  void initState() {
    super.initState();
    game = context.read<GameState>();
    match = game.userMatchCurrent!;
    home = game.teams.firstWhere((t) => t.id == match.homeId);
    away = game.teams.firstWhere((t) => t.id == match.awayId);
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (finished) return;
    setState(() {
      minute++;
      if (minute >= nextChunkStart && nextChunkStart < 90) {
        final end = nextChunkStart + 15 > 90 ? 90 : nextChunkStart + 15;
        pending.addAll(
          game.generateChunk(match, nextChunkStart, end, tactic, hg, ag),
        );
        pending.sort((a, b) => a.minute.compareTo(b.minute));
        nextChunkStart = end;
      }
      while (pending.isNotEmpty && pending.first.minute <= minute) {
        final e = pending.removeAt(0);
        feed.insert(0, e);
        if (e.type == 'GOAL') {
          if (e.teamId == home.id) {
            hg++;
          } else {
            ag++;
          }
        }
      }
      if (minute >= 90) {
        finished = true;
        _timer?.cancel();
        if (!applied) {
          applied = true;
          game.applyUserMatchResult(hg, ag);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rodada ${match.round} — AO VIVO'),
        backgroundColor: _kGreen,
      ),
      body: Column(
        children: [
          _scoreboard(),
          _tacticBar(),
          const Divider(height: 1),
          Expanded(
            child: feed.isEmpty
                ? const Center(
                    child: Text(
                      'A bola vai rolar... ⚽',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    itemCount: feed.length,
                    itemBuilder: (context, i) {
                      final e = feed[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: e.type == 'GOAL'
                              ? Colors.green
                              : Colors.grey.shade800,
                          child: Text(
                            "${e.minute}'",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          e.text,
                          style: TextStyle(
                            color: e.type == 'GOAL'
                                ? Colors.greenAccent
                                : Colors.white70,
                            fontWeight:
                                e.type == 'GOAL' ? FontWeight.bold : null,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: finished
                  ? SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'FIM DE JOGO → Continuar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      kTacticDesc[tactic] ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreboard() {
    return Container(
      width: double.infinity,
      color: Colors.black38,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                ClubShield(shortName: home.shortName, size: 36),
                const SizedBox(height: 4),
                Text(
                  home.shortName,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '$hg  x  $ag',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                finished ? 'FIM DE JOGO' : "$minute'",
                style: TextStyle(
                  color: finished ? Colors.orange : Colors.greenAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Expanded(
            child: Column(
              children: [
                ClubShield(shortName: away.shortName, size: 36),
                const SizedBox(height: 4),
                Text(
                  away.shortName,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tacticBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final t in Tactic.values)
            ChoiceChip(
              label: Text(kTacticLabels[t] ?? ''),
              selected: tactic == t,
              selectedColor: Colors.green,
              backgroundColor: Colors.grey.shade900,
              labelStyle: TextStyle(
                color: tactic == t ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              onSelected: finished
                  ? null
                  : (v) {
                      if (v) setState(() => tactic = t);
                    },
            ),
        ],
      ),
    );
  }
}