part of 'engine.dart';

/// Nome de exibição de uma competição.
String compName(String comp) {
  switch (comp) {
    case 'A':
    case 'B':
    case 'C':
    case 'D':
      return 'Série $comp';
    case 'CDB':
      return 'Copa do Brasil';
    case 'LIB':
      return 'Libertadores';
    case 'SUL':
      return 'Sul-Americana';
    case 'SUP':
      return 'Supercopa do Brasil';
    case 'REC':
      return 'Recopa Sul-Americana';
    case 'UCL':
      return 'Liga dos Campeões';
    case 'MUN':
      return 'Copa Intercontinental';
  }
  if (comp.startsWith('EST:')) {
    final key = comp.substring(4);
    return kRegionalNames[key] ?? 'Estadual $key';
  }
  return kLeagueNames[comp] ?? comp;
}

String stageName(String stage) {
  switch (stage) {
    case 'L':
      return 'Rodada';
    case 'G':
      return 'Fase de grupos';
    case 'R32':
      return '1ª fase';
    case 'R16':
      return 'Oitavas';
    case 'QF':
      return 'Quartas';
    case 'SF':
      return 'Semifinal';
    case 'F':
      return 'Final';
  }
  return stage;
}

String divisionComp(int division) => 'ABCD'[(division - 1).clamp(0, 3)];

/// Descrição curta de um jogo: "Série A • 12ª rodada", "Copa do Brasil • Quartas (ida)".
String matchLabel(Match m) {
  final c = compName(m.comp);
  if (m.isLeague) return '$c • ${m.round}ª rodada';
  if (m.stage == 'G') {
    if (m.comp.startsWith('EST:')) return '$c • ${m.round}ª rodada';
    return '$c • Grupo ${m.group} (${m.round}º jogo)';
  }
  final leg = m.leg == 1 ? ' (ida)' : m.leg == 2 ? ' (volta)' : '';
  return '$c • ${stageName(m.stage)}$leg';
}

/// Ligas estrangeiras simuladas no calendário.
const List<String> kForeignLeagues = ['ENG', 'ESP', 'ITA', 'GER', 'FRA', 'POR', 'SAU', 'ARG'];

extension GameCompetitions on GameState {
  static const Map<int, String> _cdbAfter = {
    3: 'R32', 7: 'R16', 11: 'QF:1', 13: 'QF:2', 17: 'SF:1', 19: 'SF:2', 27: 'F:1', 29: 'F:2',
  };
  static const Map<int, String> _contAfter = {
    2: 'G:1', 4: 'G:2', 6: 'G:3', 8: 'G:4', 10: 'G:5', 12: 'G:6',
    15: 'R16:1', 16: 'R16:2', 21: 'QF:1', 22: 'QF:2', 24: 'SF:1', 25: 'SF:2', 31: 'F',
  };

  /// Série D no formato real: grupos regionais e mata-mata (rodadas da liga).
  static const Map<int, String> _serieDKnockout = {
    12: 'QF:1', 13: 'QF:2', 15: 'SF:1', 16: 'SF:2', 18: 'F:1', 19: 'F:2',
  };

  /// Datas fixas do início: Supercopa (1), Recopa (2 e 3) e estaduais (4 a 11).
  static const int _supDay = 1;
  static const int _recDay1 = 2;
  static const int _recDay2 = 3;
  static const int _estStart = 4;
  static const int _estDays = 8;

