part of 'engine.dart';

/// Técnico disponível para contratação no Modo Presidente.
class CoachOption {
  final String name;
  final int rating;
  final int wage;
  const CoachOption(this.name, this.rating, this.wage);
}

/// Fase 10B — Modo Presidente: popularidade, mandato, eleição, crises,
/// escolha do técnico e patrimônio do clube.
extension GamePresident on GameState {
  void startPresident(String teamId, {String name = 'Presidente', int difficulty = 1}) {
    mode = GameMode.presidente;
    _newWorld();
    this.difficulty = difficulty;
    userTeamId = teamId;
    final t = userTeam!;
    _applyDifficultyBudget(t);
    _refreshAcademy();
    final n = name.trim().isEmpty ? 'Presidente' : name.trim();
    career = CoachCareer(name: n, reputation: startingReputation(t.stars));
    career.log.add('$seasonYear: eleito presidente do ${t.name}.');
    president = PresidentState(mandateStart: seasonYear);
    president!.patrimonyHistory.add(patrimony(t));
    _aiListPlayers();
    _addNews('🏛️ ${career.name} toma posse como presidente do ${t.name} (mandato até ${president!.mandateEnd}).');
    _changed();
  }

  void _presidentAfterMatch(int gf, int ga) {
    final p = president;
    if (p == null) return;
    final delta = gf > ga ? 2 : (gf == ga ? 0 : -2);
    p.popularity = (p.popularity + delta).clamp(0, 100).toInt();
  }

  void _onUserSigning(Player player) {
    final t = userTeam;
    if (mode != GameMode.presidente || t == null) return;
    if (player.overall >= t.averageOverall + 4) {
      president!.promiseSeason = 0;
      president!.popularity = (president!.popularity + 3).clamp(0, 100).toInt();
      _addNews('🎉 A torcida festeja a contratação de ${player.name}.');
    }
  }

  void _onUserSale(Player player) {
    final t = userTeam;
    if (mode != GameMode.presidente || t == null) return;
    if (player.overall >= t.averageOverall + 4) {
      president!.popularity = (president!.popularity - 3).clamp(0, 100).toInt();
      _addNews('😠 Parte da torcida critica a venda de ${player.name}.');
    }
  }

  /// Técnicos livres (reais e fictícios) com salário pedido.
  List<CoachOption> availableCoaches() {
    final t = userTeam;
    if (t == null) return const [];
    final busy = allTeams.map((x) => x.coach).toSet();
    final list = <CoachOption>[
      for (final (name, rating) in kCoachPool)
        if (!busy.contains(name)) CoachOption(name, rating, coachSalary(t.stars, rating * 20)),
    ]..sort((a, b) => b.rating.compareTo(a.rating));
    return list;
  }

  int coachFireCost(Team t) => t.coachWage * 3;

  TransferResult hireCoach(CoachOption c) {
    final t = userTeam;
    if (t == null || mode != GameMode.presidente) {
      return const TransferResult(false, 'Só o presidente contrata técnicos.');
    }
    final cost = coachFireCost(t);
    if (t.balance < cost) {
      return TransferResult(false, 'Caixa insuficiente para a multa do técnico atual (${formatMoney(cost)}).');
    }
    final old = t.coach;
    _debit(t, cost, 'Comissão técnica', 'Rescisão com $old');
    t
      ..coach = c.name
      ..coachRating = c.rating
      ..coachWage = c.wage;
    final p = president!;
    final pos = userPosition;
    p.popularity = (p.popularity + (pos >= 12 || t.fanMorale < 50 ? 5 : -2)).clamp(0, 100).toInt();
    _addNews('🔄 ${t.name} demite $old e anuncia ${c.name} como novo técnico.');
    _changed();
    return TransferResult(true, '${c.name} é o novo técnico (${'★' * c.rating}).');
  }

