import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'data.dart';

class GameState extends ChangeNotifier {
  List<Team> teams = [];
  List<Match> matches = [];
  int currentRound = 1;
  int seasonYear = 2026;
  String? userTeamId;
  bool started = false;
  final Random _rng = Random();

  int get totalRounds => teams.isEmpty ? 0 : (teams.length - 1) * 2;

  Team? get userTeam =>
      userTeamId == null ? null : teams.firstWhere((t) => t.id == userTeamId);

  Team get champion => standings.first;

  List<Team> get standings {
    final s = List<Team>.from(teams);
    s.sort((a, b) {
      if (b.points != a.points) return b.points.compareTo(a.points);
      if (b.wins != a.wins) return b.wins.compareTo(a.wins);
      if (b.goalDifference != a.goalDifference) {
        return b.goalDifference.compareTo(a.goalDifference);
      }
      if (b.goalsFor != a.goalsFor) return b.goalsFor.compareTo(a.goalsFor);
      return a.name.compareTo(b.name);
    });
    return s;
  }

  int get userPosition => standings.indexWhere((t) => t.id == userTeamId) + 1;

  bool get seasonFinished => currentRound > totalRounds;

  void startGame(String teamId) {
    teams = createLeague();
    for (final t in teams) {
      t.startingIds = autoLineup(t);
    }
    userTeamId = teamId;
    matches = _generateSchedule();
    currentRound = 1;
    seasonYear = 2026;
    started = true;
    notifyListeners();
  }

  List<String> autoLineup(Team t) {
    const quota = {'GOL': 1, 'ZAG': 2, 'LAT': 2, 'VOL': 2, 'MEI': 2, 'ATA': 2};
    final ids = <String>[];
    final pool = List<Player>.from(t.squad);
    quota.forEach((pos, n) {
      final cands = pool.where((p) => p.position == pos).toList()
        ..sort((a, b) => b.overall.compareTo(a.overall));
      for (int i = 0; i < n && i < cands.length; i++) {
        ids.add(cands[i].id);
        pool.remove(cands[i]);
      }
    });
    while (ids.length < 11 && pool.isNotEmpty) {
      pool.sort((a, b) => b.overall.compareTo(a.overall));
      ids.add(pool.removeAt(0).id);
    }
    return ids;
  }

  List<Match> get currentRoundMatches =>
      matches.where((m) => m.round == currentRound).toList();

  bool get currentRoundPlayed =>
      currentRoundMatches.isNotEmpty &&
      currentRoundMatches.every((m) => m.isPlayed);

  Match? get userMatchCurrent {
    if (seasonFinished) return null;
    final ms = currentRoundMatches
        .where((m) => m.homeId == userTeamId || m.awayId == userTeamId)
        .toList();
    return ms.isEmpty ? null : ms.first;
  }

  void simulateOtherMatches() {
    for (final m in currentRoundMatches) {
      if (m.isPlayed) continue;
      if (m.homeId == userTeamId || m.awayId == userTeamId) continue;
      final home = teams.firstWhere((t) => t.id == m.homeId);
      final away = teams.firstWhere((t) => t.id == m.awayId);
      final score = _simulateScore(home, away);
      m.homeGoals = score[0];
      m.awayGoals = score[1];
      _applyResult(home, away, score[0], score[1]);
      _applyEffects(home, home.startingPlayers, score[0], score[1], const []);
      _applyEffects(away, away.startingPlayers, score[1], score[0], const []);
    }
    notifyListeners();
  }

