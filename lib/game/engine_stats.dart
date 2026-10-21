part of 'engine.dart';

/// Números de um jogador na temporada (todas as competições).
class PlayerStatLine {
  String name;
  String teamId;
  String position;
  int age;
  int games = 0;
  int goals = 0;
  int assists = 0;
  int yellows = 0;
  int reds = 0;
  double ratingSum = 0;
  final Map<String, int> goalsByComp = {};

  PlayerStatLine({required this.name, required this.teamId, required this.position, required this.age});

  double get avgRating => games == 0 ? 0 : ratingSum / games;

  Map<String, dynamic> toJson() => {
    'n': name, 't': teamId, 'p': position, 'a': age, 'g': games, 'gl': goals, 'as': assists,
    'y': yellows, 'r': reds, 'rs': double.parse(ratingSum.toStringAsFixed(1)), 'gc': goalsByComp,
  };

  factory PlayerStatLine.fromJson(Map<String, dynamic> j) =>
      PlayerStatLine(name: j['n'], teamId: j['t'], position: j['p'] ?? 'MEI', age: j['a'] ?? 25)
        ..games = j['g'] ?? 0
        ..goals = j['gl'] ?? 0
        ..assists = j['as'] ?? 0
        ..yellows = j['y'] ?? 0
        ..reds = j['r'] ?? 0
        ..ratingSum = (j['rs'] ?? 0).toDouble()
        ..goalsByComp.addAll(Map<String, int>.from(j['gc'] ?? {}));
}

/// Recordes históricos do clube do usuário.
class ClubRecord {
  String biggestWin = '';
  int biggestDiff = 0;
  int bestCrowd = 0;
  final Map<String, int> scorers = {};
  final Map<String, int> apps = {};

  ClubRecord();

  Map<String, dynamic> toJson() => {'bw': biggestWin, 'bd': biggestDiff, 'bc': bestCrowd, 'sc': scorers, 'ap': apps};

  factory ClubRecord.fromJson(Map<String, dynamic> j) => ClubRecord()
    ..biggestWin = j['bw'] ?? ''
    ..biggestDiff = j['bd'] ?? 0
    ..bestCrowd = j['bc'] ?? 0
    ..scorers.addAll(Map<String, int>.from(j['sc'] ?? {}))
    ..apps.addAll(Map<String, int>.from(j['ap'] ?? {}));
}

extension GameStats on GameState {
  static double _attackW(String pos) => const {'ATA': 3.0, 'MEI': 2.0, 'VOL': 0.8, 'LAT': 0.7, 'ZAG': 0.4, 'GOL': 0.0}[pos] ?? 1.0;
  static double _assistW(String pos) => const {'ATA': 1.5, 'MEI': 3.0, 'VOL': 1.2, 'LAT': 1.5, 'ZAG': 0.3, 'GOL': 0.05}[pos] ?? 1.0;

  Player? _weighted(List<Player> pool, double Function(Player) w, {Player? exclude}) {
    double total = 0;
    for (final p in pool) {
      if (p != exclude) total += w(p);
    }
    if (total <= 0) return null;
    var r = _rng.nextDouble() * total;
    for (final p in pool) {
      if (p == exclude) continue;
      r -= w(p);
      if (r <= 0) return p;
    }
    return pool.last;
  }

  /// Autores dos gols de um jogo simulado (atacantes e meias marcam mais).
  List<String> _pickScorers(List<Player> onPitch, int goals) {
    final out = <String>[];
    for (int i = 0; i < goals; i++) {
      final p = _weighted(onPitch, (p) => _attackW(p.position) * p.overall);
      if (p != null) out.add(p.id);
    }
    return out;
  }

  /// Cartões de um jogo simulado: amarelos e, às vezes, um vermelho.
  (List<String>, List<String>) _randomCards(List<Player> homeOn, List<Player> awayOn) {
    final yellows = <String>[];
    final reds = <String>[];
    for (final side in [homeOn, awayOn]) {
      if (side.isEmpty) continue;
      final n = _rng.nextInt(4);
      for (int i = 0; i < n; i++) {
        yellows.add(side[_rng.nextInt(side.length)].id);
      }
      if (_rng.nextDouble() < 0.04) reds.add(side[_rng.nextInt(side.length)].id);
    }
    return (yellows, reds);
  }

