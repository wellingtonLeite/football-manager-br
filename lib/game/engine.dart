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
    userTeamId = teamId;
    matches = _generateSchedule();
    currentRound = 1;
    seasonYear = 2026;
    started = true;
    notifyListeners();
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
      if (m.homeId == userTeamId || m.awayId == userTeamId) continue;
      final home = teams.firstWhere((t) => t.id == m.homeId);
      final away = teams.firstWhere((t) => t.id == m.awayId);
      final score = _simulateScore(home, away, Tactic.neutro, Tactic.neutro);
      m.homeGoals = score[0];
      m.awayGoals = score[1];
      _applyResult(home, away, score[0], score[1]);
    }
    notifyListeners();
  }

  void applyUserMatchResult(int hg, int ag) {
    final m = userMatchCurrent;
    if (m == null) return;
    final home = teams.firstWhere((t) => t.id == m.homeId);
    final away = teams.firstWhere((t) => t.id == m.awayId);
    m.homeGoals = hg;
    m.awayGoals = ag;
    _applyResult(home, away, hg, ag);
    notifyListeners();
  }

  void advanceRound() {
    if (!currentRoundPlayed || seasonFinished) return;
    currentRound++;
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
      }
    }
    matches = _generateSchedule();
    currentRound = 1;
    notifyListeners();
  }

  // ---------- SIMULAÇÃO ----------

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

  List<double> _lambdas(Team home, Team away, Tactic ht, Tactic at) {
    final double hs = home.strength + 4.0;
    final double as = away.strength.toDouble();
    final double diff = hs - as;
    final List<double> mh = _tacticMods(ht);
    final List<double> ma = _tacticMods(at);
    final double lh =
        (1.45 + diff / 18.0 + mh[0] + ma[1]).clamp(0.25, 4.5).toDouble();
    final double la =
        (1.15 - diff / 18.0 + ma[0] + mh[1]).clamp(0.25, 4.5).toDouble();
    return [lh, la];
  }

  List<int> _simulateScore(Team home, Team away, Tactic ht, Tactic at) {
    final l = _lambdas(home, away, ht, at);
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

  List<MatchEvent> generateChunk(
    Match m,
    int minFrom,
    int minTo,
    Tactic userTactic,
    int hg,
    int ag,
  ) {
    final home = teams.firstWhere((t) => t.id == m.homeId);
    final away = teams.firstWhere((t) => t.id == m.awayId);
    final bool userIsHome = home.id == userTeamId;

    final int aiDiff = userIsHome ? ag - hg : hg - ag;
    Tactic ai = Tactic.neutro;
    if (minFrom >= 60 && aiDiff <= -1) ai = Tactic.ofensivo;
    if (minFrom >= 70 && aiDiff >= 2) ai = Tactic.retranca;

    final Tactic ht = userIsHome ? userTactic : ai;
    final Tactic at = userIsHome ? ai : userTactic;
    final l = _lambdas(home, away, ht, at);

    final List<MatchEvent> events = [];
    for (int min = minFrom; min < minTo; min++) {
      if (_rng.nextDouble() < l[0] / 90.0) {
        events.add(MatchEvent(
          minute: min,
          type: 'GOAL',
          teamId: home.id,
          text: "⚽ GOL do ${home.name}! ${_scorer(home)} marca aos $min'!",
        ));
      }
      if (_rng.nextDouble() < l[1] / 90.0) {
        events.add(MatchEvent(
          minute: min,
          type: 'GOAL',
          teamId: away.id,
          text: "⚽ GOL do ${away.name}! ${_scorer(away)} marca aos $min'!",
        ));
      }
      if (_rng.nextDouble() < 0.05) {
        final t = _rng.nextBool() ? home : away;
        events.add(MatchEvent(
          minute: min,
          type: 'CHANCE',
          teamId: t.id,
          text: "🔥 Chance do ${t.name}: ${_scorer(t)} finaliza e o goleiro salva!",
        ));
      }
      if (_rng.nextDouble() < 0.012) {
        final t = _rng.nextBool() ? home : away;
        events.add(MatchEvent(
          minute: min,
          type: 'CARD',
          teamId: t.id,
          text: "🟨 Cartão amarelo para ${_anyPlayer(t)} (${t.name}).",
        ));
      }
    }
    return events;
  }

  String _scorer(Team t) {
    final att =
        t.squad.where((p) => p.position == 'ATA' || p.position == 'MEI').toList();
    if (att.isEmpty) return t.squad.first.name;
    att.sort((a, b) => b.overall.compareTo(a.overall));
    return att[_rng.nextInt(att.length < 5 ? att.length : 5)].name;
  }

  String _anyPlayer(Team t) => t.squad[_rng.nextInt(t.squad.length)].name;

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