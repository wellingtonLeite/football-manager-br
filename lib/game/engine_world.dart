part of 'engine.dart';

/// Conquistas: id → (emoji, título, descrição).
const Map<String, (String, String, String)> kAchievements = {
  'primeira_vitoria': ('🎉', 'Primeira vitória', 'Vença o primeiro jogo da carreira'),
  'dez_vitorias': ('🔟', 'Embalado', '10 vitórias na mesma temporada'),
  'estadual': ('🥇', 'Campeão estadual', 'Conquiste um estadual ou copa regional'),
  'acesso': ('⬆️', 'Acesso!', 'Suba de divisão'),
  'serie_a': ('🏆', 'Campeão brasileiro', 'Vença a Série A'),
  'copa_brasil': ('🏆', 'Copa do Brasil', 'Vença a Copa do Brasil'),
  'libertadores': ('🌎', 'Glória eterna', 'Vença a Libertadores'),
  'sul_americana': ('🌎', 'Sul-Americana', 'Vença a Sul-Americana'),
  'mundial': ('🌍', 'Campeão do mundo', 'Vença a Copa Intercontinental'),
  'goleada': ('💥', 'Goleada', 'Vença por 5 gols de diferença'),
  'craque': ('⭐', 'Contratação de peso', 'Contrate um jogador de overall 85+'),
  'venda_50': ('💸', 'Venda milionária', 'Venda um jogador por R\$ 50 mi ou mais'),
  'rico': ('🏦', 'Cofre cheio', 'Tenha R\$ 200 mi em caixa'),
  'estrutura': ('🏗️', 'Estrutura de ponta', 'Leve uma estrutura ao nível 3'),
  'tres_temporadas': ('📅', 'Longevidade', 'Complete 3 temporadas'),
  'reeleito': ('🗳️', 'Reeleito', 'Vença uma eleição como presidente'),
  'selecao_jogador': ('🇧🇷', 'Convocado', 'Seja convocado para a Seleção (Modo Jogador)'),
  'cem_gols': ('💯', 'Artilheiro histórico', '100 gols na carreira (Modo Jogador)'),
  'selecao_tecnico': ('🇧🇷', 'Técnico da Seleção', 'Assuma a Seleção Brasileira'),
  'copa_mundo': ('🏆', 'Campeão mundial', 'Vença a Copa do Mundo com a Seleção'),
};

/// Seleções adversárias e sua força (para amistosos, Eliminatórias e Copas).
const Map<String, int> kNations = {
  'Argentina': 86, 'França': 87, 'Espanha': 87, 'Inglaterra': 86, 'Alemanha': 84, 'Portugal': 85,
  'Holanda': 83, 'Bélgica': 81, 'Itália': 82, 'Croácia': 80, 'Uruguai': 80, 'Colômbia': 80,
  'Marrocos': 79, 'Japão': 78, 'Estados Unidos': 78, 'México': 77, 'Senegal': 77, 'Equador': 77,
  'Suíça': 78, 'Dinamarca': 78, 'Coreia do Sul': 76, 'Austrália': 74, 'Paraguai': 75, 'Chile': 74,
  'Peru': 72, 'Venezuela': 72, 'Bolívia': 68, 'Canadá': 75, 'Nigéria': 76, 'Egito': 74,
};

/// Seleção Brasileira comandada pelo usuário (Modo Técnico).
class NationalTeamState {
  final List<String> squad;
  int wins = 0, draws = 0, losses = 0, goalsFor = 0, goalsAgainst = 0;
  final List<String> log;
  NationalTeamState({List<String>? squad, List<String>? log})
      : squad = squad ?? [],
        log = log ?? [];

  Map<String, dynamic> toJson() =>
      {'sq': squad, 'w': wins, 'd': draws, 'l': losses, 'gf': goalsFor, 'ga': goalsAgainst, 'log': log};

  factory NationalTeamState.fromJson(Map<String, dynamic> j) =>
      NationalTeamState(squad: List<String>.from(j['sq'] ?? []), log: List<String>.from(j['log'] ?? []))
        ..wins = j['w'] ?? 0
        ..draws = j['d'] ?? 0
        ..losses = j['l'] ?? 0
        ..goalsFor = j['gf'] ?? 0
        ..goalsAgainst = j['ga'] ?? 0;
}

extension GameWorld on GameState {
  // ---------------------------------------------------------------------------
  // Janelas de transferência
  // ---------------------------------------------------------------------------

