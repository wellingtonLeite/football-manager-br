part of 'engine.dart';

const Map<String, String> kTrainingFocus = {
  'equilibrado': '⚖️ Equilibrado — evolução normal',
  'fisico': '🏃 Físico — recupera mais energia',
  'tecnico': '🎯 Técnico — +25% de experiência',
  'finalizacao': '⚽ Finalização — o time marca mais',
  'defesa': '🧱 Defesa — o time sofre menos',
  'tatico': '📋 Tático — +1 de força em campo',
};

const Map<String, String> kTrainingIntensity = {
  'leve': 'Leve: menos lesões e cansaço, menos evolução',
  'normal': 'Normal',
  'intensa': 'Intensa: +40% de evolução, mais lesões e cansaço',
};

/// Comissão técnica contratável: (chave, nome, emoji, efeito por nível).
const List<(String, String, String, String)> kStaffRoles = [
  ('auxiliar', 'Auxiliar técnico', '🧠', '+0,4 de força em campo por nível'),
  ('preparador', 'Preparador físico', '🏃', '+4 de energia recuperada por dia, por nível'),
  ('olheiro', 'Olheiro-chefe', '🔭', 'revela o potencial de mais jogadores por dia'),
  ('marketing', 'Diretor de marketing', '📣', 'traz mais propostas de patrocínio, e mais valiosas'),
];

/// Fase extra — treino, comissão técnica, categorias de base, olheiros,
/// preço de ingressos e sócio-torcedor.
extension GameClub on GameState {
  /// Bônus de força: auxiliar, treino tático e nível de dificuldade.
  double staffBonus(Team t) {
    final c = _settingsFor(t);
    if (c == null) return 0;
    final diff = const [2.0, 0.0, -2.0][difficulty.clamp(0, 2)];
    return 0.4 * (c.staff['auxiliar'] ?? 0) + (c.trainingFocus == 'tatico' ? 1.0 : 0) + diff;
  }

  double trainingAttack(Team t) => _settingsFor(t)?.trainingFocus == 'finalizacao' ? 0.12 : 0;

  double trainingDefense(Team t) => _settingsFor(t)?.trainingFocus == 'defesa' ? 0.12 : 0;

  void setFormation(Formation f) {
    final t = userTeam;
    if (t == null) return;
    t.formation = f;
    // Mantém os titulares que cabem no novo esquema (respeitando a cota de cada posição)
    final used = <String, int>{};
    final keep = <String>[];
    for (final id in t.startingIds) {
      final p = t.findPlayer(id);
      if (p == null) continue;
      final n = used[p.position] ?? 0;
      if (n < (f.quota[p.position] ?? 0)) {
        keep.add(id);
        used[p.position] = n + 1;
      }
    }
    t.startingIds = _fillLineup(t, keep);
    _changed();
  }

  void setTraining({String? focus, String? intensity}) {
    if (focus != null && kTrainingFocus.containsKey(focus)) trainingFocus = focus;
    if (intensity != null && kTrainingIntensity.containsKey(intensity)) trainingIntensity = intensity;
    _changed();
  }

  int staffWage(int level) => const [0, 60000, 150000, 300000][level.clamp(0, 3)];

  int get staffPayroll => staff.values.fold(0, (s, l) => s + staffWage(l));

  TransferResult hireStaff(String role) {
    final t = userTeam;
    if (t == null || !managesClub) return const TransferResult(false, 'Você não administra um clube.');
    final level = staff[role] ?? 0;
    if (level >= 3) return const TransferResult(false, 'Já é o melhor profissional disponível.');
    final signing = staffWage(level + 1) * 3;
    if (t.balance < signing) return TransferResult(false, 'Caixa insuficiente: a contratação custa ${formatMoney(signing)}.');
    _debit(t, signing, 'Comissão técnica', 'Contratação: ${kStaffRoles.firstWhere((r) => r.$1 == role).$2} nível ${level + 1}');
    staff[role] = level + 1;
    _changed();
    return TransferResult(true, 'Contratado! Salário de ${formatMoney(staffWage(level + 1))}/mês.');
  }

  /// Rotina diária do clube do usuário: treino, base e olheiros.
  void _clubDaily() {
    final t = userTeam;
    if (t == null || !managesClub) return;
    final mult = const {'leve': 0.7, 'normal': 1.0, 'intensa': 1.4}[trainingIntensity] ?? 1.0;
    final tech = trainingFocus == 'tecnico' ? 1.25 : 1.0;
    final xp = (2 * mult * tech).round();
    for (final p in t.squad) {
      if (p.injured) continue;
      final msgs = p.gainXp(xp);
      for (final m in msgs) {
        _addNews('📈 Treino: $m');
      }
      p.energy = (p.energy + (staff['preparador'] ?? 0) * 4 + (trainingFocus == 'fisico' ? 5 : 0)
              - (trainingIntensity == 'intensa' ? 5 : 0) + (trainingIntensity == 'leve' ? 3 : 0))
          .clamp(0, 100)
          .toInt();
      if (trainingIntensity == 'intensa' && _rng.nextDouble() < 0.003) {
        p.injuredRounds = rollInjury(t);
        _addNews('🚑 ${p.name} se machucou no treino intenso.');
      }
    }
    for (final y in academy) {
      y.gainXp(2 + t.ctLevel);
    }
    _scoutDaily();
    _marketingDaily();
  }

