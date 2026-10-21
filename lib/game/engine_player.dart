part of 'engine.dart';

const String kUserPlayerId = 'user_player';

/// Clubes que oferecem o primeiro contrato ao atleta criado (Séries C e D).
List<ClubInfo> startingClubOptions({int count = 4}) {
  final pool = [...kClubsC, ...kClubsD]..shuffle(Random());
  return pool.take(count).toList();
}

/// Overall inicial do atleta conforme idade e estilo.
int startingOverall(int age, String style) =>
    56 + (age - 16) * 2 + (style == 'Craque da base' ? 3 : 0);

/// Fase 10C — Modo Jogador.
extension GamePlayer on GameState {
  void startPlayerCareer({
    required String name,
    required String nationality,
    required String position,
    required int age,
    required String style,
    required String teamId,
  }) {
    mode = GameMode.jogador;
    _newWorld();
    userTeamId = teamId;
    final t = userTeam!;
    final n = name.trim().isEmpty ? 'Jogador' : name.trim();
    final p = Player(
      id: kUserPlayerId,
      name: n,
      position: position,
      age: age,
      overall: startingOverall(age, style),
      contractYears: 3,
      morale: 80,
    );
    if (style == 'Físico') p.energy = 100;
    t.squad.add(p);
    playerCareer = PlayerCareer(playerId: p.id, nationality: nationality);
    playerCareer!.seasons.add(PlayerSeasonStats(season: seasonYear, team: t.name));
    career = CoachCareer(name: n, reputation: 20);
    career.log.add('$seasonYear: assinou o primeiro contrato profissional com o ${t.name}, aos $age anos.');
    t.startingIds = autoLineup(t);
    _addNews('✍️ $n ($position, $age anos) assina o primeiro contrato com o ${t.name}!');
    _changed();
  }

  Player? get userPlayer {
    final id = playerCareer?.playerId;
    if (id == null) return null;
    return userTeam?.findPlayer(id);
  }

  PlayerSeasonStats _currentStats() {
    final pc = playerCareer!;
    final teamName = userTeam?.name ?? '-';
    final last = pc.seasons.isEmpty ? null : pc.seasons.last;
    if (last != null && last.season == seasonYear && last.team == teamName) return last;
    final s = PlayerSeasonStats(season: seasonYear, team: teamName);
    pc.seasons.add(s);
    return s;
  }

  PlayerSeasonStats? get currentPlayerStats {
    final pc = playerCareer;
    if (pc == null) return null;
    final list = pc.seasons.where((s) => s.season == seasonYear).toList();
    if (list.isEmpty) return null;
    final total = PlayerSeasonStats(season: seasonYear, team: list.last.team);
    for (final s in list) {
      total
        ..games += s.games
        ..goals += s.goals
        ..assists += s.assists
        ..ratingSum += s.ratingSum;
    }
    return total;
  }

  double _attackWeight(String pos) => const {
    'ATA': 3.0, 'MEI': 2.0, 'VOL': 0.8, 'LAT': 0.7, 'ZAG': 0.4, 'GOL': 0.0,
  }[pos] ?? 1.0;

  double _assistWeight(String pos) => const {
    'ATA': 1.5, 'MEI': 3.0, 'VOL': 1.2, 'LAT': 1.5, 'ZAG': 0.3, 'GOL': 0.05,
  }[pos] ?? 1.0;