  /// Monta o calendário: Supercopa, Recopa, estaduais, ligas e copas intercaladas.
  void _buildSeason({required bool first}) {
    matches = [];
    stageDays = {};
    _crowned.clear();
    _byDay.clear();
    _standingsCache.clear();
    if (first || cupEntrants.isEmpty) cupEntrants = _firstSeasonEntrants();

    // 1) Supercopa do Brasil e Recopa Sul-Americana
    final sup = (cupEntrants['SUP'] ?? []).where(_index.containsKey).toList();
    if (sup.length == 2) {
      stageDays['SUP:F'] = _supDay;
      _addMatches([Match(round: 0, homeId: sup[0], awayId: sup[1], comp: 'SUP', day: _supDay, stage: 'F')]);
    }
    final rec = (cupEntrants['REC'] ?? []).where(_index.containsKey).toList();
    if (rec.length == 2) {
      stageDays['REC:F:1'] = _recDay1;
      stageDays['REC:F:2'] = _recDay2;
      _addMatches([
        Match(round: 0, homeId: rec[1], awayId: rec[0], comp: 'REC', day: _recDay1, stage: 'F', leg: 1),
        Match(round: 0, homeId: rec[0], awayId: rec[1], comp: 'REC', day: _recDay2, stage: 'F', leg: 2),
      ]);
    }

    // 2) Estaduais / copas regionais
    regionalGroups = _makeRegionalGroups();
    regionalGroups.forEach((key, ids) {
      final rounds = _roundRobin(ids, double: false);
      for (int r = 0; r < rounds.length; r++) {
        _addMatches([
          for (final (h, a) in rounds[r])
            Match(round: r + 1, homeId: h, awayId: a, comp: 'EST:$key', day: _estStart + r, stage: 'G'),
        ]);
      }
      stageDays['EST:$key:F'] = _estStart + _estDays - 1;
    });
    stageDays['WIN:1:end'] = _estStart + _estDays + 2;

    // 3) Ligas (Brasil A–C, Série D em grupos, ligas estrangeiras) com copas no meio
    final schedules = <String, List<List<(String, String)>>>{};
    for (int div = 1; div <= 3; div++) {
      final ids = teams.where((t) => t.division == div).map((t) => t.id).toList()..shuffle(_rng);
      schedules[divisionComp(div)] = _roundRobin(ids, double: true);
    }
    for (final lg in kForeignLeagues) {
      final ids = foreignTeams.where((t) => t.league == lg).map((t) => t.id).toList()..shuffle(_rng);
      if (ids.length >= 2) schedules[lg] = _roundRobin(ids, double: true);
    }
    final dGroups = _serieDGroups();
    final dSchedules = {for (final e in dGroups.entries) e.key: _roundRobin(e.value, double: true)};

    int day = _estStart + _estDays - 1;
    for (int r = 1; r <= GameState.leagueRounds; r++) {
      day++;
      schedules.forEach((comp, rounds) {
        if (r > rounds.length) return;
        _addMatches([
          for (final (h, a) in rounds[r - 1]) Match(round: r, homeId: h, awayId: a, comp: comp, day: day),
        ]);
      });
      dSchedules.forEach((g, rounds) {
        if (r > rounds.length) return;
        _addMatches([
          for (final (h, a) in rounds[r - 1])
            Match(round: r, homeId: h, awayId: a, comp: 'D', day: day, stage: 'G', group: g),
        ]);
      });
      final dko = _serieDKnockout[r];
      if (dko != null) stageDays['D:$dko'] = day;
      if (r == 19) stageDays['WIN:2:start'] = day;
      if (r == 24) stageDays['WIN:2:end'] = day;
      final cdb = _cdbAfter[r];
      if (cdb != null) {
        day++;
        stageDays['CDB:$cdb'] = day;
      }
      final cont = _contAfter[r];
      if (cont != null) {
        day++;
        stageDays['LIB:$cont'] = day;
        stageDays['SUL:$cont'] = day;
        if (!cont.startsWith('G')) stageDays['UCL:$cont'] = day;
      }
    }
    // 4) Copa Intercontinental: semifinal e final depois da última rodada
    stageDays['MUN:SF'] = day + 1;
    stageDays['MUN:F'] = day + 2;
    totalDays = day + 2;

    // 5) Jogos já definidos das copas
    _createCdbFirstRound();
    _createContinentalGroups('LIB', first ? kLibGroups2026 : null);
    _createContinentalGroups('SUL', first ? kSulGroups2026 : null);
    _createUclFirstRound();
  }

