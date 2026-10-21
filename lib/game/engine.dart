import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'data.dart';

class GameState extends ChangeNotifier {
  List<Team> teams = [];
  List<Match> matches = [];
  int currentRound = 1;
  String? userTeamId;
  bool started = false;
  final Random _rng = Random();

  int get totalRounds => teams.isEmpty ? 0 : (teams.length - 1) * 2;

  Team? get userTeam =>
      userTeamId == null ? null : teams.firstWhere((t) => t.id == userTeamId);

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
    started = true;
    notifyListeners();
  }

  List<Match> get currentRoundMatches =>
      matches.where((m) => m.round == currentRound).toList();

  bool get currentRoundPlayed => currentRoundMatches.every((m) => m.isPlayed);

  void simulateRound() {
    if (currentRoundPlayed || seasonFinished) return;
    for (final m in currentRoundMatches) {
      final home = teams.firstWhere((t) => t.id == m.homeId);
      final away = teams.firstWhere((t) => t.id == m.awayId);
      final score = _simulateScore(home, away);
      m.homeGoals = score[0];
      m.awayGoals = score[1];
      _applyResult(home, away, score[0], score[1]);
    }
    notifyListeners();
  }

  void advanceRound() {
    if (!currentRoundPlayed) return;
    currentRound++;
    notifyListeners();
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

  List<int> _simulateScore(Team home, Team away) {
    final double hs = home.strength + 4.0;
    final double as = away.strength;
    final double diff = hs - as;
    final double lambdaHome = (1.45 + diff / 18.0).clamp(0.25, 4.5).toDouble();
    final double lambdaAway = (1.15 - diff / 18.0).clamp(0.25, 4.5).toDouble();
    return [_poisson(lambdaHome), _poisson(lambdaAway)];
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
}