  /// Nota e números do atleta do usuário em uma partida.
  void _playerMatchReport(Match m, int hg, int ag) {
    final pc = playerCareer;
    final p = userPlayer;
    final t = userTeam;
    if (pc == null || p == null || t == null || pc.retired || !m.involves(t.id)) return;
    final starter = t.startingIds.contains(p.id);
    final cameOn = !starter && !p.injured && _rng.nextDouble() < 0.35;
    if (!starter && !cameOn) return;
    final home = m.homeId == t.id;
    final gf = home ? hg : ag;
    final ga = home ? ag : hg;
    final onPitch = t.startingPlayers;
    double sumA = 0, sumS = 0;
    for (final x in onPitch) {
      sumA += _attackWeight(x.position) * x.overall;
      sumS += _assistWeight(x.position) * x.overall;
    }
    if (!starter) {
      sumA += _attackWeight(p.position) * p.overall;
      sumS += _assistWeight(p.position) * p.overall;
    }
    final minutesFactor = starter ? 1.0 : 0.35;
    final shareA = sumA == 0 ? 0 : _attackWeight(p.position) * p.overall / sumA * minutesFactor;
    final shareS = sumS == 0 ? 0 : _assistWeight(p.position) * p.overall / sumS * minutesFactor;
    int goals = 0, assists = 0;
    for (int i = 0; i < gf; i++) {
      if (_rng.nextDouble() < shareA) {
        goals++;
      } else if (_rng.nextDouble() < shareS * 0.7) {
        assists++;
      }
    }
    double rating = 6.0 + goals * 1.0 + assists * 0.6;
    rating += gf > ga ? 0.4 : (gf < ga ? -0.4 : 0);
    rating += (p.overall - t.averageOverall) * 0.05;
    rating += (_rng.nextDouble() + _rng.nextDouble() - 1) * 0.9;
    if (p.position == 'GOL') rating += ga == 0 ? 0.8 : -0.3 * ga;
    if (p.position == 'ZAG' || p.position == 'LAT') rating += ga == 0 ? 0.4 : -0.15 * ga;
    if (!starter) rating = 6.0 + (rating - 6.0) * 0.6;
    rating = ((rating.clamp(3.0, 10.0)) * 10).round() / 10;
    final s = _currentStats();
    s
      ..games += 1
      ..goals += goals
      ..assists += assists
      ..ratingSum += rating;
    pc.lastRating = rating;
    if (rating >= 7.5) p.gainXp(8);
    if (rating >= 8.5) p.morale = (p.morale + 4).clamp(0, 100).toInt();
    final opp = teamById(home ? m.awayId : m.homeId);
    final extra = [
      if (goals > 0) '$goals gol${goals > 1 ? 's' : ''}',
      if (assists > 0) '$assists assist.',
      if (!starter) 'saiu do banco',
    ].join(', ');
    _addNews('⭐ Nota ${rating.toStringAsFixed(1)}${extra.isEmpty ? '' : ' ($extra)'} — ${t.shortName} $gf x $ga ${opp.shortName} (${compName(m.comp)})');
  }

  void _playerPayday() {
    final p = userPlayer;
    if (p == null || playerCareer!.retired) return;
    career.earnings += p.wage;
  }

  void _playerDaily(int finishedDay) {
    final pc = playerCareer;
    final p = userPlayer;
    if (pc == null || p == null || pc.retired) return;
    // Data FIFA: convocação para a Seleção Brasileira
    if (finishedDay % 20 == 0) {
      final s = currentPlayerStats;
      final avg = s == null || s.games < 5 ? 0.0 : s.avgRating;
      final eligible = pc.nationality == 'Brasil' && p.age >= 18;
      if (eligible && (p.overall >= 84 || (p.overall >= 77 && avg >= 7.0))) {
        pc.caps += 2;
        p.morale = (p.morale + 10).clamp(0, 100).toInt();
        p.gainXp(15);
        career.log.add('$seasonYear: convocado para a Seleção Brasileira (${pc.caps} jogos).');
        _addNews('🇧🇷 CONVOCADO! ${p.name} está na lista da Seleção Brasileira para a Data FIFA.');
      } else if (eligible && p.overall >= 74 && avg >= 6.8) {
        _addNews('📋 ${p.name} foi observado pela comissão da Seleção, mas ficou fora da lista.');
      }
    }
    if (pc.transferRequested && career.offers.length < 3 && _rng.nextDouble() < 0.25) {
      _generatePlayerOffers(1);
    }
  }

  void _generatePlayerOffers(int count, {bool bigger = true}) {
    final p = userPlayer;
    final t = userTeam;
    if (p == null || t == null) return;
    final cands = teams
        .where((x) =>
            x.id != t.id &&
            !career.offers.any((o) => o.teamId == x.id) &&
            p.overall >= x.averageOverall - 4 &&
            (!bigger || x.division < t.division || (x.division == t.division && x.stars >= t.stars)))
        .toList()
      ..shuffle(_rng);
    for (final x in cands.take(count)) {
      final wage = roundTo(max(p.wage * 1.2, Player.fairWage(p.overall, p.age) * 1.1), 1000);
      career.offers.add(JobOffer(teamId: x.id, salary: wage, goal: BoardGoal.naoCair));
      _addNews('📨 O ${x.name} (${compName(divisionComp(x.division))}) quer contratar ${p.name}: ${formatMoney(wage)}/mês.');
    }
  }