  /// Turno (e returno se [double]) pelo método do círculo. Folga quando ímpar.
  List<List<(String, String)>> _roundRobin(List<String> input, {required bool double}) {
    final ids = List<String>.from(input);
    if (ids.length.isOdd) ids.add('');
    final n = ids.length;
    if (n < 2) return [];
    final result = <List<(String, String)>>[];
    var rotating = ids.sublist(1);
    for (int round = 0; round < n - 1; round++) {
      final roundIds = [ids[0], ...rotating];
      final pairs = <(String, String)>[];
      for (int i = 0; i < n ~/ 2; i++) {
        var home = roundIds[i];
        var away = roundIds[n - 1 - i];
        if (i.isOdd || (i == 0 && round.isOdd)) {
          final tmp = home;
          home = away;
          away = tmp;
        }
        if (home.isNotEmpty && away.isNotEmpty) pairs.add((home, away));
      }
      result.add(pairs);
      rotating = [rotating.last, ...rotating.sublist(0, rotating.length - 1)];
    }
    if (double) {
      final second = [for (final r in result) [for (final (h, a) in r) (a, h)]];
      result.addAll(second);
    }
    return result;
  }

  /// Estados com 4+ clubes têm estadual próprio (até 8 clubes);
  /// os demais se juntam em copas regionais.
  Map<String, List<String>> _makeRegionalGroups() {
    int order(Team a, Team b) =>
        a.division != b.division ? a.division.compareTo(b.division) : b.stars.compareTo(a.stars);
    final byState = <String, List<Team>>{};
    for (final t in teams) {
      (byState[t.state] ??= []).add(t);
    }
    final result = <String, List<String>>{};
    final leftovers = <String, List<Team>>{};
    byState.forEach((state, list) {
      list.sort(order);
      if (list.length >= 4) {
        result[state] = list.take(8).map((t) => t.id).toList();
      } else {
        (leftovers[kStateRegion[state] ?? 'R-SE'] ??= []).addAll(list);
      }
    });
    leftovers.forEach((region, list) {
      list.sort(order);
      if (list.length >= 3) result[region] = list.take(8).map((t) => t.id).toList();
    });
    return result;
  }

  /// Série D: 4 grupos de 5 clubes agrupados por região.
  Map<String, List<String>> _serieDGroups() {
    final d = teams.where((t) => t.division == 4).toList()
      ..sort((a, b) => (kStateRegion[a.state] ?? 'R-SE').compareTo(kStateRegion[b.state] ?? 'R-SE'));
    final groups = <String, List<String>>{};
    const letters = 'ABCD';
    for (int i = 0; i < d.length; i++) {
      (groups[letters[(i ~/ 5).clamp(0, 3)]] ??= []).add(d[i].id);
    }
    return groups;
  }

  /// Posição de um clube da Série D: campeão 1, vice 2, semifinalistas 3–4...
  int serieDRank(String teamId) {
    String? winner(String stage, int slot) => tieWinner('D', stage, slot);
    final f = stageMatches('D', 'F');
    if (f.isNotEmpty && f.every((m) => m.isPlayed)) {
      final w = winner('F', 0);
      if (w == teamId) return 1;
      if (f.first.involves(teamId)) return 2;
    }
    if (stageMatches('D', 'SF').any((m) => m.involves(teamId))) return 3;
    if (stageMatches('D', 'QF').any((m) => m.involves(teamId))) return 5;
    for (final g in groupsOf('D')) {
      final table = groupTable('D', g);
      final i = table.indexWhere((r) => r.team.id == teamId);
      if (i >= 0) return 9 + i * 4;
    }
    return 20;
  }

  Map<String, List<String>> _firstSeasonEntrants() {
    List<String> idsOf(Map<String, List<String>> groups) => [
      for (final g in groups.values)
        for (final code in g)
          if (_index.containsKey(code.toLowerCase()) && !_index[code.toLowerCase()]!.isForeign)
            code.toLowerCase(),
    ];
    final cdb = <String>[
      ...teams.where((t) => t.division == 1).map((t) => t.id),
      ...kClubsB.take(8).map((c) => c.shortName.toLowerCase()),
      ...kClubsC.take(4).map((c) => c.shortName.toLowerCase()),
    ];
    // 2026 real: Supercopa Flamengo x Corinthians; Recopa Flamengo x Lanús
    return {
      'LIB': idsOf(kLibGroups2026),
      'SUL': idsOf(kSulGroups2026),
      'CDB': cdb,
      'SUP': ['fla', 'cor'],
      'REC': ['fla', 'lan'],
      'UCL': _uclByStrength(),
    };
  }