  /// Janela 1: pré-temporada (estaduais). Janela 2: meio da temporada.
  bool get transferWindowOpen {
    final w2s = stageDays['WIN:2:start'] ?? 0;
    final w2e = stageDays['WIN:2:end'] ?? 0;
    final w1e = stageDays['WIN:1:end'] ?? 14;
    return currentDay <= w1e || (currentDay >= w2s && currentDay <= w2e) || seasonFinished;
  }

  String get windowLabel {
    if (transferWindowOpen) {
      final end = currentDay <= (stageDays['WIN:1:end'] ?? 14) ? stageDays['WIN:1:end'] : stageDays['WIN:2:end'];
      return seasonFinished ? 'Janela aberta (pré-temporada)' : 'Janela aberta até a data ${end ?? '-'}';
    }
    final next = stageDays['WIN:2:start'] ?? 0;
    return next > currentDay ? 'Janela fechada: reabre na data $next' : 'Janela fechada até o fim da temporada';
  }

  /// Negócios entre clubes da IA (Brasil e exterior) durante as janelas.
  void _aiTransfers() {
    if (!transferWindowOpen || seasonFinished) return;
    final buyers = allTeams.where((t) => t.id != userTeamId && (t.league.isNotEmpty || !t.isForeign)).toList();
    for (int i = 0; i < 4; i++) {
      final buyer = buyers[_rng.nextInt(buyers.length)];
      final avg = buyer.averageOverall;
      final pool = allTeams.where((s) => s.id != buyer.id && s.id != userTeamId && s.baseOverall < buyer.baseOverall + 2 && s.squad.length > 20);
      final cands = <(Team, Player)>[];
      for (final s in pool) {
        for (final p in s.squad) {
          if (p.onLoan || p.id == playerCareer?.playerId) continue;
          if (p.overall >= avg + 1 && p.age <= 29) cands.add((s, p));
        }
      }
      if (cands.isEmpty) continue;
      final (seller, p) = cands[_rng.nextInt(cands.length)];
      final fee = roundTo(p.marketValue * (1.0 + _rng.nextDouble() * 0.3), 50000);
      if (buyer.balance < fee || buyer.squad.length >= GameState.maxSquadSize) continue;
      seller.squad.remove(p);
      seller.startingIds.remove(p.id);
      buyer.squad.add(p);
      buyer.balance -= fee;
      seller.balance += fee;
      p
        ..wage = max(p.wage, Player.fairWage(p.overall, p.age))
        ..contractYears = 2 + _rng.nextInt(3)
        ..listed = false;
      _settleSellOn(p, fee);
      final brazil = !seller.isForeign || !buyer.isForeign;
      if (brazil && (fee >= 10000000 || seller.division == 1)) {
        _addNews('🔁 Mercado: ${p.name} sai do ${seller.name} para o ${buyer.name} por ${formatMoney(fee)}.');
      } else if (fee >= 80000000) {
        _addNews('🌍 Mercado europeu: ${p.name} troca o ${seller.name} pelo ${buyer.name} (${formatMoney(fee)}).');
      }
    }
  }

  /// Cláusula de venda futura: se um ex-jogador do usuário for vendido, o clube recebe a parte.
  void _settleSellOn(Player p, int fee) {
    final clause = sellOnClauses.remove(p.id);
    if (clause == null) return;
    final t = _index[clause.$1];
    if (t == null) return;
    final share = (fee * clause.$2 / 100).round();
    _credit(t, share, 'Transferências', 'Cláusula de venda: ${clause.$2}% de ${p.name}');
    if (t.id == userTeamId) _addNews('💰 Cláusula de venda: ${p.name} foi revendido e o clube recebeu ${formatMoney(share)}.');
  }

  /// Exerce a opção de compra de um jogador emprestado.
  TransferResult exerciseLoanOption(String playerId) {
    final t = userTeam;
    final p = t?.findPlayer(playerId);
    final price = loanOptions[playerId];
    if (t == null || p == null || price == null || !p.onLoan) {
      return const TransferResult(false, 'Este empréstimo não tem opção de compra.');
    }
    if (t.balance < price) return TransferResult(false, 'Caixa insuficiente: a opção custa ${formatMoney(price)}.');
    final owner = _index[p.loanFromTeamId];
    _debit(t, price, 'Transferências', 'Opção de compra: ${p.name}');
    owner?.balance += price;
    p
      ..loanFromTeamId = null
      ..contractYears = max(p.contractYears, 3);
    loanOptions.remove(playerId);
    _addNews('✍️ ${t.name} exerce a opção de compra e fica com ${p.name} em definitivo.');
    _changed();
    return TransferResult(true, '${p.name} agora é do clube em definitivo.');
  }

  // ---------------------------------------------------------------------------
  // Seleção Brasileira (Modo Técnico)
  // ---------------------------------------------------------------------------

