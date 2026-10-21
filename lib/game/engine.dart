import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'data.dart';
import 'economy.dart';

class GameState extends ChangeNotifier {
  List<Team> teams = [];
  List<Match> matches = [];
  int currentRound = 1;
  int seasonYear = 2026;
  String? userTeamId;
  bool started = false;
  final Random _rng = Random();

  // Fases 8, 9 e 10A
  CoachCareer career = CoachCareer(name: 'Treinador');
  List<Player> freeAgents = [];
  List<TransferOffer> incomingOffers = [];
  List<FinanceEntry> ledger = [];
  List<NewsItem> news = [];
  List<SeasonRecord> history = [];

  static const String _saveKey = 'fmbr_save_v1';
  static const int maxSquadSize = 30;
  static const int minSquadSize = 18;

  int get totalRounds => teams.isEmpty ? 0 : (teams.length - 1) * 2;

  Team teamById(String id) => teams.firstWhere((t) => t.id == id);

  Team? get userTeam => userTeamId == null ? null : teamById(userTeamId!);

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

  int positionOf(String teamId) => standings.indexWhere((t) => t.id == teamId) + 1;

  int get userPosition => userTeamId == null ? 0 : positionOf(userTeamId!);

  bool get seasonFinished => currentRound > totalRounds;

  void startGame(String teamId, {String coachName = 'Treinador'}) {
    teams = createLeague();
    for (final t in teams) {
      t.startingIds = autoLineup(t);
    }
    userTeamId = teamId;
    matches = _generateSchedule();
    currentRound = 1;
    seasonYear = 2026;
    started = true;

    final t = userTeam!;
    final name = coachName.trim().isEmpty ? 'Treinador' : coachName.trim();
    career = CoachCareer(
      name: name,
      salary: coachSalary(t.stars, 50),
      goal: goalForStars(t.stars),
    );
    career.log.add('$seasonYear: assumiu o ${t.name}.');
    t.coach = name;
    freeAgents = generateFreeAgents(_rng, 30);
    incomingOffers = [];
    ledger = [];
    news = [];
    history = [];
    _aiListPlayers();
    _addNews('👔 ${career.name} assume o ${t.name}. Meta da diretoria: ${career.goal.label}.');
    notifyListeners();
    saveToDisk();
  }

  // ---------------------------------------------------------------------------
  // Escalação
  // ---------------------------------------------------------------------------

  static const Map<String, int> _lineupQuota = {
    'GOL': 1, 'ZAG': 2, 'LAT': 2, 'VOL': 2, 'MEI': 2, 'ATA': 2,
  };

  List<String> autoLineup(Team t) => _fillLineup(t, const []);

  /// Mantém os titulares de [keep] (se aptos) e completa até 11 respeitando
  /// as cotas por posição. Considera energia e ignora lesionados.
  List<String> _fillLineup(Team t, List<String> keep) {
    double score(Player p) => p.overall * (0.85 + 0.15 * p.energy / 100.0);
    final pool = t.squad.where((p) => !p.injured).toList()
      ..sort((a, b) => score(b).compareTo(score(a)));
    final ids = <String>[];
    final counts = <String, int>{};
    for (final id in keep) {
      final p = t.findPlayer(id);
      if (p == null || p.injured || ids.contains(id) || ids.length >= 11) continue;
      ids.add(id);
      pool.remove(p);
      counts[p.position] = (counts[p.position] ?? 0) + 1;
    }
    _lineupQuota.forEach((pos, n) {
      for (final p in pool.where((p) => p.position == pos).toList()) {
        if ((counts[pos] ?? 0) >= n || ids.length >= 11) break;
        ids.add(p.id);
        pool.remove(p);
        counts[pos] = (counts[pos] ?? 0) + 1;
      }
    });
    while (ids.length < 11 && pool.isNotEmpty) {
      final next = pool.firstWhere((p) => p.position != 'GOL', orElse: () => pool.first);
      ids.add(next.id);
      pool.remove(next);
    }
    return ids;
  }

  void _prepareLineups() {
    for (final t in teams) {
      t.startingIds = t.id == userTeamId ? _fillLineup(t, t.startingIds) : autoLineup(t);
    }
  }

  /// Coloca/tira um jogador do time titular do usuário. Retorna uma mensagem
  /// de erro quando a troca não é possível.
  String? toggleStarter(String playerId) {
    final t = userTeam;
    if (t == null) return null;
    final p = t.findPlayer(playerId);
    if (p == null) return null;
    if (t.startingIds.contains(playerId)) {
      t.startingIds.remove(playerId);
    } else {
      if (p.injured) return '${p.name} está lesionado.';
      if (t.startingIds.length >= 11) {
        final samePos = t.startingPlayers.where((s) => s.position == p.position).toList()
          ..sort((a, b) => a.overall.compareTo(b.overall));
        if (samePos.isEmpty) {
          return 'Escalação completa: tire um titular antes de colocar ${p.name}.';
        }
        final idx = t.startingIds.indexOf(samePos.first.id);
        t.startingIds[idx] = p.id;
      } else {
        t.startingIds.add(p.id);
      }
    }
    notifyListeners();
    saveToDisk();
    return null;
  }

  void resetUserLineup() {
    final t = userTeam;
    if (t == null) return;
    t.startingIds = autoLineup(t);
    notifyListeners();
    saveToDisk();
  }

  /// Rodadas que o atleta ainda vai desfalcar (para exibição).
  int roundsOut(Player p) => max(0, p.injuredRounds - (currentRoundPlayed ? 1 : 0));

  // ---------------------------------------------------------------------------
  // Rodadas
  // ---------------------------------------------------------------------------

  List<Match> get currentRoundMatches =>
      matches.where((m) => m.round == currentRound).toList();

  bool get currentRoundPlayed =>
      currentRoundMatches.isNotEmpty &&
      currentRoundMatches.every((m) => m.isPlayed);

  Match? get userMatchCurrent {
    if (seasonFinished || userTeamId == null) return null;
    for (final m in currentRoundMatches) {
      if (!m.isPlayed && (m.homeId == userTeamId || m.awayId == userTeamId)) {
        return m;
      }
    }
    return null;
  }

  void simulateOtherMatches() {
    _prepareLineups();
    for (final m in currentRoundMatches) {
      if (m.isPlayed) continue;
      if (m.homeId == userTeamId || m.awayId == userTeamId) continue;
      final home = teamById(m.homeId);
      final away = teamById(m.awayId);
      final score = _simulateScore(home, away);
      m.homeGoals = score[0];
      m.awayGoals = score[1];
      _applyResult(home, away, score[0], score[1]);
      _applyEffects(home, home.startingPlayers, score[0], score[1], const []);
      _applyEffects(away, away.startingPlayers, score[1], score[0], const []);
      _matchFinances(home, away, score[0], score[1]);
      _randomInjury(home);
      _randomInjury(away);
    }
    notifyListeners();
    saveToDisk();
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
    final aTeam = teamById(userIsHome ? m.awayId : m.homeId);
    final uGf = userIsHome ? hg : ag;
    final uGa = userIsHome ? ag : hg;
    final aGf = userIsHome ? ag : hg;
    final aGa = userIsHome ? hg : ag;
    final msgs = _applyEffects(uTeam, userOnPitch, uGf, uGa, userScorerIds);
    _applyEffects(aTeam, aiOnPitch, aGf, aGa, aiScorerIds);
    _updateFanMorale(uTeam, uGf, uGa);
    _updatePressMorale(uTeam, uGf, uGa);
    final homeTeam = teamById(m.homeId);
    final awayTeam = teamById(m.awayId);
    m.homeGoals = hg;
    m.awayGoals = ag;
    _applyResult(homeTeam, awayTeam, hg, ag);
    _matchFinances(homeTeam, awayTeam, hg, ag);
    _updateBoardConfidence(uGf, uGa);
    notifyListeners();
    saveToDisk();
    return msgs;
  }

