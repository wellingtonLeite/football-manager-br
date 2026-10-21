import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/engine.dart';
import '../game/models.dart';
import 'shield.dart';
import 'audio_service.dart';

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
  late final bool userIsHome;
  late List<Player> homeOn;
  late List<Player> homeBench;
  late List<Player> awayOn;
  late List<Player> awayBench;
  late AudioService audio;

  Timer? _timer;
  int minute = 0;
  int hg = 0;
  int ag = 0;
  int nextChunk = 1;
  int subsUsed = 0;
  static const int maxSubs = 5;
  bool finished = false;
  bool halftime = false;
  bool applied = false;
  Tactic userTactic = Tactic.neutro;
  Tactic aiTactic = Tactic.neutro;
  String? talkApplied;
  final List<MatchEvent> feed = [];
  final List<MatchEvent> pending = [];
  final List<String> userScorerIds = [];
  final List<String> aiScorerIds = [];
  List<String> growthMsgs = [];

  List<Player> get userOn => userIsHome ? homeOn : awayOn;
  List<Player> get userBench => userIsHome ? homeBench : awayBench;
  List<Player> get aiOn => userIsHome ? awayOn : homeOn;
  List<Player> get aiBench => userIsHome ? awayBench : homeBench;

  @override
  void initState() {
    super.initState();
    game = context.read<GameState>();
    audio = context.read<AudioService>();
    match = game.userMatchCurrent!;
    home = game.teams.firstWhere((t) => t.id == match.homeId);
    away = game.teams.firstWhere((t) => t.id == match.awayId);
    userIsHome = match.homeId == game.userTeamId;
    homeOn = List<Player>.from(home.startingPlayers);
    homeBench = home.squad.where((p) => !homeOn.contains(p)).toList();
    awayOn = List<Player>.from(away.startingPlayers);
    awayBench = away.squad.where((p) => !awayOn.contains(p)).toList();
    
    audio.playWhistle();
    audio.playCrowd();
    
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    audio.stopCrowd();
    super.dispose();
  }

  void _tick() {
    if (finished || halftime) return;
    setState(() {
      minute++;
      if (minute == 45) {
        _drain(45);
        halftime = true;
        audio.playWhistle();
        feed.insert(
          0,
          MatchEvent(
            minute: 45,
            type: 'INFO',
            teamId: '',
            text: '⏱️ INTERVALO: ${home.shortName} $hg x $ag ${away.shortName}',
          ),
        );
        _aiHalftime();
        return;
      }
      if (minute >= nextChunk) {
        final end = nextChunk + 15 > 90 ? 91 : nextChunk + 15;
        pending.addAll(_genChunk(nextChunk, end));
        pending.sort((a, b) => a.minute.compareTo(b.minute));
        nextChunk = end;
      }
      _drain(minute);
      if (minute >= 90) {
        _finish();
      }
    });
  }

  void _drain(int upTo) {
    while (pending.isNotEmpty && pending.first.minute <= upTo) {
      final e = pending.removeAt(0);
      feed.insert(0, e);
      if (e.type == 'GOAL') {
        audio.playGoal();
        if (e.teamId == home.id) {
          hg++;
        } else {
          ag++;
        }
        if (e.playerId != null) {
          if (e.teamId == game.userTeamId) {
            userScorerIds.add(e.playerId!);
          } else {
            aiScorerIds.add(e.playerId!);
          }
        }
      } else if (e.type == 'CARD') {
        audio.playCard();
      }
    }
  }

  List<MatchEvent> _genChunk(int from, int to) {
    final uS = game.userTeam!.pitchStrength(userOn);
    final aiTeam =
        game.teams.firstWhere((t) => t.id == (userIsHome ? match.awayId : match.homeId));
    final aS = aiTeam.pitchStrength(aiOn);
    _updateAiTactic();
    final hs = userIsHome ? uS + 4.0 : aS + 4.0;
    final as = userIsHome ? aS : uS;
    final ht = userIsHome ? userTactic : aiTactic;
    final at = userIsHome ? aiTactic : userTactic;
    return game.generateChunk(
      match: match,
      minFrom: from,
      minTo: to,
      homeTactic: ht,
      awayTactic: at,
      homeStrength: hs,
      awayStrength: as,
      homeOnPitch: homeOn,
      awayOnPitch: awayOn,
    );
  }

  void _updateAiTactic() {
    final aiGoals = userIsHome ? ag : hg;
    final userGoals = userIsHome ? hg : ag;
    final diff = aiGoals - userGoals;
    aiTactic = Tactic.neutro;
    if (minute >= 60 && diff <= -1) aiTactic = Tactic.ofensivo;
    if (minute >= 70 && diff >= 2) aiTactic = Tactic.retranca;
  }

  void _aiHalftime() {
    final aiGoals = userIsHome ? ag : hg;
    final userGoals = userIsHome ? hg : ag;
    if (aiGoals < userGoals) {
      final candidates =
          aiOn.where((p) => p.position == 'ATA' || p.position == 'MEI').toList();
      final benchPool =
          aiBench.where((p) => p.position == 'ATA' || p.position == 'MEI').toList();
      if (candidates.isEmpty || benchPool.isEmpty) return;
      candidates.sort((a, b) => a.overall.compareTo(b.overall));
      benchPool.sort((a, b) => b.overall.compareTo(a.overall));
      final out = candidates.first;
      final inn = benchPool.first;
      aiOn.remove(out);
      aiBench.add(out);
      aiOn.add(inn);
      aiBench.remove(inn);
      final aiTeam = userIsHome ? away : home;
      feed.insert(
        0,
        MatchEvent(
          minute: 45,
          type: 'SUB',
          teamId: aiTeam.id,
          text: '🔄 ${aiTeam.name}: sai ${out.name}, entra ${inn.name}.',
        ),
      );
    }
  }

  void _finish() {
    finished = true;
    _timer?.cancel();
    audio.playWhistle();
    feed.insert(
      0,
      MatchEvent(
        minute: 90,
        type: 'INFO',
        teamId: '',
        text: '🏁 FIM DE JOGO: ${home.shortName} $hg x $ag ${away.shortName}',
      ),
    );
    if (!applied) {
      applied = true;
      growthMsgs = game.finishUserMatch(
        hg,
        ag,
        userOn,
        userScorerIds,
        aiOn,
        aiScorerIds,
      );
    }
  }

  void _applyTalk(String key) {
    if (talkApplied != null) return;
    talkApplied = key;
    for (final p in userOn) {
      if (key == 'motivar') {
        p.morale = (p.morale + 6).clamp(0, 100).toInt();
      }
      if (key == 'descanso') {
        p.energy = (p.energy + 10).clamp(0, 100).toInt();
      }
      if (key == 'equilibrada') {
        p.morale = (p.morale + 3).clamp(0, 100).toInt();
        p.energy = (p.energy + 5).clamp(0, 100).toInt();
      }
    }
    setState(() {});
  }

  void _openSubSheet() {
    if (subsUsed >= maxSubs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limite de 5 substituições atingido!')),
      );
      return;
    }
    audio.playButton();
    Player? out;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF263238),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          color: const Color(0xFF263238),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  out == null
                      ? '1) Quem SAI? (sub ${subsUsed + 1}/$maxSubs)'
                      : '2) Quem ENTRA? (${out!.name} sai)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: out == null
                    ? ListView(
                        children: [
                          for (final p in List<Player>.from(userOn))
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey.shade700,
                                child: Text('${p.overall}',
                                    style: const TextStyle(color: Colors.white)),
                              ),
                              title: Text(p.name,
                                  style: const TextStyle(color: Colors.white)),
                              subtitle: Text('${p.position} • ⚡${p.energy}',
                                  style: const TextStyle(color: Colors.white60)),
                              onTap: () => setSheet(() => out = p),
                            ),
                        ],
                      )
                    : ListView(
                        children: [
                          for (final p in List<Player>.from(userBench))
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey.shade700,
                                child: Text('${p.overall}',
                                    style: const TextStyle(color: Colors.white)),
                              ),
                              title: Text(p.name,
                                  style: const TextStyle(color: Colors.white)),
                              subtitle: Text('${p.position} • ⚡${p.energy}',
                                  style: const TextStyle(color: Colors.white60)),
                              onTap: () {
                                audio.playButton();
                                setState(() {
                                  userOn.remove(out);
                                  userBench.add(out!);
                                  userOn.add(p);
                                  userBench.remove(p);
                                  subsUsed++;
                                  feed.insert(
                                    0,
                                    MatchEvent(
                                      minute: minute,
                                      type: 'SUB',
                                      teamId: game.userTeamId!,
                                      text:
                                          '🔄 ${game.userTeam!.name}: sai ${out!.name}, entra ${p.name}.',
                                    ),
                                  );
                                });
                                Navigator.pop(ctx);
                              },
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rodada ${match.round} — AO VIVO'),
        backgroundColor: _kGreen,
        actions: [
          IconButton(
            icon: Icon(audio.muted ? Icons.volume_off : Icons.volume_up),
            onPressed: audio.toggleMute,
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Substituição',
            onPressed: finished ? null : _openSubSheet,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('$subsUsed/$maxSubs',
                  style: const TextStyle(color: Colors.white70)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _scoreboard(),
          if (halftime && !finished) _halftimePanel() else _tacticBar(),
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
                        onPressed: () {
                          audio.playButton();
                          showDialog(
                            context: context,
                            builder: (dlg) => AlertDialog(
                              backgroundColor: const Color(0xFF263238),
                              title: const Text('📈 Pós-Jogo',
                                  style: TextStyle(color: Colors.white)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Placar: ${home.shortName} $hg x $ag ${away.shortName}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  if (growthMsgs.isEmpty)
                                    const Text(
                                      'Sem evoluções desta vez. XP acumulado!',
                                      style: TextStyle(color: Colors.white70),
                                    )
                                  else
                                    for (final m in growthMsgs)
                                      Text('⬆️ $m',
                                          style: const TextStyle(
                                              color: Colors.greenAccent)),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '⚡ Titulares: -25 de energia (recupera na próxima rodada).',
                                    style: TextStyle(
                                        color: Colors.white60, fontSize: 12),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    audio.playButton();
                                    Navigator.pop(dlg);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Continuar'),
                                ),
                              ],
                            ),
                          );
                        },
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
                      kTacticDesc[userTactic] ?? '',
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
                Text(home.shortName,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
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
                Text(away.shortName,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _halftimePanel() {
    return Container(
      color: Colors.black45,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Text('☕ INTERVALO',
              style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            talkApplied == null
                ? 'Palestra: escolha uma opção'
                : 'Palestra aplicada ✔',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Wrap(
            spacing: 6,
            children: [
              _talkChip('motivar', '🔥 Motivacional'),
              _talkChip('descanso', '😮‍💨 Descanso'),
              _talkChip('equilibrada', '📋 Equilibrada'),
            ],
          ),
          const SizedBox(height: 6),
          _tacticChips(),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                audio.playButton();
                setState(() {
                  halftime = false;
                  audio.playWhistle();
                  feed.insert(
                    0,
                    MatchEvent(
                      minute: 45,
                      type: 'INFO',
                      teamId: '',
                      text: '⏱️ Bola rolando no 2º tempo!',
                    ),
                  );
                });
              },
              child: const Text('▶️ Iniciar 2º Tempo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _talkChip(String key, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: talkApplied == key,
      selectedColor: Colors.amber,
      backgroundColor: Colors.grey.shade900,
      labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
      onSelected: talkApplied == null ? (v) { if (v) { audio.playButton(); _applyTalk(key); } } : null,
    );
  }

  Widget _tacticBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: _tacticChips(),
    );
  }

  Widget _tacticChips() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in Tactic.values)
          ChoiceChip(
            label: Text(kTacticLabels[t] ?? ''),
            selected: userTactic == t,
            selectedColor: Colors.green,
            backgroundColor: Colors.grey.shade900,
            labelStyle: TextStyle(
              color: userTactic == t ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            onSelected: finished
                ? null
                : (v) {
                    if (v) {
                      audio.playButton();
                      setState(() => userTactic = t);
                    }
                  },
          ),
      ],
    );
  }
}