  bool get isNationalCoach => national != null;

  /// Melhores brasileiros disponíveis (todas as ligas), para a convocação.
  List<(Team, Player)> brazilianPool({int n = 60}) {
    final list = <(Team, Player)>[];
    for (final t in allTeams) {
      for (final p in t.squad) {
        if (p.nat == 'BRA') list.add((t, p));
      }
    }
    list.sort((a, b) => b.$2.overall.compareTo(a.$2.overall));
    return list.take(n).toList();
  }

  void _offerNationalTeam() {
    if (mode != GameMode.tecnico || isNationalCoach || nationalOffer) return;
    if (career.reputation >= 85 || (career.trophies.length >= 3 && career.reputation >= 75)) {
      nationalOffer = true;
      _addNews('🇧🇷 A CBF quer ${career.name} como técnico da Seleção Brasileira! Veja em Carreira.');
    }
  }

  void acceptNationalTeam() {
    if (!nationalOffer) return;
    nationalOffer = false;
    final old = userTeam;
    if (old != null) {
      _replaceCoach(old);
      career.log.add('$seasonYear: deixou o ${old.name} para assumir a Seleção Brasileira.');
    }
    userTeamId = null;
    career.employed = false;
    career.salary = 2500000;
    national = NationalTeamState(squad: brazilianPool(n: 23).map((e) => e.$2.id).toList());
    career.log.add('$seasonYear: assumiu a Seleção Brasileira.');
    _addNews('🇧🇷 ${career.name} é o novo técnico da Seleção Brasileira!');
    _unlock('selecao_tecnico');
    _changed();
  }

  void declineNationalTeam() {
    nationalOffer = false;
    _changed();
  }

  void setNationalSquad(List<String> ids) {
    if (national == null) return;
    national!.squad
      ..clear()
      ..addAll(ids.take(26));
    _changed();
  }

  double _nationalStrength() {
    final n = national;
    if (n == null) return 80;
    final players = <Player>[];
    for (final id in n.squad) {
      final t = ownerOf(id) ?? foreignTeams.where((x) => x.findPlayer(id) != null).firstOrNull;
      final p = t?.findPlayer(id);
      if (p != null && !p.injured) players.add(p);
    }
    if (players.isEmpty) return 75;
    players.sort((a, b) => b.overall.compareTo(a.overall));
    final xi = players.take(11).toList();
    return xi.fold<double>(0, (s, p) => s + p.overall) / xi.length + (career.reputation - 50) / 25;
  }

  /// Joga um jogo da Seleção: texto ("Brasil 2 x 1 Argentina") e se o Brasil venceu.
  (String, bool) _nationalGame(String opponent, {bool knockout = false}) {
    final n = national!;
    final l = lambdasFrom(_nationalStrength() + 2, (kNations[opponent] ?? 76).toDouble(), Tactic.neutro, Tactic.neutro);
    var gf = _poisson(l[0]);
    var ga = _poisson(l[1]);
    String extra = '';
    if (knockout && gf == ga) {
      final win = _rng.nextBool();
      extra = win ? ' (Brasil nos pênaltis)' : ' ($opponent nos pênaltis)';
      if (win) {
        gf++;
      } else {
        ga++;
      }
    }
    n
      ..goalsFor += gf
      ..goalsAgainst += ga;
    if (gf > ga) {
      n.wins++;
    } else if (gf == ga) {
      n.draws++;
    } else {
      n.losses++;
    }
    final text = 'Brasil $gf x $ga $opponent$extra';
    n.log.add('$seasonYear: $text');
    if (n.log.length > 40) n.log.removeAt(0);
    return (text, gf > ga);
  }

  /// Data FIFA: dois jogos da Seleção (Eliminatórias ou amistosos).
  void _nationalDaily(int finishedDay) {
    if (!isNationalCoach || finishedDay % 20 != 0) return;
    final names = kNations.keys.toList()..shuffle(_rng);
    final a = _nationalGame(names[0]);
    final b = _nationalGame(names[1]);
    _addNews('🇧🇷 Data FIFA: ${a.$1} • ${b.$1}');
    final wins = (a.$2 ? 1 : 0) + (b.$2 ? 1 : 0);
    career.reputation = (career.reputation + wins - 1).clamp(0, 100).toInt();
  }

