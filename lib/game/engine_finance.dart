part of 'engine.dart';

/// Fase 8 — Finanças.
extension GameFinance on GameState {
  void _credit(Team t, int amount, String category, String description) {
    t.balance += amount;
    if (isHumanTeam(t.id) && managesClub && amount != 0) {
      ledger.add(FinanceEntry(
        teamId: t.id,
        season: seasonYear,
        round: min(currentDay, max(1, totalDays)),
        category: category,
        description: description,
        amount: amount,
      ));
    }
  }

  void _debit(Team t, int amount, String category, String description) =>
      _credit(t, -amount, category, description);

  void _matchFinances(Match m, Team home, Team away, int hg, int ag) {
    if (!home.isForeign) {
      final raw = attendance(home, positionOf(home.id), bigGame: !m.isLeague && m.stage != 'G');
      final crowd = min(home.effectiveCapacity, (raw * ticketDemand(home)).round());
      _credit(home, crowd * ticketPriceFor(home), 'Bilheteria',
          'Bilheteria vs ${away.name} ($crowd pagantes)');
      final rec = clubRecords[home.id];
      if (home.id == userTeamId && (rec == null || crowd > rec.bestCrowd)) {
        (clubRecords[home.id] ??= ClubRecord()).bestCrowd = crowd;
      }
    }
    if (!m.isLeague) {
      _cupMatchPrizes(m, home, away, hg, ag);
      return;
    }
    if (home.isForeign) return;
    final div = home.division;
    if (hg > ag) {
      _credit(home, winBonus(div), 'Premiação', 'Vitória sobre ${away.name}');
    } else if (hg < ag) {
      _credit(away, winBonus(div), 'Premiação', 'Vitória sobre ${home.name}');
    } else {
      _credit(home, drawBonus(div), 'Premiação', 'Empate com ${away.name}');
      _credit(away, drawBonus(div), 'Premiação', 'Empate com ${home.name}');
    }
  }

  /// Copas: cota por jogo na fase de grupos continental e bicho por vitória em todas as copas.
  void _cupMatchPrizes(Match m, Team home, Team away, int hg, int ag) {
    final continental = (m.comp == 'LIB' || m.comp == 'SUL') && m.stage == 'G';
    if (continental) {
      for (final t in [home, away]) {
        if (!t.isForeign) _credit(t, cupPrize(m.comp, 'G') ~/ 6, 'Premiação', '${compName(m.comp)}: cota por jogo da fase de grupos');
      }
    }
    final winner = hg > ag ? home : (ag > hg ? away : null);
    if (winner != null && !winner.isForeign) {
      final loser = winner == home ? away : home;
      final bonus = continental ? (m.comp == 'LIB' ? 1500000 : 500000) : winBonus(winner.division);
      _credit(winner, bonus, 'Premiação', 'Vitória sobre ${loser.name} (${compName(m.comp)})');
    } else if (winner == null && m.stage == 'G') {
      for (final t in [home, away]) {
        if (!t.isForeign) _credit(t, drawBonus(t.division), 'Premiação', 'Empate (${compName(m.comp)})');
      }
    }
  }

  /// Ao fim do 1º turno (rodada 19), 40% da premiação por posição já entra no caixa.
  void _midSeasonPrizes(int finished) {
    final day = stageDays['WIN:2:start'];
    if (day == null || finished != day || stageDays['PAID:MID'] == 1) return;
    stageDays['PAID:MID'] = 1;
    for (int div = 1; div <= 3; div++) {
      final table = standingsOf(div);
      for (int i = 0; i < table.length; i++) {
        _credit(table[i], (positionPrize(i + 1, division: div) * 0.4).round(), 'Premiação',
            'Premiação do 1º turno: ${i + 1}º lugar na ${compName(divisionComp(div))}');
      }
    }
    if (managesClub && userTeam != null) _addNews('💰 Premiação do 1º turno depositada no caixa!');
  }

  void _monthlyFinances(int month) {
    for (final t in teams) {
      final hi = humans.isEmpty ? null : _humanIndexOf(t.id);
      if (hi != null) {
        _withHuman(hi, () => _monthlyTeam(t, month));
      } else {
        _monthlyTeam(t, month);
      }
    }
    if (mode == GameMode.jogador) _playerPayday();
  }

