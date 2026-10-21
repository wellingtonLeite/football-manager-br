part of 'engine.dart';

/// Fase 10A — Carreira do técnico (e convites, usados também pelo presidente).
extension GameCareer on GameState {
  void _updateBoardConfidence(int gf, int ga) {
    final t = userTeam;
    if (t == null) return;
    int delta = gf > ga ? 5 : (gf == ga ? 0 : -6);
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

  /// Escolhe um técnico livre para um clube da IA.
  (String, int) _randomCoach() {
    final busy = allTeams.map((t) => t.coach).toSet();
    final free = kCoachPool.where((c) => !busy.contains(c.$1)).toList();
    if (free.isEmpty) return (randomName(_rng), 2);
    return free[_rng.nextInt(free.length)];
  }

  void _replaceCoach(Team t) {
    final c = _randomCoach();
    t
      ..coach = c.$1
      ..coachRating = c.$2
      ..coachWage = coachSalary(t.stars, c.$2 * 20);
  }

  void _generateJobOffers(int count, {bool upgradeOnly = false}) {
    final current = userTeam;
    final table = <String, int>{for (final t in teams) t.id: positionOf(t.id)};
    final midSeason = currentDay > 1 && !seasonFinished;
    var cands = teams
        .where((t) =>
            t.id != userTeamId &&
            !isHumanTeam(t.id) &&
            requiredReputation(t.stars) <= career.reputation &&
            !career.offers.any((o) => o.teamId == t.id) &&
            (!upgradeOnly ||
                current == null ||
                t.division < current.division ||
                (t.division == current.division && t.stars > current.stars)))
        .toList()
      ..shuffle(_rng);
    if (midSeason) {
      final struggling = cands.where((t) => (table[t.id] ?? 0) >= 10).toList();
      if (struggling.isNotEmpty) cands = struggling;
    }
    for (final t in cands.take(count)) {
      if (career.offers.length >= 3) break;
      final pos = table[t.id] ?? 0;
      final goal = midSeason && pos >= 14 ? BoardGoal.naoCair : goalForTeam(t);
      career.offers.add(JobOffer(
        teamId: t.id,
        salary: coachSalary(t.stars, career.reputation),
        goal: goal,
      ));
      final role = mode == GameMode.presidente ? 'presidente' : 'técnico';
      _addNews('📨 Convite: o ${t.name} (${compName(divisionComp(t.division))}) quer ${career.name} como $role.');
    }
  }

  void acceptJobOffer(JobOffer o) {
    final t = _index[o.teamId];
    if (t == null) return;
    final old = userTeam;
    if (old != null) {
      if (mode == GameMode.tecnico) _replaceCoach(old);
      career.log.add('$seasonYear: deixou o ${old.name} para assumir o ${t.name}.');
    } else {
      career.log.add('$seasonYear: assumiu o ${t.name}.');
    }
    userTeamId = t.id;
    national = null;
    career.employed = true;
    career.offers.clear();
    incomingOffers.clear();
    ledger.clear();
    for (final p in t.squad) {
      p.listed = false;
      p.askingPrice = 0;
    }
    if (mode == GameMode.presidente) {
      president = PresidentState(mandateStart: seasonFinished ? seasonYear + 1 : seasonYear, popularity: 55);
      _addNews('🏛️ ${career.name} é eleito presidente do ${t.name}!');
    } else {
      t.coach = career.name;
      career
        ..salary = o.salary
        ..goal = o.goal
        ..boardConfidence = 60;
      t.startingIds = autoLineup(t);
      _addNews('👔 ${career.name} é o novo técnico do ${t.name}! Meta: ${o.goal.labelFor(t.division)}.');
    }
    _changed();
  }

  void rejectJobOffer(JobOffer o) {
    career.offers.remove(o);
    _changed();
  }

  void _leaveClub({required bool fired, required String reason}) {
    final t = userTeam;
    if (t == null) return;
    if (mode == GameMode.tecnico) _replaceCoach(t);
    career
      ..employed = false
      ..salary = 0
      ..reputation = (career.reputation - (fired ? 8 : 3)).clamp(0, 100).toInt();
    userTeamId = null;
    incomingOffers.clear();
    career.offers.clear();
    final role = mode == GameMode.presidente ? 'presidência' : 'comando';
    career.log.add(fired
        ? '$seasonYear: deixou o $role do ${t.name} $reason.'
        : '$seasonYear: pediu demissão do ${t.name} $reason.');
    _addNews(fired
        ? '🚨 ${career.name} deixa o $role do ${t.name} $reason.'
        : '👋 ${career.name} pediu demissão do ${t.name}.');
    _generateJobOffers(1 + _rng.nextInt(2));
  }

  void resign() {
    if (!career.employed) return;
    _leaveClub(fired: false, reason: seasonFinished ? 'ao fim da temporada' : 'na data $currentDay');
    _changed();
  }

  /// Rotina diária do Modo Técnico: demissão ou convites quando desempregado.
  void _careerDaily(int finishedDay) {
    final t = userTeam;
    if (career.employed && t != null) {
      if (t.played >= 6 && career.boardConfidence <= 15) {
        _leaveClub(fired: true, reason: 'após ${t.played} rodadas (demitido)');
      }
    } else if (career.offers.length < 3 && (career.offers.isEmpty || _rng.nextDouble() < 0.3)) {
      _generateJobOffers(1);
    }
  }

  void _careerSeasonClose(int? upos, bool? met) {
    final user = career.employed ? userTeam : null;
    if (user != null && upos != null) {
      int rep = career.reputation;
      if (upos <= 4) {
        rep += 4;
      } else if (upos >= 17) {
        rep -= 10;
      }
      final goal = career.goal.labelFor(user.division);
      if (met == true) {
        final bonus = career.salary * 3;
        career.earnings += bonus;
        rep += 5;
        career.boardConfidence = 70;
        career.log.add('$seasonYear: meta cumprida ($goal) com o ${user.name} — $uposº lugar.');
        _addNews('✅ Meta cumprida! Bônus de ${formatMoney(bonus)} e contrato renovado automaticamente.');
      } else {
        rep -= 3;
        career.log.add('$seasonYear: meta não cumprida ($goal) com o ${user.name} — $uposº lugar.');
      }
      career.reputation = rep.clamp(0, 100).toInt();
      if (met != true && upos > career.goal.maxPosition + 4) {
        _leaveClub(fired: true, reason: 'ao fim da temporada (demitido)');
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
      // A meta da próxima temporada considera a divisão em que o clube vai jogar
      final nextDivision = pendingDivisions[u.id] ?? u.division;
      final probe = Team(
        id: u.id, name: u.name, shortName: u.shortName, state: u.state, stadium: u.stadium,
        coach: u.coach, stars: u.stars, baseOverall: u.baseOverall, squad: const [],
        division: nextDivision,
      );
      career.goal = goalForTeam(probe);
      career.salary = max(career.salary, coachSalary(u.stars, career.reputation));
      if (_rng.nextDouble() < 0.5) _generateJobOffers(1, upgradeOnly: true);
    } else if (career.offers.isEmpty) {
      _generateJobOffers(2);
    }
  }
}