  /// 16 vagas: 4 Inglaterra, 4 Espanha, 3 Itália, 3 Alemanha, 1 França, 1 Portugal.
  static const Map<String, int> _uclSlots = {'ENG': 4, 'ESP': 4, 'ITA': 3, 'GER': 3, 'FRA': 1, 'POR': 1};

  List<String> _uclByStrength() => [
    for (final e in _uclSlots.entries)
      ...(foreignTeams.where((t) => t.league == e.key).toList()
            ..sort((a, b) => b.baseOverall.compareTo(a.baseOverall)))
          .take(e.value)
          .map((t) => t.id),
  ];

  List<String> _uclByTable() => [
    for (final e in _uclSlots.entries) ...standingsOfLeague(e.key).take(e.value).map((t) => t.id),
  ];

  void _createCdbFirstRound() {
    final ids = (cupEntrants['CDB'] ?? []).where(_index.containsKey).toList()..shuffle(_rng);
    final day = stageDays['CDB:R32']!;
    final created = <Match>[];
    for (int i = 0; i + 1 < ids.length && created.length < 16; i += 2) {
      // Clube de divisão inferior manda o jogo
      var h = ids[i], a = ids[i + 1];
      if (teamById(h).division < teamById(a).division) {
        final tmp = h;
        h = a;
        a = tmp;
      }
      created.add(Match(round: created.length, homeId: h, awayId: a, comp: 'CDB', day: day, stage: 'R32'));
    }
    _addMatches(created);
  }

  /// Liga dos Campeões: mata-mata de 16 nas mesmas datas da Libertadores.
  void _createUclFirstRound() {
    final ids = (cupEntrants['UCL'] ?? []).where(_index.containsKey).toList()..shuffle(_rng);
    if (ids.length < 16 || stageDays['UCL:R16:1'] == null) return;
    final created = <Match>[];
    for (int i = 0; i < 8; i++) {
      final a = ids[i * 2], b = ids[i * 2 + 1];
      created
        ..add(Match(round: i, homeId: b, awayId: a, comp: 'UCL', day: stageDays['UCL:R16:1']!, stage: 'R16', leg: 1))
        ..add(Match(round: i, homeId: a, awayId: b, comp: 'UCL', day: stageDays['UCL:R16:2']!, stage: 'R16', leg: 2));
    }
    _addMatches(created);
  }

  void _createContinentalGroups(String comp, Map<String, List<String>>? fixed) {
    final foreign = (comp == 'LIB' ? kForeignLib : kForeignSul).map((c) => c.shortName.toLowerCase());
    Map<String, List<String>> groups;
    if (fixed != null) {
      groups = fixed.map((g, codes) => MapEntry(g, codes.map((c) => c.toLowerCase()).toList()));
    } else {
      final all = [...(cupEntrants[comp] ?? []), ...foreign].where(_index.containsKey).toSet().toList()
        ..shuffle(_rng)
        ..sort((a, b) => teamById(b).stars.compareTo(teamById(a).stars));
      groups = {for (final g in 'ABCDEFGH'.split('')) g: <String>[]};
      final letters = groups.keys.toList();
      for (int i = 0; i < all.length && i < 32; i++) {
        final pot = i ~/ 8;
        final idx = pot.isEven ? i % 8 : 7 - i % 8;
        groups[letters[idx]]!.add(all[i]);
      }
    }
    // Jogos de grupo: 6 rodadas, cada time 3 em casa e 3 fora
    const pairs = [
      [(0, 1), (2, 3)], [(1, 2), (3, 0)], [(0, 2), (1, 3)],
      [(1, 0), (3, 2)], [(2, 1), (0, 3)], [(2, 0), (3, 1)],
    ];
    groups.forEach((g, ids) {
      if (ids.length < 4) return;
      for (int r = 0; r < 6; r++) {
        final day = stageDays['$comp:G:${r + 1}']!;
        _addMatches([
          for (final (h, a) in pairs[r])
            Match(round: r + 1, homeId: ids[h], awayId: ids[a], comp: comp, day: day, stage: 'G', group: g),
        ]);
      }
      for (final id in ids) {
        final t = teamById(id);
        if (!t.isForeign) _credit(t, cupPrize(comp, 'G'), 'Premiação', '${compName(comp)}: fase de grupos');
      }
    });
  }