  List<String> finishUserMatch(
    int hg,
    int ag,
    List<Player> userOnPitch,
    List<String> userScorerIds,
    List<Player> aiOnPitch,
    List<String> aiScorerIds,
  ) {
    final m = userMatchCurrent;
    if (m == null) return const [];
    final userIsHome = m.homeId == userTeamId;
    final uTeam = userTeam!;
    final aTeam =
        teams.firstWhere((t) => t.id == (userIsHome ? m.awayId : m.homeId));
    final uGf = userIsHome ? hg : ag;
    final uGa = userIsHome ? ag : hg;
    final aGf = userIsHome ? ag : hg;
    final aGa = userIsHome ? hg : ag;
    final msgs = _applyEffects(uTeam, userOnPitch, uGf, uGa, userScorerIds);
    _applyEffects(aTeam, aiOnPitch, aGf, aGa, aiScorerIds);
    final homeTeam = teams.firstWhere((t) => t.id == m.homeId);
    final awayTeam = teams.firstWhere((t) => t.id == m.awayId);
    m.homeGoals = hg;
    m.awayGoals = ag;
    _applyResult(homeTeam, awayTeam, hg, ag);
    notifyListeners();
    return msgs;
  }

  List<String> _applyEffects(
    Team t,
    List<Player> onPitch,
    int gf,
    int ga,
    List<String> scorerIds,
  ) {
    final won = gf > ga;
    final drew = gf == ga;
    final msgs = <String>[];
    for (final p in onPitch) {
      p.energy = (p.energy - 25).clamp(20, 100).toInt();
      p.morale = (p.morale + (won ? 6 : drew ? 1 : -6)).clamp(0, 100).toInt();
      int xp = 8 + (won ? 4 : 0);
      xp += 6 * scorerIds.where((id) => id == p.id).length;
      msgs.addAll(p.gainXp(xp));
    }
    return msgs;
  }

  void advanceRound() {
    if (!currentRoundPlayed || seasonFinished) return;
    currentRound++;
    for (final t in teams) {
      for (final p in t.squad) {
        p.energy = (p.energy + 15).clamp(0, 100).toInt();
      }
    }
    notifyListeners();
  }

  void startNewSeason() {
    seasonYear++;
    for (final t in teams) {
      t.points = 0;
      t.wins = 0;
      t.draws = 0;
      t.losses = 0;
      t.goalsFor = 0;
      t.goalsAgainst = 0;
      t.played = 0;
      for (final p in t.squad) {
        p.age++;
        if (p.age >= 34) {
          p.overall = (p.overall - 2).clamp(55, 94).toInt();
        } else if (p.age >= 32) {
          p.overall = (p.overall - 1).clamp(55, 94).toInt();
        }
        p.energy = 100;
        p.morale = 70;
      }
      t.startingIds = autoLineup(t);
    }
    matches = _generateSchedule();
    currentRound = 1;
    notifyListeners();
  }

  // ---------- TÁTICAS E FORÇA ----------

  List<double> _tacticMods(Tactic t) {
    switch (t) {
      case Tactic.retranca:
        return [-0.45, -0.35];
      case Tactic.neutro:
        return [0.0, 0.0];
      case Tactic.ofensivo:
        return [0.35, 0.15];
      case Tactic.tudoOuNada:
        return [0.70, 0.45];
    }
  }

  List<double> lambdasFrom(double hs, double as, Tactic ht, Tactic at) {
    final diff = hs - as;
    final mh = _tacticMods(ht);
    final ma = _tacticMods(at);
    final lh = (1.45 + diff / 18.0 + mh[0] + ma[1]).clamp(0.25, 4.5).toDouble();
    final la = (1.15 - diff / 18.0 + ma[0] + mh[1]).clamp(0.25, 4.5).toDouble();
    return [lh, la];
  }

  List<int> _simulateScore(Team home, Team away) {
    final hs = home.pitchStrength(home.startingPlayers) + 4.0;
    final as = away.pitchStrength(away.startingPlayers);
    final l = lambdasFrom(hs, as, Tactic.neutro, Tactic.neutro);
    return [_poisson(l[0]), _poisson(l[1])];
  }

  int _poisson(double lambda) {
    final double limit = exp(-lambda);
    int k = 0;
    double p = 1.0;
    do {
      k++;
      p *= _rng.nextDouble();
    } while (p > limit);
    return k - 1;
  }

  // ---------- PARTIDA AO VIVO ----------