  /// Uma vez por "mês" a torcida/imprensa cobra uma decisão do presidente.
  void _presidentDaily(int finishedDay) {
    final p = president;
    final t = userTeam;
    if (p == null || t == null) {
      if (career.offers.length < 3 && _rng.nextDouble() < 0.3) _generateJobOffers(1);
      return;
    }
    if (finishedDay % 6 != 3 || p.pending.length >= 2) return;
    final pos = userPosition;
    final events = <CrisisEvent>[];
    if (t.fanMorale < 50 || pos >= 15) {
      events.add(CrisisEvent(
        kind: 'demitir',
        title: 'Torcida pede a cabeça do técnico',
        text: 'Faixas no CT exigem a saída de ${t.coach}. O que você faz?',
        options: ['Demitir e contratar outro técnico', 'Bancar o técnico publicamente'],
      ));
    }
    if (t.balance < 0) {
      events.add(CrisisEvent(
        kind: 'divida',
        title: 'Crise financeira',
        text: 'O caixa está negativo (${formatMoney(t.balance)}). Um banco oferece um empréstimo.',
        options: ['Pegar R\$ 20 mi emprestados (juros de 30%)', 'Cortar custos: atrasar premiações'],
      ));
    }
    events.add(CrisisEvent(
      kind: 'reforco',
      title: 'Torcida quer reforço de peso',
      text: 'Organizadas cobram uma contratação de impacto para a sequência da temporada.',
      options: ['Prometer reforço (vá ao Mercado)', 'Dizer que o caixa não permite'],
    ));
    final naming = roundTo(t.sponsorMonthly * 3, 100000);
    events.add(CrisisEvent(
      kind: 'naming',
      title: 'Proposta de naming rights',
      text: 'Uma empresa oferece ${formatMoney(naming)} para colocar o nome dela no estádio ${t.stadium}.',
      options: ['Aceitar o dinheiro', 'Recusar e preservar a tradição'],
    ));
    events.add(CrisisEvent(
      kind: 'ingresso',
      title: 'Preço dos ingressos',
      text: 'Movimentos de torcedores pedem ingressos mais baratos no próximo jogo.',
      options: ['Fazer promoção (perde ${formatMoney(_ticketPromoCost(t))} de renda)', 'Manter os preços'],
    ));
    if (_rng.nextDouble() < 0.6 || events.first.kind == 'demitir' || events.first.kind == 'divida') {
      final e = events.first.kind == 'demitir' || events.first.kind == 'divida'
          ? events.first
          : events[_rng.nextInt(events.length)];
      p.pending.add(e);
      _addNews('🏛️ ${e.title}: decisão pendente na Presidência.');
    }
  }

  int _ticketPromoCost(Team t) => (attendance(t, positionOf(t.id)) * ticketPrice(t) * 0.4).round();