  /// Tabela de um grupo (estaduais, Série D e copas continentais).
  List<StandingRow> groupTable(String comp, String group) {
    final rows = <String, StandingRow>{};
    for (final m in matches) {
      if (m.comp != comp || m.stage != 'G' || m.group != group) continue;
      final h = rows[m.homeId] ??= StandingRow(teamById(m.homeId));
      final a = rows[m.awayId] ??= StandingRow(teamById(m.awayId));
      if (!m.isPlayed) continue;
      final hg = m.homeGoals!, ag = m.awayGoals!;
      h
        ..played += 1
        ..goalsFor += hg
        ..goalsAgainst += ag;
      a
        ..played += 1
        ..goalsFor += ag
        ..goalsAgainst += hg;
      if (hg > ag) {
        h.wins++;
        a.losses++;
      } else if (hg < ag) {
        a.wins++;
        h.losses++;
      } else {
        h.draws++;
        a.draws++;
      }
    }
    final list = rows.values.toList()
      ..sort((a, b) {
        if (b.points != a.points) return b.points.compareTo(a.points);
        if (b.goalDifference != a.goalDifference) return b.goalDifference.compareTo(a.goalDifference);
        if (b.goalsFor != a.goalsFor) return b.goalsFor.compareTo(a.goalsFor);
        return b.team.stars.compareTo(a.team.stars);
      });
    return list;
  }

  /// Grupos existentes de uma competição.
  List<String> groupsOf(String comp) =>
      {for (final m in matches) if (m.comp == comp && m.stage == 'G' && m.group.isNotEmpty) m.group}.toList()..sort();

  List<Match> stageMatches(String comp, String stage) =>
      matches.where((m) => m.comp == comp && m.stage == stage).toList()
        ..sort((a, b) => a.round != b.round ? a.round.compareTo(b.round) : a.leg.compareTo(b.leg));

  /// Placar agregado antes desta partida (para jogos de volta).
  (int, int)? aggregateBefore(Match m) {
    if (m.leg != 2) return null;
    final first = matches.where((x) =>
        x.comp == m.comp && x.stage == m.stage && x.round == m.round && x.leg == 1).firstOrNull;
    if (first == null || !first.isPlayed) return null;
    // Na volta os mandos se invertem
    return (first.awayGoals!, first.homeGoals!);
  }

  /// Se o jogo terminar com [hg] x [ag], vai para os pênaltis?
  bool needsPenalties(Match m, int hg, int ag) {
    if (!m.isKnockout || m.leg == 1) return false;
    final agg = aggregateBefore(m);
    final h = hg + (agg?.$1 ?? 0);
    final a = ag + (agg?.$2 ?? 0);
    return h == a;
  }

  /// Vencedor de um confronto eliminatório (jogo único ou ida e volta).
  String? tieWinner(String comp, String stage, int slot) {
    final legs = matches.where((m) => m.comp == comp && m.stage == stage && m.round == slot).toList()
      ..sort((a, b) => a.leg.compareTo(b.leg));
    if (legs.isEmpty || legs.any((m) => !m.isPlayed)) return null;
    final last = legs.last;
    int h = last.homeGoals!, a = last.awayGoals!;
    if (legs.length == 2) {
      h += legs.first.awayGoals!;
      a += legs.first.homeGoals!;
    }
    if (h != a) return h > a ? last.homeId : last.awayId;
    return (last.homePens ?? 0) >= (last.awayPens ?? 0) ? last.homeId : last.awayId;
  }