  /// Amarelos acumulam (3 = suspensão) e vermelho suspende o próximo jogo.
  void _applyCards(Match m, List<String> yellows, List<String> reds) {
    final home = teamById(m.homeId);
    final away = teamById(m.awayId);
    Player? find(String id) => home.findPlayer(id) ?? away.findPlayer(id);
    final counted = <String, int>{};
    for (final id in yellows) {
      counted[id] = (counted[id] ?? 0) + 1;
    }
    counted.forEach((id, n) {
      final p = find(id);
      if (p == null) return;
      if (n >= 2) return; // dois amarelos no jogo viram vermelho (tratado abaixo)
      p.yellowCards++;
      if (p.yellowCards >= 3) {
        p
          ..yellowCards = 0
          ..suspended = max(p.suspended, 1);
        if (_isUserPlayer(p)) _addNews('🟨 ${p.name} levou o 3º amarelo e cumpre suspensão no próximo jogo.');
      }
    });
    for (final id in {...reds, ...counted.entries.where((e) => e.value >= 2).map((e) => e.key)}) {
      final p = find(id);
      if (p == null) continue;
      p.suspended = max(p.suspended, 1);
      if (_isUserPlayer(p)) _addNews('🟥 ${p.name} foi expulso e está suspenso para o próximo jogo.');
    }
  }

  bool _isUserPlayer(Player p) => userTeam?.findPlayer(p.id) != null;

  /// Suspensos que ficaram de fora deste jogo cumprem a pena.
  void _serveSuspensions(Team t, List<Player> onPitch) {
    for (final p in t.squad) {
      if (p.suspended > 0 && !onPitch.contains(p)) p.suspended--;
    }
  }

  PlayerStatLine _line(Player p, Team t) {
    final l = stats[p.id] ??= PlayerStatLine(name: p.name, teamId: t.id, position: p.position, age: p.age);
    l
      ..teamId = t.id
      ..name = p.name;
    return l;
  }

  void _recordStats(Match m, Team home, Team away, List<Player> homeOn, List<Player> awayOn, int hg, int ag,
      List<String> homeScorers, List<String> awayScorers, List<String> givenAssists, List<String> yellows, List<String> reds) {
    final lite = home.isForeign && away.isForeign; // jogos só de estrangeiros: só gols
    final ratings = <Player, double>{};
    final assists = <String>[...givenAssists];
    void side(Team t, List<Player> on, int gf, int ga, List<String> scorers) {
      final goals = <String, int>{};
      for (final id in scorers) {
        goals[id] = (goals[id] ?? 0) + 1;
      }
      if (givenAssists.isEmpty) {
        for (final id in scorers) {
          if (_rng.nextDouble() > 0.7) continue;
          final scorer = on.where((p) => p.id == id).firstOrNull;
          final a = _weighted(on, (p) => _assistW(p.position) * p.overall, exclude: scorer);
          if (a != null) assists.add(a.id);
        }
      }
      for (final p in on) {
        final g = goals[p.id] ?? 0;
        final a = assists.where((x) => x == p.id).length;
        if (lite && g == 0 && a == 0) continue;
        final l = _line(p, t);
        l
          ..goals += g
          ..assists += a;
        if (g > 0) l.goalsByComp[m.comp] = (l.goalsByComp[m.comp] ?? 0) + g;
        if (lite) continue;
        double r = 6.0 + g * 1.0 + a * 0.6 + (gf > ga ? 0.4 : gf < ga ? -0.4 : 0) + (p.overall - 72) * 0.03;
        r += (_rng.nextDouble() + _rng.nextDouble() - 1) * 0.8;
        if (p.position == 'GOL') r += ga == 0 ? 0.8 : -0.3 * ga;
        if (p.position == 'ZAG' || p.position == 'LAT') r += ga == 0 ? 0.4 : -0.15 * ga;
        if (reds.contains(p.id)) r -= 1.5;
        r = (r.clamp(3.0, 10.0) * 10).round() / 10;
        l
          ..games += 1
          ..ratingSum += r
          ..yellows += yellows.where((x) => x == p.id).length
          ..reds += reds.contains(p.id) ? 1 : 0;
        ratings[p] = r;
      }
    }

    side(home, homeOn, hg, ag, homeScorers);
    side(away, awayOn, ag, hg, awayScorers);
    if (ratings.isEmpty) return;
    if (m.comp == 'A') {
      for (final e in ratings.entries) {
        _roundRatings.add((e.key.id, e.value));
      }
    }
    final userId = userTeamId;
    if (userId != null && m.involves(userId)) {
      final best = ratings.entries.reduce((a, b) => a.value >= b.value ? a : b);
      _addNews('⭐ Craque do jogo: ${best.key.name} (nota ${best.value.toStringAsFixed(1)}) — '
          '${home.shortName} $hg x $ag ${away.shortName}');
      _updateClubRecord(m, userId, home, away, hg, ag, userId == home.id ? homeOn : awayOn,
          userId == home.id ? homeScorers : awayScorers);
    }
  }