  void _monthlyTeam(Team t, int month) {
    {
      final isUser = t.id == userTeamId;
      _debit(t, t.payroll, 'Salários', 'Folha salarial (mês $month)');
      if (t.sponsorsManaged) {
        for (final d in t.sponsors) {
          _credit(t, d.monthly, 'Patrocínio', '${d.company} – ${kSponsorSlots[d.slot]?.$1 ?? d.slot} (mês $month)');
        }
      } else {
        _credit(t, t.sponsorMonthly, 'Patrocínio', 'Patrocínio master (mês $month)');
      }
      _credit(t, tvRights(t), 'Cotas de TV', 'Direitos de transmissão (mês $month)');
      _debit(t, monthlyMaintenance(t), 'Estrutura', 'Manutenção de CT, estádio e DM');
      final coachPay = isUser && mode == GameMode.tecnico ? career.salary : t.coachWage;
      _debit(t, coachPay, 'Comissão técnica', 'Salário do técnico');
      if (isUser && mode == GameMode.tecnico) career.earnings += career.salary;
      if (isUser && managesClub) {
        if (staffPayroll > 0) _debit(t, staffPayroll, 'Comissão técnica', 'Salários da comissão (auxiliar, preparador, olheiro)');
        members = expectedMembers(t);
        _credit(t, members * memberPrice, 'Sócio-torcedor', '$members sócios × ${formatMoney(memberPrice)}');
      }
      if (t.balance < 0) {
        _debit(t, (t.balance.abs() * 0.02).round(), 'Multas', 'Juros e multas por salários atrasados');
        for (final p in t.squad) {
          p.morale = (p.morale - 5).clamp(0, 100).toInt();
        }
        t.fanMorale = (t.fanMorale - 3).clamp(0, 100).toInt();
        if (isUser && managesClub) {
          if (mode == GameMode.tecnico) {
            career.boardConfidence = (career.boardConfidence - 5).clamp(0, 100).toInt();
          } else {
            president!.popularity = (president!.popularity - 3).clamp(0, 100).toInt();
          }
          _addNews('⚠️ Caixa negativo! Salários atrasados derrubam a moral do elenco.');
        }
      }
    }
  }

  TransferResult upgradeFacility(Facility f) {
    final t = userTeam;
    if (t == null || !managesClub) return const TransferResult(false, 'Você não administra um clube.');
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
    if (mode == GameMode.presidente) {
      president!.popularity = (president!.popularity + 4).clamp(0, 100).toInt();
    }
    _changed();
    return TransferResult(true, '${f.label} agora está no nível ${level + 1}.');
  }

  TransferResult renegotiateSponsor() {
    final t = userTeam;
    if (t == null || !managesClub) return const TransferResult(false, 'Você não administra um clube.');
    if (t.sponsorRenegotiatedSeason == seasonYear) {
      return const TransferResult(false, 'O patrocínio já foi renegociado nesta temporada.');
    }
    t.sponsorRenegotiatedSeason = seasonYear;
    final pos = userPosition;
    double chance = 0.35 + (t.fanMorale - 50) / 200.0;
    if (pos > 0 && pos <= 6) chance += 0.15;
    if (pos >= 17) chance -= 0.2;
    String msg;
    final ok = _rng.nextDouble() < chance;
    if (ok) {
      final inc = 0.10 + _rng.nextDouble() * 0.15;
      final master = sponsorIn(t, 'master');
      if (master != null) master.monthly = roundTo(master.monthly * (1 + inc), 10000);
      t.sponsorMonthly = master != null ? sponsorTotal(t) : roundTo(t.sponsorMonthly * (1 + inc), 10000);
      msg = 'Novo contrato: ${formatMoney(t.sponsorMonthly)}/mês (+${(inc * 100).round()}%).';
      _addNews('🤝 ${t.name} renova patrocínio master por ${formatMoney(t.sponsorMonthly)}/mês.');
    } else {
      msg = 'O patrocinador manteve ${formatMoney(t.sponsorMonthly)}/mês. Tente na próxima temporada.';
    }
    _changed();
    return TransferResult(ok, msg);
  }

  /// Patrimônio do clube: elenco + caixa + estruturas (Fase 10B).
  int patrimony(Team t) {
    int facilities = 0;
    for (final f in Facility.values) {
      for (int l = 1; l <= f.levelOf(t); l++) {
        facilities += facilityCost(l);
      }
    }
    return t.squad.fold<int>(0, (s, p) => s + p.marketValue) + t.balance + facilities;
  }
}