  /// Cria os jogos de mata-mata cuja data chegou.
  void _progressCompetitions(int day) {
    stageDays.forEach((key, d) {
      if (d != day) return;
      final parts = key.split(':');
      if (parts[0] == 'WIN' || parts[0] == 'SUP' || parts[0] == 'REC') return;
      if (parts[0] == 'EST') {
        _createEstadualFinal(parts[1]);
        return;
      }
      if (parts[0] == 'MUN') {
        _createIntercontinental(parts[1]);
        return;
      }
      final comp = parts[0];
      final stage = parts[1];
      if (stage == 'G' || stage == 'R32') return;
      if (parts.length == 3 && parts[2] == '2') return; // volta criada junto com a ida
      if (matches.any((m) => m.comp == comp && m.stage == stage)) return;
      _createKnockout(comp, stage);
    });
  }

  void _createEstadualFinal(String key) {
    final comp = 'EST:$key';
    if (matches.any((m) => m.comp == comp && m.stage == 'F')) return;
    final table = groupTable(comp, '');
    if (table.length < 2) return;
    _addMatches([
      Match(round: 0, homeId: table[0].team.id, awayId: table[1].team.id, comp: comp,
          day: stageDays['$comp:F']!, stage: 'F'),
    ]);
  }

  /// Copa Intercontinental: campeão saudita x campeão da Libertadores; o vencedor
  /// enfrenta o campeão da Liga dos Campeões na final.
  void _createIntercontinental(String stage) {
    if (matches.any((m) => m.comp == 'MUN' && m.stage == stage)) return;
    final day = stageDays['MUN:$stage']!;
    if (stage == 'SF') {
      final lib = tieWinner('LIB', 'F', 0);
      final sau = standingsOfLeague('SAU').firstOrNull?.id;
      if (lib == null || sau == null) return;
      _addMatches([Match(round: 0, homeId: lib, awayId: sau, comp: 'MUN', day: day, stage: 'SF')]);
    } else {
      final semi = tieWinner('MUN', 'SF', 0);
      final ucl = tieWinner('UCL', 'F', 0);
      if (semi == null || ucl == null) return;
      _addMatches([Match(round: 0, homeId: ucl, awayId: semi, comp: 'MUN', day: day, stage: 'F')]);
    }
  }

  void _createKnockout(String comp, String stage) {
    const order = ['R32', 'R16', 'QF', 'SF', 'F'];
    final prev = order[order.indexOf(stage) - 1];
    final pairs = <(String, String)>[];
    final prevMatches = matches.where((m) => m.comp == comp && m.stage == prev).toList();
    if (prevMatches.isEmpty) {
      // Primeira fase eliminatória depois dos grupos
      pairs.addAll(_groupStageQualifiers(comp));
    } else {
      final slots = prevMatches.map((m) => m.round).toSet().toList()..sort();
      final winners = [for (final s in slots) tieWinner(comp, prev, s)];
      for (int i = 0; i + 1 < winners.length; i += 2) {
        final a = winners[i], b = winners[i + 1];
        if (a != null && b != null) pairs.add((a, b));
      }
    }
    final twoLegs = switch (comp) {
      'CDB' => stage == 'QF' || stage == 'SF' || stage == 'F',
      'D' => true,
      _ => stage != 'F',
    };
    final created = <Match>[];
    for (int i = 0; i < pairs.length; i++) {
      final (a, b) = pairs[i];
      if (twoLegs) {
        // Quem fez melhor campanha (a) decide em casa
        created.add(Match(round: i, homeId: b, awayId: a, comp: comp,
            day: stageDays['$comp:$stage:1']!, stage: stage, leg: 1));
        created.add(Match(round: i, homeId: a, awayId: b, comp: comp,
            day: stageDays['$comp:$stage:2']!, stage: stage, leg: 2));
      } else {
        final day = stageDays['$comp:$stage'] ?? stageDays['$comp:$stage:1']!;
        created.add(Match(round: i, homeId: a, awayId: b, comp: comp, day: day, stage: stage));
      }
      for (final id in [a, b]) {
        final t = teamById(id);
        if (!t.isForeign && comp != 'D') {
          _credit(t, cupPrize(comp, stage), 'Premiação', '${compName(comp)}: classificado (${stageName(stage)})');
        }
      }
      if (a == userTeamId || b == userTeamId) {
        final opp = teamById(a == userTeamId ? b : a);
        _addNews('🏆 ${compName(comp)}: ${stageName(stage)} contra o ${opp.name}!');
      }
    }
    _addMatches(created);
  }