  TransferResult requestTransfer() {
    final pc = playerCareer;
    final p = userPlayer;
    if (pc == null || p == null) return const TransferResult(false, 'Sem carreira ativa.');
    if (pc.transferRequested) {
      return const TransferResult(false, 'Seu empresário já está procurando clubes.');
    }
    pc.transferRequested = true;
    p.morale = (p.morale - 5).clamp(0, 100).toInt();
    final s = currentPlayerStats;
    final good = (s?.avgRating ?? 0) >= 6.5 || p.overall >= (userTeam?.averageOverall ?? 70);
    if (good) _generatePlayerOffers(1);
    _changed();
    return TransferResult(true, good
        ? 'Pedido feito! Propostas aparecem na sua Carreira.'
        : 'Pedido feito, mas com notas baixas será difícil aparecer proposta.');
  }

  TransferResult askRaise() {
    final pc = playerCareer;
    final p = userPlayer;
    if (pc == null || p == null) return const TransferResult(false, 'Sem carreira ativa.');
    if (pc.raiseSeason == seasonYear) {
      return const TransferResult(false, 'Você já negociou salário nesta temporada.');
    }
    pc.raiseSeason = seasonYear;
    final s = currentPlayerStats;
    final avg = s?.avgRating ?? 0;
    final fair = Player.fairWage(p.overall, p.age);
    if (avg >= 7.0 || pc.caps > 0 || fair > p.wage * 1.2) {
      final old = p.wage;
      p.wage = roundTo(max(p.wage * 1.2, fair.toDouble()), 1000);
      p.contractYears = max(p.contractYears, 3);
      _addNews('💰 ${p.name} renova com aumento: ${formatMoney(old)} → ${formatMoney(p.wage)}/mês.');
      _changed();
      return TransferResult(true, 'Aumento aprovado: ${formatMoney(p.wage)}/mês.');
    }
    if (_rng.nextDouble() < 0.3) {
      p.wage = roundTo(p.wage * 1.1, 1000);
      _changed();
      return TransferResult(true, 'A diretoria deu 10%: ${formatMoney(p.wage)}/mês.');
    }
    p.morale = (p.morale - 10).clamp(0, 100).toInt();
    _changed();
    return const TransferResult(false, 'Pedido negado. Melhore suas notas para negociar.');
  }

  TransferResult acceptPlayerOffer(JobOffer o) {
    final p = userPlayer;
    final old = userTeam;
    final to = _index[o.teamId];
    if (p == null || old == null || to == null) return const TransferResult(false, 'Proposta inválida.');
    final fee = p.marketValue;
    old.squad.remove(p);
    old.startingIds.remove(p.id);
    old.balance += fee;
    to.balance -= fee;
    to.squad.add(p);
    p
      ..wage = o.salary
      ..contractYears = 3
      ..morale = 85;
    userTeamId = to.id;
    career.offers.clear();
    playerCareer!.transferRequested = false;
    _currentStats();
    career.log.add('$seasonYear: transferido do ${old.name} para o ${to.name} por ${formatMoney(fee)}.');
    _addNews('✈️ ${p.name} é o novo reforço do ${to.name} (${formatMoney(fee)}).');
    _changed();
    return TransferResult(true, 'Bem-vindo ao ${to.name}!');
  }

  void retirePlayer() {
    final pc = playerCareer;
    final p = userPlayer;
    if (pc == null || pc.retired) return;
    pc.retired = true;
    career.log.add('$seasonYear: aposentou-se aos ${p?.age ?? '-'} anos.');
    _addNews('👋 ${career.name} pendura as chuteiras: ${pc.totalGames} jogos, ${pc.totalGoals} gols, ${pc.caps} jogos pela Seleção.');
    if (p != null) {
      userTeam?.squad.remove(p);
      userTeam?.startingIds.remove(p.id);
    }
    _changed();
  }

  void _playerSeasonClose() {
    final pc = playerCareer;
    final p = userPlayer;
    if (pc == null || p == null || pc.retired) return;
    final s = currentPlayerStats;
    if (s != null && s.games > 0) {
      career.log.add('$seasonYear: ${s.games} jogos, ${s.goals} gols, ${s.assists} assistências, nota média ${s.avgRating.toStringAsFixed(2)}.');
      if (s.avgRating >= 7.0 && s.games >= 10) _generatePlayerOffers(1 + _rng.nextInt(2));
    }
  }

  void _playerSeasonStart() {
    final pc = playerCareer;
    final p = userPlayer;
    if (pc == null || p == null || pc.retired) return;
    pc.transferRequested = false;
    _currentStats();
    if (p.age >= 40) {
      retirePlayer();
      return;
    }
    _addNews('📅 Temporada $seasonYear: ${p.name}, ${p.age} anos, overall ${p.overall}.');
  }
}