  List<MatchEvent> generateChunk({
    required Match match,
    required int minFrom,
    required int minTo,
    required Tactic homeTactic,
    required Tactic awayTactic,
    required double homeStrength,
    required double awayStrength,
    required List<Player> homeOnPitch,
    required List<Player> awayOnPitch,
  }) {
    final l =
        lambdasFrom(homeStrength, awayStrength, homeTactic, awayTactic);
    final home = teams.firstWhere((t) => t.id == match.homeId);
    final away = teams.firstWhere((t) => t.id == match.awayId);
    final events = <MatchEvent>[];
    for (int min = minFrom; min < minTo; min++) {
      if (_rng.nextDouble() < l[0] / 90.0) {
        final s = _pickScorer(homeOnPitch);
        events.add(MatchEvent(
          minute: min,
          type: 'GOAL',
          teamId: home.id,
          playerId: s.id,
          text: "⚽ GOL do ${home.name}! ${s.name} marca aos $min'!",
        ));
      }
      if (_rng.nextDouble() < l[1] / 90.0) {
        final s = _pickScorer(awayOnPitch);
        events.add(MatchEvent(
          minute: min,
          type: 'GOAL',
          teamId: away.id,
          playerId: s.id,
          text: "⚽ GOL do ${away.name}! ${s.name} marca aos $min'!",
        ));
      }
      if (_rng.nextDouble() < 0.05) {
        final bool h = _rng.nextBool();
        final t = h ? home : away;
        final p = _pickScorer(h ? homeOnPitch : awayOnPitch);
        events.add(MatchEvent(
          minute: min,
          type: 'CHANCE',
          teamId: t.id,
          playerId: p.id,
          text: "🔥 Chance do ${t.name}: ${p.name} finaliza e o goleiro salva!",
        ));
      }
      if (_rng.nextDouble() < 0.012) {
        final bool h = _rng.nextBool();
        final t = h ? home : away;
        final list = h ? homeOnPitch : awayOnPitch;
        final p = list[_rng.nextInt(list.length)];
        events.add(MatchEvent(
          minute: min,
          type: 'CARD',
          teamId: t.id,
          playerId: p.id,
          text: "🟨 Cartão amarelo para ${p.name} (${t.name}).",
        ));
      }
    }
    return events;
  }

  Player _pickScorer(List<Player> onPitch) {
    final att =
        onPitch.where((p) => p.position == 'ATA' || p.position == 'MEI').toList();
    final pool = att.isEmpty ? onPitch : att;
    pool.sort((a, b) => b.overall.compareTo(a.overall));
    final n = pool.length < 5 ? pool.length : 5;
    return pool[_rng.nextInt(n)];
  }

  // ---------- CALENDÁRIO ----------

  List<Match> _generateSchedule() {
    final ids = teams.map((t) => t.id).toList();
    final n = ids.length;
    final List<Match> result = [];
    List<String> rotating = ids.sublist(1);
    for (int round = 0; round < (n - 1) * 2; round++) {
      final roundIds = [ids[0], ...rotating];
      final firstHalf = round < n - 1;
      for (int i = 0; i < n ~/ 2; i++) {
        String a = roundIds[i];
        String b = roundIds[n - 1 - i];
        String home = firstHalf ? a : b;
        String away = firstHalf ? b : a;
        if (i.isOdd) {
          final tmp = home;
          home = away;
          away = tmp;
        }
        result.add(Match(round: round + 1, homeId: home, awayId: away));
      }
      rotating = [rotating.last, ...rotating.sublist(0, rotating.length - 1)];
    }
    return result;
  }

  void _applyResult(Team home, Team away, int hg, int ag) {
    home.played++;
    away.played++;
    home.goalsFor += hg;
    home.goalsAgainst += ag;
    away.goalsFor += ag;
    away.goalsAgainst += hg;
    if (hg > ag) {
      home.wins++;
      home.points += 3;
      away.losses++;
    } else if (hg < ag) {
      away.wins++;
      away.points += 3;
      home.losses++;
    } else {
      home.draws++;
      away.draws++;
      home.points++;
      away.points++;
    }
  }
}