  /// Primeiro mata-mata após os grupos: 1º de um grupo x 2º do grupo vizinho.
  List<(String, String)> _groupStageQualifiers(String comp) {
    final groups = groupsOf(comp);
    final result = <(String, String)>[];
    for (int i = 0; i + 1 < groups.length; i += 2) {
      final g1 = groupTable(comp, groups[i]);
      final g2 = groupTable(comp, groups[i + 1]);
      if (g1.length < 2 || g2.length < 2) continue;
      result.add((g1[0].team.id, g2[1].team.id));
      result.add((g2[0].team.id, g1[1].team.id));
    }
    return result;
  }

  /// Entrega troféus das finais disputadas na data [day].
  void _crownChampions(int day) {
    for (final m in matchesOfDay(day)) {
      if (m.stage != 'F' || m.leg == 1 || _crowned.contains(m.comp)) continue;
      final winner = tieWinner(m.comp, 'F', m.round);
      if (winner == null) continue;
      _crowned.add(m.comp);
      _awardTitle(m.comp, teamById(winner));
    }
  }

  void _awardTitle(String comp, Team t) {
    final name = compName(comp);
    t.trophies.add('$seasonYear $name');
    if (!t.isForeign) {
      final prizeComp = const ['CDB', 'LIB', 'SUL'].contains(comp) ? comp : 'EST';
      _credit(t, cupPrize(prizeComp, 'F', champion: true), 'Premiação', 'Título: $name');
    }
    final big = !t.isForeign || const ['UCL', 'MUN', 'LIB', 'SUL', 'REC'].contains(comp);
    if (big) _addNews('🏆 ${t.name} é campeão: $name $seasonYear!');
    if (t.id == userTeamId) _userWonTitle(name, comp);
  }

  void _userWonTitle(String name, String comp) {
    final bonus = switch (comp) {
      'MUN' => 15,
      'LIB' => 12,
      'CDB' => 8,
      'SUL' => 6,
      'A' => 15,
      _ => comp.startsWith('EST:') ? 2 : 5,
    };
    career.trophies.add('$seasonYear $name');
    switch (mode) {
      case GameMode.tecnico:
        career.reputation = (career.reputation + bonus).clamp(0, 100).toInt();
        if (comp == 'A') career.titles++;
      case GameMode.presidente:
        president!.popularity = (president!.popularity + bonus).clamp(0, 100).toInt();
      case GameMode.jogador:
        break;
    }
  }