  void _updateFanMorale(Team t, int gf, int ga) {
    final won = gf > ga;
    final drew = gf == ga;
    int change = 0;
    if (won) change = 10;
    if (drew) change = 2;
    if (!won && !drew) change = -8;
    if (gf >= 3) change += 5;
    if (ga >= 3) change -= 5;
    t.fanMorale = (t.fanMorale + change).clamp(0, 100).toInt();
  }

  void _updatePressMorale(Team t, int gf, int ga) {
    final won = gf > ga;
    final drew = gf == ga;
    int change = 0;
    if (won) change = 8;
    if (drew) change = 1;
    if (!won && !drew) change = -10;
    if (userPosition <= 4) change += 3;
    if (userPosition >= 17) change -= 5;
    t.pressMorale = (t.pressMorale + change).clamp(0, 100).toInt();
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
      // CT: jovens evoluem mais rápido
      if (p.age <= 23) xp = (xp * (1 + 0.25 * t.ctLevel)).round();
      msgs.addAll(p.gainXp(xp));
    }
    return msgs;
  }

  void advanceRound() {
    if (!currentRoundPlayed || seasonFinished) return;
    final finished = currentRound;
    currentRound++;
    for (final t in teams) {
      final isUser = t.id == userTeamId;
      for (final p in t.squad) {
        p.energy = (p.energy + 15 + 5 * t.medicalLevel).clamp(0, 100).toInt();
        if (p.injuredRounds > 0) p.injuredRounds--;
        // Treino no CT para jovens que não foram titulares
        if (p.age <= 23 && !t.startingIds.contains(p.id)) {
          final msgs = p.gainXp(1 + t.ctLevel);
          if (isUser) {
            for (final m in msgs) {
              _addNews('📈 Treino no CT: $m');
            }
          }
        }
      }
    }
    if (finished % 4 == 0) _monthlyFinances(finished ~/ 4);
    _expireOffers();
    _aiTransferActivity();
    if (career.employed && userTeamId != null) {
      if (finished >= 6 && career.boardConfidence <= 15) {
        _leaveClub(fired: true, reason: 'após a $finishedª rodada');
      }
    } else if (career.offers.length < 3 && (career.offers.isEmpty || _rng.nextDouble() < 0.35)) {
      _generateJobOffers(1);
    }
    if (seasonFinished) _closeSeason();
    notifyListeners();
    saveToDisk();
  }

  void startNewSeason() {
    final lastTable = standings;
    seasonYear++;
    for (final t in teams) {
      t.points = 0;
      t.wins = 0;
      t.draws = 0;
      t.losses = 0;
      t.goalsFor = 0;
      t.goalsAgainst = 0;
      t.played = 0;
      t.fanMorale = 70;
      t.pressMorale = 70;
      for (final p in t.squad) {
        p.age++;
        if (p.age >= 34) {
          p.overall = (p.overall - 2).clamp(55, 94).toInt();
        } else if (p.age >= 32) {
          p.overall = (p.overall - 1).clamp(55, 94).toInt();
        }
        p.energy = 100;
        p.morale = 70;
        p.injuredRounds = 0;
        p.contractYears--;
      }
    }

    // Empréstimos voltam ao clube de origem
    for (final t in teams) {
      for (final p in t.squad.where((p) => p.onLoan).toList()) {
        final owner = teams.where((x) => x.id == p.loanFromTeamId).firstOrNull;
        if (owner == null) continue;
        t.squad.remove(p);
        p.loanFromTeamId = null;
        owner.squad.add(p);
        if (t.id == userTeamId) {
          _addNews('↩️ ${p.name} voltou ao ${owner.name} ao fim do empréstimo.');
        }
      }
    }

    // Contratos encerrados, aposentadorias, base e reposição
    for (final t in teams) {
      final isUser = t.id == userTeamId;
      final avg = t.averageOverall;
      for (final p in t.squad.toList()) {
        if (p.age >= 38 || (p.age >= 35 && p.overall < 70)) {
          t.squad.remove(p);
          if (isUser) _addNews('👋 ${p.name} se aposentou aos ${p.age} anos.');
          continue;
        }
        if (p.contractYears > 0) continue;
        if (!isUser && p.age < 33 && p.overall >= avg - 4) {
          p.contractYears = 1 + _rng.nextInt(3);
          p.wage = max(p.wage, Player.fairWage(p.overall, p.age));
          continue;
        }
        t.squad.remove(p);
        p.listed = false;
        p.askingPrice = 0;
        freeAgents.add(p);
        if (isUser) _addNews('📄 O contrato de ${p.name} terminou e ele deixou o clube.');
      }
      for (int i = 0; i < 2; i++) {
        final y = generateYouth(_rng, _neediestPosition(t), t.baseOverall, 2 * t.ctLevel);
        t.squad.add(y);
        if (isUser) {
          _addNews('🌱 Promessa da base: ${y.name} (${y.position}, ${y.age} anos, overall ${y.overall}).');
        }
      }
      if (!isUser) {
        while (t.squad.length < 22 && freeAgents.isNotEmpty) {
          _aiSignFreeAgent(t);
        }
        for (final p in t.squad) {
          p.listed = false;
        }
      }
      final pos = lastTable.indexOf(t) + 1;
      t.sponsorMonthly = roundTo(baseSponsor(t.stars) * (1.0 + (10 - pos) * 0.02), 10000);
    }

    // Agentes livres envelhecem; a fila é renovada
    freeAgents.removeWhere((p) => p.age >= 36);
    for (final p in freeAgents) {
      p.age++;
    }
    if (freeAgents.length < 30) {
      freeAgents.addAll(generateFreeAgents(_rng, 30 - freeAgents.length));
    }
    if (freeAgents.length > 60) freeAgents = freeAgents.sublist(freeAgents.length - 60);

    for (final t in teams) {
      t.startingIds = t.id == userTeamId ? _fillLineup(t, t.startingIds) : autoLineup(t);
    }
    if (career.employed) career.offers.clear();
    incomingOffers.clear();
    ledger.removeWhere((e) => e.season < seasonYear - 1);
    _aiListPlayers();
    matches = _generateSchedule();
    currentRound = 1;
    final u = userTeam;
    if (u != null) {
      _addNews('📅 Começa a temporada $seasonYear! Meta da diretoria: ${career.goal.label}.');
    }
    notifyListeners();
    saveToDisk();
  }

  // ---------------------------------------------------------------------------
  // Fase 8 — Finanças
  // ---------------------------------------------------------------------------

  void _credit(Team t, int amount, String category, String description) {
    t.balance += amount;
    if (t.id == userTeamId && amount != 0) {
      ledger.add(FinanceEntry(
        season: seasonYear,
        round: min(currentRound, totalRounds),
        category: category,
        description: description,
        amount: amount,
      ));
    }
  }

  void _debit(Team t, int amount, String category, String description) =>
      _credit(t, -amount, category, description);

  void _matchFinances(Team home, Team away, int hg, int ag) {
    final crowd = attendance(home, positionOf(home.id));
    _credit(home, crowd * ticketPrice(home), 'Bilheteria',
        'Bilheteria vs ${away.name} ($crowd pagantes)');
    if (hg > ag) {
      _credit(home, kWinBonus, 'Premiação', 'Vitória sobre ${away.name}');
    } else if (hg < ag) {
      _credit(away, kWinBonus, 'Premiação', 'Vitória sobre ${home.name}');
    } else {
      _credit(home, kDrawBonus, 'Premiação', 'Empate com ${away.name}');
      _credit(away, kDrawBonus, 'Premiação', 'Empate com ${home.name}');
    }
  }

  void _monthlyFinances(int month) {
    for (final t in teams) {
      final isUser = t.id == userTeamId;
      _debit(t, t.payroll, 'Salários', 'Folha salarial (mês $month)');
      _credit(t, t.sponsorMonthly, 'Patrocínio', 'Patrocínio master (mês $month)');
      _credit(t, tvRights(t.stars), 'Cotas de TV', 'Direitos de transmissão (mês $month)');
      _debit(t, monthlyMaintenance(t), 'Estrutura', 'Manutenção de CT, estádio e DM');
      _debit(t, isUser ? career.salary : coachSalary(t.stars, 50), 'Comissão técnica',
          'Salário do técnico');
      if (isUser) career.earnings += career.salary;
      if (t.balance < 0) {
        _debit(t, (t.balance.abs() * 0.02).round(), 'Multas', 'Juros e multas por salários atrasados');
        for (final p in t.squad) {
          p.morale = (p.morale - 5).clamp(0, 100).toInt();
        }
        t.fanMorale = (t.fanMorale - 3).clamp(0, 100).toInt();
        if (isUser) {
          career.boardConfidence = (career.boardConfidence - 5).clamp(0, 100).toInt();
          _addNews('⚠️ Caixa negativo! Salários atrasados derrubam a moral do elenco.');
        }
      }
    }
  }

  TransferResult upgradeFacility(Facility f) {
    final t = userTeam;
    if (t == null) return const TransferResult(false, 'Você está sem clube.');
    final level = f.levelOf(t);
    if (level >= kMaxFacilityLevel) {
      return TransferResult(false, '${f.label} já está no nível máximo.');
    }
    final cost = facilityCost(level + 1);
    if (t.balance < cost) {
      return TransferResult(false, 'Caixa insuficiente: a obra custa ${formatMoney(cost)}.');
    }
    _debit(t, cost, 'Investimentos', '${f.label}: nível ${level + 1}');
    f.setLevel(t, level + 1);
    _addNews('${f.emoji} ${f.label} do ${t.name} chega ao nível ${level + 1}!');
    notifyListeners();
    saveToDisk();
    return TransferResult(true, '${f.label} agora está no nível ${level + 1}.');
  }

  TransferResult renegotiateSponsor() {
    final t = userTeam;
    if (t == null) return const TransferResult(false, 'Você está sem clube.');
    if (t.sponsorRenegotiatedSeason == seasonYear) {
      return const TransferResult(false, 'O patrocínio já foi renegociado nesta temporada.');
    }
    t.sponsorRenegotiatedSeason = seasonYear;
    final pos = userPosition;
    double chance = 0.35 + (t.fanMorale - 50) / 200.0;
    if (pos > 0 && pos <= 6) chance += 0.15;
    if (pos >= 17) chance -= 0.2;
    String msg;
    bool ok = _rng.nextDouble() < chance;
    if (ok) {
      final inc = 0.10 + _rng.nextDouble() * 0.15;
      t.sponsorMonthly = roundTo(t.sponsorMonthly * (1 + inc), 10000);
      msg = 'Novo contrato: ${formatMoney(t.sponsorMonthly)}/mês (+${(inc * 100).round()}%).';
      _addNews('🤝 ${t.name} renova patrocínio master por ${formatMoney(t.sponsorMonthly)}/mês.');
    } else {
      msg = 'O patrocinador manteve ${formatMoney(t.sponsorMonthly)}/mês. Tente na próxima temporada.';
    }
    notifyListeners();
    saveToDisk();
    return TransferResult(ok, msg);
  }

  // ---------------------------------------------------------------------------
  // Fase 9 — Mercado de transferências
  // ---------------------------------------------------------------------------

  Team? ownerOf(String playerId) {
    for (final t in teams) {
      if (t.findPlayer(playerId) != null) return t;
    }
    return null;
  }

  /// Jogadores de outros clubes, do mais forte para o mais fraco.
  List<(Team, Player)> marketPlayers({String? position, int? maxPrice, bool onlyListed = false}) {
    final result = <(Team, Player)>[];
    for (final t in teams) {
      if (t.id == userTeamId) continue;
      for (final p in t.squad) {
        if (p.onLoan) continue;
        if (position != null && p.position != position) continue;
        if (onlyListed && !p.listed) continue;
        if (maxPrice != null && askingPriceFor(t, p) > maxPrice) continue;
        result.add((t, p));
      }
    }
    result.sort((a, b) => b.$2.overall.compareTo(a.$2.overall));
    return result;
  }

  /// Valor pedido pelo clube da IA para negociar o atleta.
  int askingPriceFor(Team seller, Player p) {
    if (p.listed && p.askingPrice > 0) return p.askingPrice;
    final starter = seller.startingIds.contains(p.id);
    return roundTo(p.marketValue * (starter ? 1.5 : 1.2), 50000);
  }

  /// Salário mensal que o atleta pede para assinar com o clube do usuário.
  int wageDemand(Player p, {Team? from}) {
    final user = userTeam;
    double d = max(p.wage, Player.fairWage(p.overall, p.age)).toDouble();
    if (from == null) {
      d *= 0.9;
    } else if (user != null && from.stars > user.stars) {
      d *= 1.2;
    }
    return roundTo(d, 1000);
  }

  /// Salário pedido para renovar contrato.
  int renewalDemand(Player p) {
    final base = max(p.wage, Player.fairWage(p.overall, p.age));
    return roundTo(base * (p.morale >= 70 ? 1.05 : 1.15), 1000);
  }

  int _contractFor(int years) => years + (seasonFinished ? 1 : 0);

  String? _squadCheck(Team user) {
    if (user.squad.length >= maxSquadSize) {
      return 'Elenco cheio ($maxSquadSize atletas). Venda ou dispense alguém antes.';
    }
    return null;
  }

  TransferResult proposeTransfer({
    required String playerId,
    required int fee,
    required int wage,
    required int signingBonus,
    required int years,
  }) {
    final user = userTeam;
    if (user == null) return const TransferResult(false, 'Você está sem clube.');
    final seller = ownerOf(playerId);
    if (seller == null || seller.id == user.id) {
      return const TransferResult(false, 'Jogador indisponível.');
    }
    final p = seller.playerById(playerId);
    if (p.onLoan) return TransferResult(false, '${p.name} está emprestado e não pode ser negociado.');
    final full = _squadCheck(user);
    if (full != null) return TransferResult(false, full);
    if (seller.squad.length <= minSquadSize) {
      return TransferResult(false, 'O ${seller.name} não aceita reduzir mais o elenco.');
    }
    if (user.balance < fee + signingBonus) {
      return TransferResult(false, 'Caixa insuficiente: você tem ${formatMoney(user.balance)}.');
    }

    // 1) Clube vendedor (multa rescisória paga = negócio aceito)
    if (fee < p.releaseClause) {
      final asking = askingPriceFor(seller, p);
      final ratio = fee / asking;
      double chance = ratio >= 1.0
          ? 0.9
          : ratio >= 0.9
              ? 0.55
              : ratio >= 0.8
                  ? 0.25
                  : 0.03;
      chance += (user.stars - seller.stars) * 0.05;
      if (_rng.nextDouble() > chance) {
        notifyListeners();
        return TransferResult(false,
            'O ${seller.name} recusou ${formatMoney(fee)} por ${p.name}. Eles pedem cerca de ${formatMoney(asking)}.');
      }
    }

    // 2) Jogador (salário + luvas diluídas no contrato)
    final demand = wageDemand(p, from: seller);
    final effective = wage + signingBonus / (years * 12);
    final accepted = effective >= demand || (effective >= demand * 0.85 && _rng.nextDouble() < 0.5);
    if (!accepted) {
      return TransferResult(false,
          'O ${seller.name} aceitou, mas ${p.name} recusou o salário. Ele pede ${formatMoney(demand)}/mês.');
    }

    seller.squad.remove(p);
    seller.startingIds.remove(p.id);
    seller.balance += fee;
    _debit(user, fee, 'Transferências', 'Compra de ${p.name} (${seller.name})');
    if (signingBonus > 0) _debit(user, signingBonus, 'Transferências', 'Luvas para ${p.name}');
    p
      ..wage = wage
      ..contractYears = _contractFor(years)
      ..releaseClause = max(p.marketValue * 2, fee * 2)
      ..listed = false
      ..askingPrice = 0
      ..morale = 75;
    user.squad.add(p);
    _addNews('✍️ ${p.name} é o novo reforço do ${user.name} (${formatMoney(fee)}).');
    notifyListeners();
    saveToDisk();
    return TransferResult(true, '${p.name} assinou por $years temporada(s)!');
  }

  int loanFee(Player p) => roundTo(p.marketValue * 0.1, 50000);

  TransferResult proposeLoan(String playerId) {
    final user = userTeam;
    if (user == null) return const TransferResult(false, 'Você está sem clube.');
    final seller = ownerOf(playerId);
    if (seller == null || seller.id == user.id) {
      return const TransferResult(false, 'Jogador indisponível.');
    }
    final p = seller.playerById(playerId);
    if (p.onLoan) return TransferResult(false, '${p.name} já está emprestado.');
    final full = _squadCheck(user);
    if (full != null) return TransferResult(false, full);
    if (seller.squad.length <= minSquadSize) {
      return TransferResult(false, 'O ${seller.name} não aceita reduzir mais o elenco.');
    }
    final fee = loanFee(p);
    if (user.balance < fee) {
      return TransferResult(false, 'Caixa insuficiente para a taxa de ${formatMoney(fee)}.');
    }
    final starter = seller.startingIds.contains(p.id);
    final chance = (starter ? 0.15 : 0.75) + (user.stars - seller.stars) * 0.05;
    if (_rng.nextDouble() > chance) {
      return TransferResult(false, 'O ${seller.name} não quer emprestar ${p.name}.');
    }
    seller.squad.remove(p);
    seller.startingIds.remove(p.id);
    seller.balance += fee;
    _debit(user, fee, 'Transferências', 'Empréstimo de ${p.name} (${seller.name})');
    p
      ..loanFromTeamId = seller.id
      ..listed = false
      ..askingPrice = 0;
    user.squad.add(p);
    _addNews('🔁 ${p.name} chega ao ${user.name} por empréstimo até o fim da temporada.');
    notifyListeners();
    saveToDisk();
    return TransferResult(true,
        '${p.name} emprestado até o fim da temporada. Salário de ${formatMoney(p.wage)}/mês por sua conta.');
  }

  TransferResult signFreeAgent(String playerId, {required int wage, required int years}) {
    final user = userTeam;
    if (user == null) return const TransferResult(false, 'Você está sem clube.');
    final p = freeAgents.where((x) => x.id == playerId).firstOrNull;
    if (p == null) return const TransferResult(false, 'Jogador já assinou com outro clube.');
    final full = _squadCheck(user);
    if (full != null) return TransferResult(false, full);
    final demand = wageDemand(p);
    if (wage < demand * 0.8 || (wage < demand && _rng.nextDouble() < 0.5)) {
      return TransferResult(false, '${p.name} recusou. Ele pede ${formatMoney(demand)}/mês.');
    }
    freeAgents.remove(p);
    p
      ..wage = wage
      ..contractYears = _contractFor(years)
      ..releaseClause = p.marketValue * 2
      ..morale = 75;
    user.squad.add(p);
    _addNews('✍️ ${p.name} (agente livre) assina com o ${user.name}.');
    notifyListeners();
    saveToDisk();
    return TransferResult(true, '${p.name} assinou por $years temporada(s)!');
  }

  void setListed(String playerId, bool listed, {int? price}) {
    final p = userTeam?.findPlayer(playerId);
    if (p == null || p.onLoan) return;
    p.listed = listed;
    p.askingPrice = listed ? (price ?? p.marketValue) : 0;
    if (!listed) incomingOffers.removeWhere((o) => o.playerId == playerId);
    notifyListeners();
    saveToDisk();
  }

  int releaseCost(Player p) => p.onLoan ? 0 : p.wage * 3;

  TransferResult releasePlayer(String playerId) {
    final user = userTeam;
    final p = user?.findPlayer(playerId);
    if (user == null || p == null) return const TransferResult(false, 'Jogador não encontrado.');
    if (user.squad.length <= minSquadSize) {
      return const TransferResult(false, 'Elenco no tamanho mínimo ($minSquadSize).');
    }
    user.squad.remove(p);
    user.startingIds.remove(p.id);
    incomingOffers.removeWhere((o) => o.playerId == p.id);
    if (p.onLoan) {
      final owner = teams.where((t) => t.id == p.loanFromTeamId).firstOrNull;
      p.loanFromTeamId = null;
      owner?.squad.add(p);
      notifyListeners();
      saveToDisk();
      return TransferResult(true, '${p.name} foi devolvido ao ${owner?.name ?? 'clube de origem'}.');
    }
    final cost = releaseCost(p);
    _debit(user, cost, 'Transferências', 'Rescisão de ${p.name}');
    p
      ..listed = false
      ..askingPrice = 0
      ..contractYears = 0;
    freeAgents.add(p);
    notifyListeners();
    saveToDisk();
    return TransferResult(true, 'Contrato de ${p.name} rescindido (${formatMoney(cost)}).');
  }

  TransferResult renewContract(String playerId, {required int wage, required int years}) {
    final p = userTeam?.findPlayer(playerId);
    if (p == null) return const TransferResult(false, 'Jogador não encontrado.');
    if (p.onLoan) return TransferResult(false, '${p.name} está emprestado.');
    final demand = renewalDemand(p);
    final ok = wage >= demand || (wage >= demand * 0.9 && _rng.nextDouble() < 0.4);
    if (!ok) {
      p.morale = (p.morale - 3).clamp(0, 100).toInt();
      notifyListeners();
      return TransferResult(false, '${p.name} recusou. Ele pede ${formatMoney(demand)}/mês.');
    }
    p
      ..wage = wage
      ..contractYears = years + 1
      ..releaseClause = max(p.releaseClause, p.marketValue * 2)
      ..morale = (p.morale + 5).clamp(0, 100).toInt();
    _addNews('🖊️ ${p.name} renova até ${seasonYear + years}.');
    notifyListeners();
    saveToDisk();
    return TransferResult(true, '${p.name} renovou até ${seasonYear + years}!');
  }

  TransferResult acceptOffer(TransferOffer o) {
    final user = userTeam;
    final p = user?.findPlayer(o.playerId);
    final buyer = teams.where((t) => t.id == o.buyerId).firstOrNull;
    if (user == null || p == null || buyer == null) {
      incomingOffers.remove(o);
      notifyListeners();
      return const TransferResult(false, 'A proposta não é mais válida.');
    }
    if (user.squad.length <= minSquadSize) {
      return const TransferResult(false, 'Elenco no tamanho mínimo: contrate antes de vender.');
    }
    if (buyer.balance < o.amount) {
      incomingOffers.remove(o);
      notifyListeners();
      return TransferResult(false, 'O ${buyer.name} não tem mais caixa e desistiu.');
    }
    buyer.balance -= o.amount;
    _credit(user, o.amount, 'Transferências', 'Venda de ${p.name} para o ${buyer.name}');
    user.squad.remove(p);
    user.startingIds.remove(p.id);
    p
      ..listed = false
      ..askingPrice = 0
      ..contractYears = max(2, p.contractYears)
      ..wage = max(p.wage, Player.fairWage(p.overall, p.age));
    buyer.squad.add(p);
    incomingOffers.removeWhere((x) => x.playerId == p.id);
    _addNews('💸 ${p.name} vendido ao ${buyer.name} por ${formatMoney(o.amount)}.');
    notifyListeners();
    saveToDisk();
    return TransferResult(true, '${p.name} vendido por ${formatMoney(o.amount)}!');
  }

  void rejectOffer(TransferOffer o) {
    incomingOffers.remove(o);
    notifyListeners();
    saveToDisk();
  }

  /// Pede 15% a mais. O comprador aceita (e o negócio fecha) ou desiste.
  TransferResult counterOffer(TransferOffer o) {
    final buyer = teams.where((t) => t.id == o.buyerId).firstOrNull;
    final amount = roundTo(o.amount * 1.15, 50000);
    incomingOffers.remove(o);
    if (buyer != null && buyer.balance >= amount && _rng.nextDouble() < 0.5) {
      final improved = TransferOffer(
        playerId: o.playerId,
        buyerId: o.buyerId,
        amount: amount,
        expiresRound: o.expiresRound,
      );
      incomingOffers.add(improved);
      return acceptOffer(improved);
    }
    notifyListeners();
    saveToDisk();
    return TransferResult(false, 'O ${buyer?.name ?? 'comprador'} não aceitou pagar ${formatMoney(amount)} e desistiu.');
  }

  void _expireOffers() {
    final user = userTeam;
    incomingOffers.removeWhere((o) =>
        o.expiresRound < currentRound || user == null || user.findPlayer(o.playerId) == null);
  }

  String _neediestPosition(Team t) {
    String best = 'ATA';
    int bestGap = -999;
    kSquadTargets.forEach((pos, target) {
      final gap = target - t.squad.where((p) => p.position == pos).length;
      if (gap > bestGap) {
        bestGap = gap;
        best = pos;
      }
    });
    return best;
  }

  void _aiSignFreeAgent(Team t) {
    if (freeAgents.isEmpty) return;
    final need = _neediestPosition(t);
    final pool = freeAgents.where((p) => p.position == need).toList();
    final cands = pool.isEmpty ? List<Player>.from(freeAgents) : pool;
    cands.sort((a, b) => b.overall.compareTo(a.overall));
    final pick = cands.first;
    freeAgents.remove(pick);
    pick
      ..contractYears = 1 + _rng.nextInt(3)
      ..wage = Player.fairWage(pick.overall, pick.age)
      ..morale = 70;
    t.squad.add(pick);
  }

  /// Clubes da IA colocam atletas excedentes na lista de transferências.
  void _aiListPlayers() {
    for (final t in teams) {
      if (t.id == userTeamId) continue;
      final cands = t.squad
          .where((p) => !t.startingIds.contains(p.id) && !p.onLoan &&
              (p.age >= 30 || p.overall < t.averageOverall - 3))
          .toList()
        ..shuffle(_rng);
      for (final p in cands.take(1 + _rng.nextInt(2))) {
        p.listed = true;
        p.askingPrice = roundTo(p.marketValue * (0.85 + _rng.nextDouble() * 0.15), 50000);
      }
    }
  }

  void _aiTransferActivity() {
    final user = userTeam;
    if (user != null) {
      final avg = user.averageOverall;
      for (final p in user.squad) {
        if (p.onLoan || incomingOffers.any((o) => o.playerId == p.id)) continue;
        final chance = p.listed ? 0.35 : (p.overall >= avg + 4 ? 0.02 : 0.0);
        if (chance == 0 || _rng.nextDouble() >= chance) continue;
        final ref = p.listed && p.askingPrice > 0 ? p.askingPrice : p.marketValue;
        final buyers = teams
            .where((t) => t.id != user.id && t.squad.length < maxSquadSize && t.balance >= ref * 0.7)
            .toList();
        if (buyers.isEmpty) continue;
        final buyer = buyers[_rng.nextInt(buyers.length)];
        final factor = p.listed ? 0.75 + _rng.nextDouble() * 0.3 : 1.1 + _rng.nextDouble() * 0.3;
        final amount = roundTo(min(ref * factor, buyer.balance.toDouble()), 50000);
        incomingOffers.add(TransferOffer(
          playerId: p.id,
          buyerId: buyer.id,
          amount: amount,
          expiresRound: currentRound + 3,
        ));
        _addNews('📩 ${buyer.name} ofereceu ${formatMoney(amount)} por ${p.name}.');
      }
    }
    if (currentRound % 4 == 0) {
      for (final t in teams) {
        if (t.id != userTeamId && t.squad.length < 20) _aiSignFreeAgent(t);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Fase 10A — Carreira do técnico
  // ---------------------------------------------------------------------------

  void _updateBoardConfidence(int gf, int ga) {
    final t = userTeam;
    if (t == null) return;
    int delta = gf > ga ? 6 : (gf == ga ? 0 : -7);
    if (t.played >= 6) {
      final ppg = t.points / t.played;
      if (ppg < career.goal.expectedPpg - 0.4) {
        delta -= 3;
      } else if (ppg >= career.goal.expectedPpg) {
        delta += 2;
      }
    }
    if (t.fanMoodStatus == FanMood.protesto) delta -= 2;
    career.boardConfidence = (career.boardConfidence + delta).clamp(0, 100).toInt();
    if (career.boardConfidence <= 30 && delta < 0) {
      _addNews('😬 A diretoria do ${t.name} está insatisfeita (confiança ${career.boardConfidence}%).');
    }
  }

  String _randomCoach() {
    final busy = teams.map((t) => t.coach).toSet();
    final free = kCoachPool.where((c) => !busy.contains(c)).toList();
    if (free.isEmpty) return kCoachPool[_rng.nextInt(kCoachPool.length)];
    return free[_rng.nextInt(free.length)];
  }

  void _generateJobOffers(int count, {bool upgradeOnly = false}) {
    final currentStars = userTeam?.stars ?? 0;
    final table = standings;
    final midSeason = currentRound > 1 && !seasonFinished;
    var cands = teams
        .where((t) =>
            t.id != userTeamId &&
            requiredReputation(t.stars) <= career.reputation &&
            !career.offers.any((o) => o.teamId == t.id) &&
            (!upgradeOnly || t.stars > currentStars))
        .toList()
      ..shuffle(_rng);
    if (midSeason) {
      final struggling = cands.where((t) => table.indexOf(t) >= 10).toList();
      if (struggling.isNotEmpty) cands = struggling;
    }
    for (final t in cands.take(count)) {
      if (career.offers.length >= 3) break;
      final pos = table.indexOf(t) + 1;
      final goal = midSeason && pos >= 14 ? BoardGoal.naoCair : goalForStars(t.stars);
      career.offers.add(JobOffer(
        teamId: t.id,
        salary: coachSalary(t.stars, career.reputation),
        goal: goal,
      ));
      _addNews('📨 Convite: o ${t.name} quer ${career.name} como técnico.');
    }
  }

  void acceptJobOffer(JobOffer o) {
    final t = teams.where((x) => x.id == o.teamId).firstOrNull;
    if (t == null) return;
    final old = userTeam;
    if (old != null) {
      old.coach = _randomCoach();
      career.log.add('$seasonYear: deixou o ${old.name} para assumir o ${t.name}.');
    } else {
      career.log.add('$seasonYear: assumiu o ${t.name}.');
    }
    t.coach = career.name;
    userTeamId = t.id;
    career
      ..employed = true
      ..salary = o.salary
      ..goal = o.goal
      ..boardConfidence = 60;
    career.offers.clear();
    incomingOffers.clear();
    ledger.clear();
    for (final p in t.squad) {
      p.listed = false;
      p.askingPrice = 0;
    }
    t.startingIds = autoLineup(t);
    _addNews('👔 ${career.name} é o novo técnico do ${t.name}! Meta: ${o.goal.label}.');
    notifyListeners();
    saveToDisk();
  }

  void rejectJobOffer(JobOffer o) {
    career.offers.remove(o);
    notifyListeners();
    saveToDisk();
  }

  void _leaveClub({required bool fired, required String reason}) {
    final t = userTeam;
    if (t == null) return;
    t.coach = _randomCoach();
    career
      ..employed = false
      ..salary = 0
      ..reputation = (career.reputation - (fired ? 8 : 3)).clamp(0, 100).toInt();
    userTeamId = null;
    incomingOffers.clear();
    career.offers.clear();
    career.log.add(fired
        ? '$seasonYear: demitido do ${t.name} $reason.'
        : '$seasonYear: pediu demissão do ${t.name} $reason.');
    _addNews(fired
        ? '🚨 A diretoria do ${t.name} demitiu ${career.name} $reason.'
        : '👋 ${career.name} pediu demissão do ${t.name}.');
    _generateJobOffers(1 + _rng.nextInt(2));
  }

  void resign() {
    if (!career.employed) return;
    _leaveClub(fired: false, reason: seasonFinished ? 'ao fim da temporada' : 'na $currentRoundª rodada');
    notifyListeners();
    saveToDisk();
  }

  void _closeSeason() {
    final table = standings;
    for (int i = 0; i < table.length; i++) {
      final t = table[i];
      final pos = i + 1;
      _credit(t, positionPrize(pos), 'Premiação', 'Premiação: $posº lugar na Série A');
      if (pos <= 4) {
        _credit(t, kLibertadoresBonus, 'Premiação', 'Vaga na Libertadores');
      } else if (pos <= 6) {
        _credit(t, kSulAmericanaBonus, 'Premiação', 'Vaga na Sul-Americana');
      }
    }
    final champ = table.first;
    _addNews('🏆 ${champ.name} é campeão brasileiro de $seasonYear!');

    final user = career.employed ? userTeam : null;
    final upos = user == null ? null : table.indexOf(user) + 1;
    final met = upos == null ? null : upos <= career.goal.maxPosition;
    history.add(SeasonRecord(
      season: seasonYear,
      champion: champ.name,
      runnerUp: table[1].name,
      relegated: table.sublist(16).map((t) => t.name).toList(),
      userTeam: user?.name,
      userPosition: upos,
      userPoints: user?.points,
      goal: user == null ? null : career.goal.label,
      goalMet: met,
    ));

    if (user != null && upos != null) {
      int rep = career.reputation;
      if (upos == 1) {
        career.titles++;
        rep += 15;
        career.log.add('$seasonYear: 🏆 campeão brasileiro com o ${user.name}!');
      }
      if (upos <= 4) {
        rep += 4;
      } else if (upos >= 17) {
        rep -= 10;
      }
      if (met == true) {
        final bonus = career.salary * 3;
        career.earnings += bonus;
        rep += 5;
        career.boardConfidence = 70;
        career.log.add('$seasonYear: meta cumprida (${career.goal.label}) com o ${user.name} — $uposº lugar.');
        _addNews('✅ Meta cumprida! Bônus de ${formatMoney(bonus)} e contrato renovado automaticamente.');
      } else {
        rep -= 3;
        career.log.add('$seasonYear: meta não cumprida (${career.goal.label}) com o ${user.name} — $uposº lugar.');
      }
      career.reputation = rep.clamp(0, 100).toInt();
      if (met != true && upos > career.goal.maxPosition + 4) {
        _leaveClub(fired: true, reason: 'ao fim da temporada');
      } else if (met != true) {
        career.boardConfidence = 40;
        _addNews('⚠️ Meta não cumprida. A diretoria mantém ${career.name}, mas sob pressão.');
      }
      final expiring = user.squad.where((p) => !p.onLoan && p.contractYears <= 1).length;
      if (career.employed && expiring > 0) {
        _addNews('📄 $expiring contrato(s) terminam na virada da temporada. Renove em Mercado › Meu Elenco.');
      }
    }

    if (career.employed) {
      final u = userTeam!;
      career.goal = goalForStars(u.stars);
      career.salary = max(career.salary, coachSalary(u.stars, career.reputation));
      if (_rng.nextDouble() < 0.5) _generateJobOffers(1, upgradeOnly: true);
    } else if (career.offers.isEmpty) {
      _generateJobOffers(2);
    }
  }

  // ---------------------------------------------------------------------------
  // Notícias
  // ---------------------------------------------------------------------------

  void _addNews(String text) {
    news.insert(0, NewsItem(season: seasonYear, round: min(currentRound, max(1, totalRounds)), text: text));
    if (news.length > 80) news.removeRange(80, news.length);
  }

  // ---------------------------------------------------------------------------
  // Save / Load
  // ---------------------------------------------------------------------------

  Future<void> saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'teams': teams.map((t) => t.toJson()).toList(),
        'matches': matches.map((m) => m.toJson()).toList(),
        'currentRound': currentRound,
        'seasonYear': seasonYear,
        'userTeamId': userTeamId,
        'started': started,
        'career': career.toJson(),
        'freeAgents': freeAgents.map((p) => p.toJson()).toList(),
        'incomingOffers': incomingOffers.map((o) => o.toJson()).toList(),
        'ledger': ledger.map((e) => e.toJson()).toList(),
        'news': news.map((n) => n.toJson()).toList(),
        'history': history.map((h) => h.toJson()).toList(),
      };
      await prefs.setString(_saveKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Erro ao salvar: $e');
    }
  }

  static Future<GameState?> loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_saveKey);
      if (raw == null) return null;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      final gs = GameState();

      gs.teams = (map['teams'] as List)
          .map((tJson) => Team.fromJson(tJson as Map<String, dynamic>))
          .toList();
      gs.matches = (map['matches'] as List)
          .map((mJson) => Match.fromJson(mJson as Map<String, dynamic>))
          .toList();
      gs.currentRound = map['currentRound'];
      gs.seasonYear = map['seasonYear'];
      gs.userTeamId = map['userTeamId'];
      gs.started = map['started'] ?? false;

      List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
          (map[key] as List? ?? []).map((e) => f(e as Map<String, dynamic>)).toList();

      gs.freeAgents = list('freeAgents', Player.fromJson);
      gs.incomingOffers = list('incomingOffers', TransferOffer.fromJson);
      gs.ledger = list('ledger', FinanceEntry.fromJson);
      gs.news = list('news', NewsItem.fromJson);
      gs.history = list('history', SeasonRecord.fromJson);

      if (map['career'] != null) {
        gs.career = CoachCareer.fromJson(map['career'] as Map<String, dynamic>);
      } else {
        gs._migrateOldSave();
      }
      return gs;
    } catch (e) {
      debugPrint('Erro ao carregar: $e');
      return null;
    }
  }

  /// Saves anteriores à Fase 8 não tinham finanças, mercado nem carreira.
  void _migrateOldSave() {
    for (final t in teams) {
      t.balance = initialBudget(t.stars);
      t.sponsorMonthly = baseSponsor(t.stars);
      t.ctLevel = initialFacilityLevel(t.stars);
      t.medicalLevel = initialFacilityLevel(t.stars);
    }
    final u = userTeam;
    career = CoachCareer(
      name: 'Treinador',
      employed: u != null,
      salary: u == null ? 0 : coachSalary(u.stars, 50),
      goal: u == null ? BoardGoal.naoCair : goalForStars(u.stars),
    );
    if (freeAgents.isEmpty) freeAgents = generateFreeAgents(_rng, 30);
  }

  Future<void> deleteSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);
    teams = [];
    matches = [];
    currentRound = 1;
    seasonYear = 2026;
    userTeamId = null;
    started = false;
    career = CoachCareer(name: 'Treinador');
    freeAgents = [];
    incomingOffers = [];
    ledger = [];
    news = [];
    history = [];
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Coletiva de imprensa
  // ---------------------------------------------------------------------------

  List<PressConference> generatePressConference() {
    final t = userTeam;
    if (t == null) return const [];
    final pos = userPosition;
    final lastMatch = matches.where((m) =>
        m.isPlayed && (m.homeId == t.id || m.awayId == t.id)).lastOrNull;
    if (lastMatch == null) return const [];
    final userIsHome = lastMatch.homeId == t.id;
    final gf = userIsHome ? lastMatch.homeGoals! : lastMatch.awayGoals!;
    final ga = userIsHome ? lastMatch.awayGoals! : lastMatch.homeGoals!;
    final won = gf > ga;
    final drew = gf == ga;

    final questions = <PressConference>[];

    if (won) {
      questions.add(PressConference(
        question: 'Vitória importante! Como avalia a atuação da equipe?',
        answers: [
          'Fomos superiores do início ao fim, merecemos os 3 pontos.',
          'Foi uma partida difícil, mas o time mostrou caráter.',
          'Precisamos melhorar, não jogamos bem.',
        ],
        correctIndex: 0,
        correctFeedback: 'Imprensa satisfeita com sua confiança! (+5 moral)',
        wrongFeedback: 'Imprensa estranha sua modéstia. (-3 moral)',
      ));
    } else if (drew) {
      questions.add(PressConference(
        question: userIsHome
            ? 'Empate em casa. O que faltou para vencer?'
            : 'Empate fora de casa. O resultado foi bom?',
        answers: [
          'Faltou eficiência no ataque, criamos chances mas não convertemos.',
          'O adversário jogou muito bem, parabéns a eles.',
          'Foi um resultado justo, aceitável.',
        ],
        correctIndex: 0,
        correctFeedback: 'Análise técnica respeitada. (+3 moral)',
        wrongFeedback: 'Imprensa critica falta de autocrítica. (-4 moral)',
      ));
    } else {
      questions.add(PressConference(
        question: 'Derrota preocupante. Qual sua explicação?',
        answers: [
          'Assumo a responsabilidade. Precisamos trabalhar mais.',
          'A arbitragem prejudicou o time.',
          'Os jogadores não se empenharam.',
        ],
        correctIndex: 0,
        correctFeedback: 'Postura profissional elogiada. (+2 moral)',
        wrongFeedback: 'Desculpas não colam. Imprensa detona. (-8 moral)',
      ));
    }

    if (pos <= 4) {
      questions.add(PressConference(
        question: 'Time no G4. Acha que briga pelo título?',
        answers: [
          'Estamos focados jogo a jogo, mas temos qualidade para isso.',
          'Sim, somos favoritos ao título.',
          'Não, nosso objetivo é só não cair.',
        ],
        correctIndex: 0,
        correctFeedback: 'Humildade e ambição: imprensa aprova. (+4 moral)',
        wrongFeedback: 'Arrogância ou falta de visão. (-5 moral)',
      ));
    } else if (pos >= 17) {
      questions.add(PressConference(
        question: 'Time na zona de rebaixamento. Há risco de queda?',
        answers: [
          'Sabemos da situação, mas confiamos na virada.',
          'Não, vamos escapar facilmente.',
          'Sim, o risco é real e grande.',
        ],
        correctIndex: 0,
        correctFeedback: 'Realismo e esperança. (+3 moral)',
        wrongFeedback: 'Negação ou pessimismo. Imprensa pressiona. (-6 moral)',
      ));
    }

    if (t.fanMorale <= 40) {
      questions.add(PressConference(
        question: 'Torcida protestando. Como lida com a pressão?',
        answers: [
          'Entendo a frustração. Precisamos dar alegrias a eles.',
          'A torcida tem que apoiar sempre, não só quando vence.',
          'Não me importo com protestos.',
        ],
        correctIndex: 0,
        correctFeedback: 'Empatia com torcida. (+5 moral da torcida)',
        wrongFeedback: 'Desrespeito com torcida. (-10 moral da torcida)',
      ));
    }

    return questions;
  }

  void applyPressAnswer(int questionIndex, int answerIndex) {
    final t = userTeam;
    if (t == null) return;
    final questions = generatePressConference();
    if (questionIndex >= questions.length) return;
    final q = questions[questionIndex];
    if (answerIndex == q.correctIndex) {
      t.pressMorale = (t.pressMorale + 5).clamp(0, 100).toInt();
      if (q.correctFeedback.contains('torcida')) {
        t.fanMorale = (t.fanMorale + 5).clamp(0, 100).toInt();
      }
    } else {
      final penalty = q.wrongFeedback.contains('10') ? 10 :
                      q.wrongFeedback.contains('8') ? 8 :
                      q.wrongFeedback.contains('6') ? 6 :
                      q.wrongFeedback.contains('5') ? 5 :
                      q.wrongFeedback.contains('4') ? 4 : 3;
      if (q.wrongFeedback.contains('torcida')) {
        t.fanMorale = (t.fanMorale - penalty).clamp(0, 100).toInt();
      } else {
        t.pressMorale = (t.pressMorale - penalty).clamp(0, 100).toInt();
      }
    }
    notifyListeners();
    saveToDisk();
  }

  // ---------------------------------------------------------------------------
  // Simulação
  // ---------------------------------------------------------------------------

  List<double> _tacticMods(Tactic t) {
    switch (t) {
      case Tactic.retranca: return [-0.45, -0.35];
      case Tactic.neutro: return [0.0, 0.0];
      case Tactic.ofensivo: return [0.35, 0.15];
      case Tactic.tudoOuNada: return [0.70, 0.45];
    }
  }

  List<double> lambdasFrom(double hs, double aws, Tactic ht, Tactic at) {
    final diff = hs - aws;
    final mh = _tacticMods(ht);
    final ma = _tacticMods(at);
    final lh = (1.45 + diff / 18.0 + mh[0] + ma[1]).clamp(0.25, 4.5).toDouble();
    final la = (1.15 - diff / 18.0 + ma[0] + mh[1]).clamp(0.25, 4.5).toDouble();
    return [lh, la];
  }

  /// Bônus do mando de campo: torcida empolgada empurra mais (Fase 6).
  double homeAdvantage(Team t) => 2.0 + 4.0 * t.fanMorale / 100.0;

  List<int> _simulateScore(Team home, Team away) {
    final hs = home.pitchStrength(home.startingPlayers) + homeAdvantage(home);
    final aws = away.pitchStrength(away.startingPlayers);
    final l = lambdasFrom(hs, aws, Tactic.neutro, Tactic.neutro);
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

  /// Duração (em rodadas, +1 da rodada atual) de uma lesão. O DM encurta.
  int rollInjury(Team t) => max(1, 1 + _rng.nextInt(4) - t.medicalLevel) + 1;

  void _randomInjury(Team t) {
    final starters = t.startingPlayers;
    if (starters.isEmpty) return;
    if (_rng.nextDouble() >= 0.15 * (1 - 0.2 * t.medicalLevel)) return;
    final p = starters[_rng.nextInt(starters.length)];
    p.injuredRounds = rollInjury(t);
    if (t.id == userTeamId) {
      _addNews('🚑 ${p.name} se lesionou e desfalca o time por ${p.injuredRounds - 1} rodada(s).');
    }
  }

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
    final l = lambdasFrom(homeStrength, awayStrength, homeTactic, awayTactic);
    final home = teamById(match.homeId);
    final away = teamById(match.awayId);
    final events = <MatchEvent>[];
    if (homeOnPitch.isEmpty || awayOnPitch.isEmpty) return events;
    for (int min = minFrom; min < minTo; min++) {
      if (_rng.nextDouble() < l[0] / 90.0) {
        final s = pickScorer(homeOnPitch);
        events.add(MatchEvent(minute: min, type: 'GOAL', teamId: home.id, playerId: s.id, text: "⚽ GOL do ${home.name}! ${s.name} marca aos $min'!"));
      }
      if (_rng.nextDouble() < l[1] / 90.0) {
        final s = pickScorer(awayOnPitch);
        events.add(MatchEvent(minute: min, type: 'GOAL', teamId: away.id, playerId: s.id, text: "⚽ GOL do ${away.name}! ${s.name} marca aos $min'!"));
      }
      if (_rng.nextDouble() < 0.05) {
        final bool h = _rng.nextBool();
        final t = h ? home : away;
        final p = pickScorer(h ? homeOnPitch : awayOnPitch);
        events.add(MatchEvent(minute: min, type: 'CHANCE', teamId: t.id, playerId: p.id, text: "🔥 Chance do ${t.name}: ${p.name} finaliza e o goleiro salva!"));
      }
      if (_rng.nextDouble() < 0.012) {
        final bool h = _rng.nextBool();
        final t = h ? home : away;
        final list = h ? homeOnPitch : awayOnPitch;
        final p = list[_rng.nextInt(list.length)];
        events.add(MatchEvent(minute: min, type: 'CARD', teamId: t.id, playerId: p.id, text: "🟨 Cartão amarelo para ${p.name} (${t.name})."));
      }
      final bool hInj = _rng.nextBool();
      final injTeam = hInj ? home : away;
      if (_rng.nextDouble() < 0.0035 * (1 - 0.2 * injTeam.medicalLevel)) {
        final list = hInj ? homeOnPitch : awayOnPitch;
        final p = list[_rng.nextInt(list.length)];
        events.add(MatchEvent(minute: min, type: 'INJURY', teamId: injTeam.id, playerId: p.id, text: "🚑 ${p.name} (${injTeam.name}) sente lesão e não tem condições de seguir."));
      }
    }
    return events;
  }

  Player pickScorer(List<Player> onPitch) {
    final att = onPitch.where((p) => p.position == 'ATA' || p.position == 'MEI').toList();
    final pool = att.isEmpty ? List<Player>.from(onPitch) : att;
    pool.sort((a, b) => b.overall.compareTo(a.overall));
    final n = pool.length < 5 ? pool.length : 5;
    return pool[_rng.nextInt(n)];
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
