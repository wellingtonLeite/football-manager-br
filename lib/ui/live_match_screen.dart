import 'dart:async';
import 'dart:math';
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
  int aiSubsUsed = 0;
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
  final List<String> yellowIds = [];
  final List<String> redIds = [];

  // Estatísticas da partida (mandante, visitante)
  int homeShots = 0, awayShots = 0, homeOnTarget = 0, awayOnTarget = 0;
  double homePossession = 50;

  // Campinho 2D: posição da bola (0 = gol do mandante, 1 = gol do visitante)
  double ballX = 0.5;
  double ballY = 0.5;
  final Random _ballRng = Random();
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
    userTactic = game.userTactic;
    home = game.teams.firstWhere((t) => t.id == match.homeId);
    away = game.teams.firstWhere((t) => t.id == match.awayId);
    userIsHome = match.homeId == game.userTeamId;
    homeOn = List<Player>.from(home.startingPlayers);
    homeBench = home.squad.where((p) => !homeOn.contains(p) && !p.unavailable).toList();
    awayOn = List<Player>.from(away.startingPlayers);
    awayBench = away.squad.where((p) => !awayOn.contains(p) && !p.unavailable).toList();
    
    audio.playWhistle();
    audio.playCrowd();
    
    final hs = game.teamStrength(home, homeOn);
    final aws = game.teamStrength(away, awayOn);
    homePossession = (50 + (hs - aws) * 1.2 + (userIsHome ? 0 : 0)).clamp(30, 70).toDouble();
    _timer = Timer.periodic(Duration(milliseconds: audio.matchSpeedMs), (_) => _tick());
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
      _aiFatigueSubs();
      ballX = (ballX + (_ballRng.nextDouble() - 0.5) * 0.25 + (homePossession - 50) / 800).clamp(0.08, 0.92);
      ballY = (ballY + (_ballRng.nextDouble() - 0.5) * 0.3).clamp(0.15, 0.85);
      // Finalizações para fora (só estatística)
      if (minute % 6 == 0) {
        if (homeOn.isNotEmpty && minute % 12 == 0) homeShots++;
        if (awayOn.isNotEmpty && minute % 12 == 6) awayShots++;
      }
      if (minute >= 90) {
        _finish();
      }
    });
  }

  /// Eventos são gerados em blocos de 15 minutos; se o jogador do evento já
  /// saiu de campo, o gol é atribuído a quem está em campo e o resto é descartado.
  MatchEvent? _validate(MatchEvent e) {
    if (e.playerId == null) return e;
    final onPitch = e.teamId == home.id ? homeOn : awayOn;
    if (onPitch.any((p) => p.id == e.playerId)) return e;
    if (e.type != 'GOAL' || onPitch.isEmpty) return null;
    final team = e.teamId == home.id ? home : away;
    final s = game.pickScorer(onPitch);
    return MatchEvent(
      minute: e.minute,
      type: 'GOAL',
      teamId: e.teamId,
      playerId: s.id,
      text: "⚽ GOL do ${team.name}! ${s.name} marca aos ${e.minute}'!",
    );
  }

  void _injury(MatchEvent e) {
    final isHome = e.teamId == home.id;
    final team = isHome ? home : away;
    final p = team.findPlayer(e.playerId!);
    if (p == null) return;
    p.injuredRounds = game.rollInjury(team);
    p.energy = p.energy < 30 ? p.energy : 30;
    audio.playInjury();
    if (e.teamId == game.userTeamId) {
      feed.insert(
        0,
        MatchEvent(
          minute: e.minute,
          type: 'INFO',
          teamId: '',
          text: '⚠️ ${p.name} está lesionado: faça uma substituição (⇄ no topo).',
        ),
      );
      return;
    }
    // IA substitui o lesionado, se puder
    final on = isHome ? homeOn : awayOn;
    final bench = isHome ? homeBench : awayBench;
    if (aiSubsUsed >= maxSubs || bench.isEmpty) return;
    final samePos = bench.where((b) => b.position == p.position).toList();
    final pool = samePos.isEmpty ? List<Player>.from(bench) : samePos;
    pool.sort((a, b) => b.overall.compareTo(a.overall));
    final inn = pool.first;
    on.remove(p);
    on.add(inn);
    bench.remove(inn);
    aiSubsUsed++;
    feed.insert(
      0,
      MatchEvent(
        minute: e.minute,
        type: 'SUB',
        teamId: team.id,
        text: '🔄 ${team.name}: sai ${p.name} (lesionado), entra ${inn.name}.',
      ),
    );
  }

  void _drain(int upTo) {
    while (pending.isNotEmpty && pending.first.minute <= upTo) {
      final e = _validate(pending.removeAt(0));
      if (e == null) continue;
      feed.insert(0, e);
      if (e.type == 'GOAL' || e.type == 'CHANCE') {
        ballX = e.teamId == home.id ? 0.94 : 0.06;
        ballY = 0.4 + _ballRng.nextDouble() * 0.2;
        if (e.teamId == home.id) {
          homeShots++;
          homeOnTarget++;
        } else {
          awayShots++;
          awayOnTarget++;
        }
      }
      if (e.type == 'INJURY') {
        _injury(e);
      } else if (e.type == 'GOAL') {
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
      } else if (e.type == 'RED') {
        _sendOff(e.playerId!, e.teamId, e.minute, direct: true);
      } else if (e.type == 'CARD') {
        audio.playCard();
        yellowIds.add(e.playerId!);
        if (yellowIds.where((id) => id == e.playerId).length >= 2) {
          _sendOff(e.playerId!, e.teamId, e.minute, direct: false);
        }
      }
    }
  }

  List<MatchEvent> _genChunk(int from, int to) {
    final uS = game.teamStrength(game.userTeam!, userOn);
    final aiTeam =
        game.teams.firstWhere((t) => t.id == (userIsHome ? match.awayId : match.homeId));
    final aS = game.teamStrength(aiTeam, aiOn);
    _updateAiTactic();
    final hs = (userIsHome ? uS : aS) + game.homeAdvantage(home);
    final aws = userIsHome ? aS : uS;
    final ht = userIsHome ? userTactic : aiTactic;
    final at = userIsHome ? aiTactic : userTactic;
    return game.generateChunk(
      match: match,
      minFrom: from,
      minTo: to,
      homeTactic: ht,
      awayTactic: at,
      homeStrength: hs,
      awayStrength: aws,
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

  /// Expulsão: o jogador sai e o time fica com um a menos.
  void _sendOff(String playerId, String teamId, int minute, {required bool direct}) {
    final on = teamId == home.id ? homeOn : awayOn;
    final p = on.where((x) => x.id == playerId).firstOrNull;
    if (p == null) return;
    on.remove(p);
    redIds.add(playerId);
    audio.playCard();
    feed.insert(
      0,
      MatchEvent(
        minute: minute,
        type: 'RED',
        teamId: teamId,
        text: direct ? '🟥 ${p.name} está fora: o time joga com ${on.length}.'
            : '🟨🟥 Segundo amarelo! ${p.name} é expulso e o time fica com ${on.length}.',
      ),
    );
  }

  /// A IA troca jogadores muito cansados entre os 60 e 75 minutos.
  void _aiFatigueSubs() {
    if (aiSubsUsed >= maxSubs || minute < 60 || minute > 75 || minute % 5 != 0) return;
    final tired = aiOn.where((p) => p.energy < 45 && p.position != 'GOL').toList()
      ..sort((a, b) => a.energy.compareTo(b.energy));
    if (tired.isEmpty) return;
    final out = tired.first;
    final pool = aiBench.where((b) => !b.unavailable && b.position == out.position).toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    if (pool.isEmpty) return;
    final inn = pool.first;
    aiOn
      ..remove(out)
      ..add(inn);
    aiBench
      ..remove(inn)
      ..add(out);
    aiSubsUsed++;
    final team = userIsHome ? away : home;
    feed.insert(0, MatchEvent(minute: minute, type: 'SUB', teamId: team.id, text: '🔄 ${team.name}: sai ${out.name} (cansado), entra ${inn.name}.'));
  }

  void _aiHalftime() {
    final aiGoals = userIsHome ? ag : hg;
    final userGoals = userIsHome ? hg : ag;
    if (aiGoals < userGoals) {
      final candidates =
          aiOn.where((p) => p.position == 'ATA' || p.position == 'MEI').toList();
      final benchPool =
          aiBench.where((p) => p.position == 'ATA' || p.position == 'MEI').toList();
      if (candidates.isEmpty || benchPool.isEmpty || aiSubsUsed >= maxSubs) return;
      aiSubsUsed++;
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
    audio.stopCrowd();
    audio.playFinalWhistle();
    feed.insert(
      0,
      MatchEvent(
        minute: 90,
        type: 'INFO',
        teamId: '',
        text: '🏁 FIM DE JOGO: ${home.shortName} $hg x $ag ${away.shortName}',
      ),
    );
    int? hp;
    int? ap;
    if (game.needsPenalties(match, hg, ag)) {
      final (h, a) = game.shootout(home, away);
      hp = h;
      ap = a;
      pens = (h, a);
      final winner = h > a ? home : away;
      feed.insert(
        0,
        MatchEvent(
          minute: 90,
          type: 'GOAL',
          teamId: winner.id,
          text: '🥅 PÊNALTIS: ${home.shortName} $h x $a ${away.shortName} — ${winner.name} se classifica!',
        ),
      );
      audio.playGoal();
    }
    if (!applied) {
      applied = true;
      growthMsgs = game.finishUserMatch(
        hg,
        ag,
        userOn,
        userScorerIds,
        aiOn,
        aiScorerIds,
        yellowIds: yellowIds,
        redIds: redIds,
        homePens: hp,
        awayPens: ap,
      );
    }
  }

  /// Placar dos pênaltis, se houve disputa.
  (int, int)? pens;

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
                              title: Text('${p.injured ? '🚑 ' : ''}${p.name}',
                                  style: const TextStyle(color: Colors.white)),
                              subtitle: Text('${p.position} • ⚡${p.energy}',
                                  style: const TextStyle(color: Colors.white60)),
                              onTap: () => setSheet(() => out = p),
                            ),
                        ],
                      )
                    : ListView(
                        children: [
                          for (final p in userBench.where((b) => !b.injured).toList())
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
    return PopScope(
      canPop: finished,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${matchLabel(match)} — AO VIVO', style: const TextStyle(fontSize: 15)),
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
            SizedBox(
              height: 86,
              width: double.infinity,
              child: CustomPaint(painter: _PitchPainter(ballX, ballY, homePossession)),
            ),
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
                                : e.type == 'INJURY'
                                    ? Colors.deepOrange
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
                                  : e.type == 'INJURY'
                                      ? Colors.orangeAccent
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
                                    Text(
                                      'Posse ${homePossession.round()}% x ${100 - homePossession.round()}% • '
                                      'Finalizações $homeShots x $awayShots • No gol $homeOnTarget x $awayOnTarget',
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    if (yellowIds.isNotEmpty || redIds.isNotEmpty)
                                      Text('Cartões: 🟨 ${yellowIds.length} • 🟥 ${redIds.length}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
              if (pens != null)
                Text('Pênaltis: ${pens!.$1} x ${pens!.$2}',
                    style: const TextStyle(color: Colors.amber, fontSize: 12)),
              if (game.aggregateBefore(match) case final agg?)
                Text('Agregado: ${hg + agg.$1} x ${ag + agg.$2}',
                    style: const TextStyle(color: Colors.white60, fontSize: 11)),
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


/// Campinho 2D com a bola e a barra de posse.
class _PitchPainter extends CustomPainter {
  final double ballX;
  final double ballY;
  final double possession;
  _PitchPainter(this.ballX, this.ballY, this.possession);

  @override
  void paint(Canvas canvas, Size size) {
    final field = Rect.fromLTWH(8, 4, size.width - 16, size.height - 18);
    canvas.drawRect(field, Paint()..color = const Color(0xFF2E7D32));
    final line = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(field, line);
    canvas.drawLine(Offset(field.center.dx, field.top), Offset(field.center.dx, field.bottom), line);
    canvas.drawCircle(field.center, field.height * 0.22, line);
    final boxH = field.height * 0.55;
    final boxW = field.width * 0.09;
    canvas.drawRect(Rect.fromLTWH(field.left, field.center.dy - boxH / 2, boxW, boxH), line);
    canvas.drawRect(Rect.fromLTWH(field.right - boxW, field.center.dy - boxH / 2, boxW, boxH), line);
    final ball = Offset(field.left + field.width * ballX, field.top + field.height * ballY);
    canvas.drawCircle(ball, 5, Paint()..color = Colors.white);
    canvas.drawCircle(ball, 5, Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke);
    // Barra de posse
    final barY = size.height - 10;
    final split = 8 + (size.width - 16) * possession / 100;
    canvas.drawRect(Rect.fromLTWH(8, barY, split - 8, 6), Paint()..color = Colors.greenAccent);
    canvas.drawRect(Rect.fromLTWH(split, barY, size.width - 8 - split, 6), Paint()..color = Colors.orangeAccent);
  }

  @override
  bool shouldRepaint(covariant _PitchPainter old) =>
      old.ballX != ballX || old.ballY != ballY || old.possession != possession;
}