  /// Responde a uma crise. Retorna o efeito para mostrar ao usuário.
  TransferResult resolveCrisis(CrisisEvent e, int option) {
    final p = president;
    final t = userTeam;
    if (p == null || t == null) return const TransferResult(false, 'Sem mandato ativo.');
    p.pending.remove(e);
    String msg;
    int pop = 0;
    switch (e.kind) {
      case 'demitir':
        if (option == 0) {
          final coaches = availableCoaches();
          if (coaches.isEmpty) {
            msg = 'Não há técnicos livres no momento.';
          } else {
            final best = coaches.where((c) => c.wage <= t.coachWage * 2).firstOrNull ?? coaches.last;
            final r = hireCoach(best);
            msg = r.message;
            pop = 4;
          }
        } else {
          pop = t.fanMorale < 40 ? -6 : -2;
          msg = 'Você bancou ${t.coach}. A torcida não gostou.';
        }
      case 'divida':
        if (option == 0) {
          _credit(t, 20000000, 'Empréstimos', 'Empréstimo bancário');
          p.debt += 26000000;
          msg = 'Entraram R\$ 20 mi. Serão cobrados R\$ 26 mi no fim da temporada.';
          pop = -2;
        } else {
          for (final pl in t.squad) {
            pl.morale = (pl.morale - 8).clamp(0, 100).toInt();
          }
          msg = 'Custos cortados: o elenco ficou insatisfeito.';
          pop = -3;
        }
      case 'reforco':
        if (option == 0) {
          pop = 3;
          p.promiseSeason = seasonYear;
          msg = 'Promessa feita! Contrate alguém forte até o fim da temporada ou a torcida vai cobrar.';
        } else {
          pop = -4;
          msg = 'A torcida entendeu, mas não gostou.';
        }
      case 'naming':
        if (option == 0) {
          final value = roundTo(t.sponsorMonthly * 3, 100000);
          _credit(t, value, 'Patrocínio', 'Naming rights do estádio');
          pop = -5;
          msg = 'Entraram ${formatMoney(value)}. Os tradicionalistas reclamaram.';
        } else {
          pop = 3;
          msg = 'A torcida aplaude a decisão.';
        }
      case 'ingresso':
        if (option == 0) {
          _debit(t, _ticketPromoCost(t), 'Bilheteria', 'Promoção de ingressos');
          t.fanMorale = (t.fanMorale + 8).clamp(0, 100).toInt();
          pop = 5;
          msg = 'Estádio cheio e torcida feliz.';
        } else {
          pop = -2;
          msg = 'Preços mantidos.';
        }
      default:
        msg = 'Decisão registrada.';
    }
    p.popularity = (p.popularity + pop).clamp(0, 100).toInt();
    _changed();
    return TransferResult(pop >= 0, '$msg (popularidade ${pop >= 0 ? '+' : ''}$pop)');
  }

  void _presidentSeasonClose(int? upos) {
    final p = president;
    final t = userTeam;
    if (p == null || t == null) {
      if (career.offers.isEmpty) _generateJobOffers(2);
      return;
    }
    if (p.debt > 0) {
      _debit(t, p.debt, 'Empréstimos', 'Pagamento do empréstimo + juros');
      p.debt = 0;
    }
    if (p.promiseSeason == seasonYear) {
      p.popularity = (p.popularity - 5).clamp(0, 100).toInt();
    }
    final next = pendingDivisions[t.id];
    if (next != null) {
      p.popularity = (p.popularity + (next < t.division ? 15 : -25)).clamp(0, 100).toInt();
    }
    final value = patrimony(t);
    final prev = p.patrimonyHistory.isEmpty ? value : p.patrimonyHistory.last;
    p.patrimonyHistory.add(value);
    p.popularity = (p.popularity + (value > prev ? 4 : -4)).clamp(0, 100).toInt();
    career.log.add('$seasonYear: ${upos ?? '-'}º lugar, patrimônio ${formatMoney(value)}, popularidade ${p.popularity}%.');

    if (seasonYear >= p.mandateEnd) {
      final chance = (p.popularity / 100).clamp(0.1, 0.95);
      p.elections++;
      if (_rng.nextDouble() < chance) {
        p
          ..mandateStart = seasonYear + 1
          ..popularity = max(p.popularity, 50);
        career.reputation = (career.reputation + 5).clamp(0, 100).toInt();
        career.log.add('$seasonYear: reeleito presidente do ${t.name} até ${p.mandateEnd}.');
        _addNews('🗳️ Reeleito! ${career.name} comanda o ${t.name} até ${p.mandateEnd}.');
      } else {
        career.log.add('$seasonYear: perdeu a eleição no ${t.name}.');
        _addNews('🗳️ Derrota na eleição: ${career.name} deixa a presidência do ${t.name}.');
        president = null;
        _leaveClub(fired: true, reason: 'após perder a eleição');
      }
    }
  }

  void _presidentSeasonStart() {
    final p = president;
    final t = userTeam;
    if (p == null || t == null) return;
    p.pending.clear();
    _addNews('📅 Temporada $seasonYear: mandato até ${p.mandateEnd}, popularidade ${p.popularity}%.');
  }
}