  /// Copa do Mundo (2030, 2034...) e Copa América (2028, 2032...) no fim da temporada.
  void _nationalTournament() {
    if (!isNationalCoach) return;
    final world = seasonYear % 4 == 2;
    final america = seasonYear % 4 == 0;
    if (!world && !america) return;
    final name = world ? 'Copa do Mundo $seasonYear' : 'Copa América $seasonYear';
    final pool = kNations.keys
        .where((k) => !america || const ['Argentina', 'Uruguai', 'Colômbia', 'Equador', 'Paraguai', 'Chile', 'Peru', 'Venezuela', 'Bolívia', 'México', 'Estados Unidos', 'Canadá'].contains(k))
        .toList()
      ..shuffle(_rng);
    final results = <String>[];
    int wins = 0;
    for (final opp in pool.take(3)) {
      final r = _nationalGame(opp);
      results.add(r.$1);
      if (r.$2) wins++;
    }
    bool alive = wins >= 2;
    final stages = ['Oitavas', 'Quartas', 'Semifinal', 'Final'];
    var reached = 'fase de grupos';
    if (alive) {
      final rest = pool.skip(3).toList()..sort((a, b) => (kNations[a] ?? 0).compareTo(kNations[b] ?? 0));
      for (int i = 0; i < stages.length && alive; i++) {
        final opp = rest[(rest.length - stages.length + i).clamp(0, rest.length - 1)];
        final r = _nationalGame(opp, knockout: true);
        results.add('${stages[i]}: ${r.$1}');
        alive = r.$2;
        reached = stages[i];
      }
    }
    final champion = alive && reached == 'Final';
    national!.log.add('$name: ${champion ? 'CAMPEÃO! 🏆' : 'caiu na $reached'}');
    _addNews(champion ? '🏆🇧🇷 O BRASIL É CAMPEÃO: $name!' : '🇧🇷 $name: o Brasil caiu na $reached.');
    for (final r in results) {
      _addNews('🇧🇷 $name — $r');
    }
    if (champion) {
      career.trophies.add(name);
      career.reputation = (career.reputation + 15).clamp(0, 100).toInt();
      if (world) _unlock('copa_mundo');
    } else if (reached == 'fase de grupos' || reached == 'Oitavas') {
      career.reputation = (career.reputation - 10).clamp(0, 100).toInt();
      national = null;
      career.log.add('$seasonYear: demitido da Seleção após a $name.');
      _addNews('🚨 A CBF demite ${career.name} após a $name.');
      _generateJobOffers(2);
    }
  }

  // ---------------------------------------------------------------------------
  // Conquistas
  // ---------------------------------------------------------------------------

  void _unlock(String id) {
    if (achievements.contains(id) || !kAchievements.containsKey(id)) return;
    achievements.add(id);
    final a = kAchievements[id]!;
    _addNews('${a.$1} CONQUISTA DESBLOQUEADA: ${a.$2}!');
  }

  void _checkAchievements() {
    final t = userTeam;
    if (t != null && managesClub) {
      if (t.wins >= 1) _unlock('primeira_vitoria');
      if (t.wins >= 10) _unlock('dez_vitorias');
      if (t.balance >= 200000000) _unlock('rico');
      if (t.ctLevel >= 3 || t.stadiumLevel >= 3 || t.medicalLevel >= 3) _unlock('estrutura');
    }
    for (final tr in career.trophies) {
      if (tr.contains('Série A')) _unlock('serie_a');
      if (tr.contains('Copa do Brasil')) _unlock('copa_brasil');
      if (tr.contains('Libertadores')) _unlock('libertadores');
      if (tr.contains('Sul-Americana')) _unlock('sul_americana');
      if (tr.contains('Intercontinental')) _unlock('mundial');
      if (kRegionalNames.values.any(tr.contains)) _unlock('estadual');
    }
    if (history.length >= 3) _unlock('tres_temporadas');
    final pc = playerCareer;
    if (pc != null) {
      if (pc.caps > 0) _unlock('selecao_jogador');
      if (pc.totalGoals >= 100) _unlock('cem_gols');
    }
    if ((president?.elections ?? 0) > 0 && president != null) _unlock('reeleito');
  }

  // ---------------------------------------------------------------------------
  // Editor
  // ---------------------------------------------------------------------------

  void editTeam(String id, {String? name, String? coach, String? stadium}) {
    final t = _index[id];
    if (t == null) return;
    if (name != null) t.name = name;
    if (coach != null) t.coach = coach;
    if (stadium != null) t.stadium = stadium;
    _changed();
  }

  void editPlayer(String teamId, String playerId, {String? name, int? age, int? overall, String? position}) {
    final p = _index[teamId]?.findPlayer(playerId);
    if (p == null) return;
    if (name != null && name.isNotEmpty) p.name = name;
    if (age != null) p.age = age;
    if (overall != null) {
      p.overall = overall;
      p.potential = max(p.potential, overall);
    }
    if (position != null) p.position = position;
    _changed();
  }
}