  // ---------------------------------------------------------------------------
  // Categorias de base
  // ---------------------------------------------------------------------------

  /// Novos garotos chegam à base a cada temporada (o CT melhora a qualidade).
  void _refreshAcademy() {
    final t = userTeam;
    if (t == null || !managesClub) return;
    for (final y in academy) {
      y.age++;
    }
    final leaving = academy.where((y) => y.age >= 20).toList();
    for (final y in leaving) {
      academy.remove(y);
      _addNews('🎓 ${y.name} completou 20 anos sem subir e deixou a base.');
    }
    for (int i = 0; i < 4 && academy.length < 10; i++) {
      final pos = kPositions[_rng.nextInt(kPositions.length)];
      final y = generatePlayer(_rng, id: newPlayerId(_rng), position: pos, base: t.baseOverall - 14 + 2 * t.ctLevel, minAge: 15, maxAge: 16)
        ..contractYears = 3;
      y.potential = min(93, y.overall + 8 + _rng.nextInt(16) + 2 * t.ctLevel);
      academy.add(y);
      scouted.add(y.id);
    }
  }

  TransferResult promoteYouth(String id) {
    final t = userTeam;
    final y = academy.where((p) => p.id == id).firstOrNull;
    if (t == null || y == null) return const TransferResult(false, 'Jogador não encontrado.');
    if (t.squad.length >= GameState.maxSquadSize) return const TransferResult(false, 'Elenco cheio.');
    academy.remove(y);
    y
      ..contractYears = 3
      ..wage = fairWageFor(t, y);
    t.squad.add(y);
    _addNews('🌱 ${y.name} (${y.age} anos) sobe da base para o profissional!');
    _changed();
    return TransferResult(true, '${y.name} agora é do elenco principal.');
  }

  void releaseYouth(String id) {
    academy.removeWhere((p) => p.id == id);
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Olheiros
  // ---------------------------------------------------------------------------

  /// Regiões que o olheiro pode observar.
  List<(String, String)> get scoutRegions => [
        ('BRA', 'Brasil (Séries A–D)'),
        ('FA', 'Agentes livres'),
        for (final e in kLeagueNames.entries) (e.key, e.value),
        ('AME', 'América do Sul (copas)'),
      ];

  void setScoutRegion(String r) {
    scoutRegion = r;
    _changed();
  }

  Iterable<Player> _regionPlayers(String r) {
    if (r == 'FA') return freeAgents;
    if (r == 'BRA') return teams.where((t) => t.id != userTeamId).expand((t) => t.squad);
    if (r == 'AME') return foreignTeams.where((t) => t.league.isEmpty).expand((t) => t.squad);
    return foreignTeams.where((t) => t.league == r).expand((t) => t.squad);
  }

  void _scoutDaily() {
    final level = staff['olheiro'] ?? 0;
    final pool = _regionPlayers(scoutRegion).where((p) => !scouted.contains(p.id)).toList();
    if (pool.isEmpty) return;
    pool.shuffle(_rng);
    final found = pool.take(2 + 4 * level).toList();
    scouted.addAll(found.map((p) => p.id));
    found.sort((a, b) => (b.potential - b.overall).compareTo(a.potential - a.overall));
    final gem = found.first;
    if (gem.potential - gem.overall >= 10 && gem.age <= 21) {
      final club = ownerOf(gem.id)?.name ?? 'sem clube';
      _addNews('🔭 Olheiro: ${gem.name} (${gem.age} anos, ${gem.position}, $club) pode chegar a ${gem.potential}!');
    }
  }

  bool isScouted(Player p) => scouted.contains(p.id) || (userTeam?.findPlayer(p.id) != null);

  TransferResult scoutPlayer(String id) {
    final t = userTeam;
    if (t == null) return const TransferResult(false, 'Você não administra um clube.');
    if (scouted.contains(id)) return const TransferResult(false, 'Jogador já observado.');
    const cost = 50000;
    if (t.balance < cost) return const TransferResult(false, 'Caixa insuficiente.');
    _debit(t, cost, 'Comissão técnica', 'Observação de jogador');
    scouted.add(id);
    _changed();
    return const TransferResult(true, 'Relatório pronto: potencial revelado.');
  }

  // ---------------------------------------------------------------------------
  // Ingressos e sócio-torcedor
  // ---------------------------------------------------------------------------

  void setTicketMultiplier(double m) {
    ticketMultiplier = m.clamp(0.5, 2.0).toDouble();
    _changed();
  }

  void setMemberPrice(int price) {
    memberPrice = price.clamp(10, 200).toInt();
    _changed();
  }

  /// Sócios que o plano atrai (torcida, tamanho do clube e preço).
  int expectedMembers(Team t) {
    final base = t.effectiveCapacity * (0.10 + t.fanMorale / 300.0) * (0.6 + 0.15 * t.stars);
    final elasticity = pow(40 / memberPrice.clamp(10, 200), 0.8);
    return (base * elasticity).round();
  }

  /// Ajuste do público pelo preço do ingresso do usuário (preço alto, menos gente).
  double ticketDemand(Team t) {
    final c = _settingsFor(t);
    return c == null ? 1.0 : pow(1 / c.ticketMultiplier, 0.7).toDouble();
  }

  int ticketPriceFor(Team t) => (ticketPrice(t) * (_settingsFor(t)?.ticketMultiplier ?? 1.0)).round();
}