  /// Fim da temporada: prêmios, acesso/rebaixamento, vagas nas copas e histórico.
  void _closeSeason() {
    final titles = <String, String>{};
    final nextDiv = <String, int>{};
    _lastPositions = {};
    for (int div = 1; div <= 3; div++) {
      final table = standingsOf(div);
      if (table.isEmpty) continue;
      for (int i = 0; i < table.length; i++) {
        final t = table[i];
        final pos = i + 1;
        _lastPositions[t.id] = pos;
        _credit(t, positionPrize(pos, division: div), 'Premiação', 'Premiação: $posº lugar na ${compName(divisionComp(div))}');
        if (div > 1 && pos <= 4) {
          _credit(t, promotionBonus(div), 'Premiação', 'Bônus de acesso');
          nextDiv[t.id] = div - 1;
        }
        if (pos > table.length - 4) nextDiv[t.id] = div + 1;
      }
      final champ = table.first;
      final comp = divisionComp(div);
      titles[compName(comp)] = champ.name;
      _awardTitle(comp, champ);
    }
    // Série D: os semifinalistas sobem
    for (final t in teams.where((t) => t.division == 4)) {
      final rank = serieDRank(t.id);
      _lastPositions[t.id] = rank;
      if (rank <= 4) {
        _credit(t, promotionBonus(4), 'Premiação', 'Bônus de acesso');
        nextDiv[t.id] = 3;
      }
    }
    // Ligas estrangeiras
    for (final lg in kForeignLeagues) {
      final table = standingsOfLeague(lg);
      if (table.isEmpty) continue;
      titles[compName(lg)] = table.first.name;
      table.first.trophies.add('$seasonYear ${compName(lg)}');
    }
    for (final m in matches.where((m) => m.stage == 'F' && m.leg != 1)) {
      final w = tieWinner(m.comp, 'F', m.round);
      if (w != null) titles[compName(m.comp)] = teamById(w).name;
      if (w != null && !_crowned.contains(m.comp)) {
        _crowned.add(m.comp);
        _awardTitle(m.comp, teamById(w));
      }
    }
    pendingDivisions = nextDiv;
    for (final e in nextDiv.entries) {
      final t = teamById(e.key);
      final up = e.value < t.division;
      if (t.id == userTeamId) {
        _addNews(up
            ? '🎉 ACESSO! O ${t.name} vai jogar a ${compName(divisionComp(e.value))}!'
            : '💔 Rebaixado: o ${t.name} vai para a ${compName(divisionComp(e.value))}.');
        if (up) _unlock('acesso');
      }
    }

    // Vagas para a próxima temporada
    final a = standingsOf(1).map((t) => t.id).toList();
    final cdbWinner = tieWinner('CDB', 'F', 0);
    final lib = <String>[...a.take(5)];
    if (cdbWinner != null && !lib.contains(cdbWinner) && teamById(cdbWinner).division == 1) {
      lib.add(cdbWinner);
    } else {
      lib.add(a[5]);
    }
    final sul = a.where((id) => !lib.contains(id)).take(7).toList();
    final cdb = <String>[
      ...a,
      ...standingsOf(2).take(8).map((t) => t.id),
      ...standingsOf(3).take(4).map((t) => t.id),
    ];
    for (final id in a.take(4)) {
      _credit(teamById(id), kLibertadoresBonus, 'Premiação', 'Vaga na Libertadores');
    }
    final sup = <String>[a.first, if (cdbWinner != null && cdbWinner != a.first) cdbWinner else a[1]];
    final libW = tieWinner('LIB', 'F', 0);
    final sulW = tieWinner('SUL', 'F', 0);
    cupEntrants = {
      'LIB': lib,
      'SUL': sul,
      'CDB': cdb,
      'SUP': sup,
      'REC': [?libW, ?sulW],
      'UCL': _uclByTable(),
    };

    titles.addAll(_seasonAwards());

    final user = userTeam;
    final upos = user == null ? null : positionOf(user.id);
    final met = (mode == GameMode.tecnico && career.employed && upos != null)
        ? upos <= career.goal.maxPosition
        : null;
    final tableA = standingsOf(1);
    history.add(SeasonRecord(
      season: seasonYear,
      champion: tableA.first.name,
      runnerUp: tableA[1].name,
      relegated: tableA.sublist(16).map((t) => t.name).toList(),
      userTeam: user?.name,
      userPosition: upos,
      userPoints: user?.points,
      goal: met == null || user == null ? null : career.goal.labelFor(user.division),
      goalMet: met,
      titles: titles,
    ));

    switch (mode) {
      case GameMode.tecnico:
        _forEachHuman(() {
          final u = career.employed ? userTeam : null;
          final pos = u == null ? null : positionOf(u.id);
          final ok = u == null || pos == null ? null : pos <= career.goal.maxPosition;
          _careerSeasonClose(pos, ok);
          _nationalTournament();
          _offerNationalTeam();
        });
      case GameMode.presidente:
        _presidentSeasonClose(upos);
      case GameMode.jogador:
        _playerSeasonClose();
    }
    _checkAchievements();
  }
}