  void _updateClubRecord(Match m, String teamId, Team home, Team away, int hg, int ag, List<Player> on, List<String> scorers) {
    final r = clubRecords[teamId] ??= ClubRecord();
    final userHome = home.id == teamId;
    final diff = userHome ? hg - ag : ag - hg;
    if (diff > r.biggestDiff) {
      r
        ..biggestDiff = diff
        ..biggestWin = '${home.shortName} $hg x $ag ${away.shortName} ($seasonYear, ${compName(m.comp)})';
      if (diff >= 4) _addNews('📚 Recorde: maior vitória da era ${career.name}: ${r.biggestWin}.');
    }
    for (final p in on) {
      r.apps[p.name] = (r.apps[p.name] ?? 0) + 1;
    }
    for (final id in scorers) {
      final p = on.where((x) => x.id == id).firstOrNull;
      if (p != null) r.scorers[p.name] = (r.scorers[p.name] ?? 0) + 1;
    }
  }

  /// Seleção da rodada da Série A (4-4-2 pelas notas da data).
  void _computeBestOfRound(int day) {
    if (_roundRatings.isEmpty) return;
    final round = leagueRoundOfDay(day);
    final byPos = <String, List<(Player, double)>>{};
    for (final (id, r) in _roundRatings) {
      final team = teams.where((t) => t.division == 1 && t.findPlayer(id) != null).firstOrNull;
      final p = team?.findPlayer(id);
      if (p != null) (byPos[p.position] ??= []).add((p, r));
    }
    _roundRatings.clear();
    const need = {'GOL': 1, 'ZAG': 2, 'LAT': 2, 'VOL': 2, 'MEI': 2, 'ATA': 2};
    final lines = <String>['Seleção da ${round ?? '-'}ª rodada da Série A:'];
    need.forEach((pos, n) {
      final list = (byPos[pos] ?? [])..sort((a, b) => b.$2.compareTo(a.$2));
      for (final (p, r) in list.take(n)) {
        final t = teams.firstWhere((t) => t.findPlayer(p.id) != null);
        lines.add('$pos • ${p.name} (${t.shortName}) ${r.toStringAsFixed(1)}');
      }
    });
    bestOfRound = lines;
  }

  /// Artilheiros de uma competição.
  List<PlayerStatLine> topScorers(String comp, {int n = 15}) {
    final list = stats.values.where((l) => (l.goalsByComp[comp] ?? 0) > 0).toList()
      ..sort((a, b) => (b.goalsByComp[comp] ?? 0).compareTo(a.goalsByComp[comp] ?? 0));
    return list.take(n).toList();
  }

  /// Líderes de assistências entre jogadores de clubes brasileiros.
  List<PlayerStatLine> topAssists({int n = 10}) {
    final ids = {for (final t in teams) t.id};
    final list = stats.values.where((l) => ids.contains(l.teamId) && l.assists > 0).toList()
      ..sort((a, b) => b.assists.compareTo(a.assists));
    return list.take(n).toList();
  }

  /// Prêmios da temporada (Série A), guardados no histórico.
  Map<String, String> _seasonAwards() {
    final serieA = {for (final t in teams.where((t) => t.division == 1)) t.id};
    String club(String id) => _index[id]?.shortName ?? '';
    final awards = <String, String>{};
    final eligible = stats.values.where((l) => serieA.contains(l.teamId) && l.games >= 15).toList();
    if (eligible.isNotEmpty) {
      eligible.sort((a, b) => b.avgRating.compareTo(a.avgRating));
      final b = eligible.first;
      awards['🏅 Bola de Ouro'] = '${b.name} (${club(b.teamId)}, nota ${b.avgRating.toStringAsFixed(2)})';
      final young = eligible.where((l) => l.age <= 21).toList();
      if (young.isNotEmpty) {
        awards['🌟 Revelação'] = '${young.first.name} (${club(young.first.teamId)})';
      }
    }
    final scorers = topScorers('A', n: 1);
    if (scorers.isNotEmpty) {
      final s = scorers.first;
      awards['👟 Artilheiro da Série A'] = '${s.name} (${club(s.teamId)}, ${s.goalsByComp['A']} gols)';
    }
    final champ = standingsOf(1).first;
    awards['📋 Técnico do ano'] = '${champ.coach} (${champ.shortName})';
    for (final e in awards.entries) {
      _addNews('${e.key}: ${e.value}');
    }
    return awards;
  }
}
