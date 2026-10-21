part of 'engine.dart';

/// Fase 9 — Mercado de transferências.
extension GameMarket on GameState {
  Team? ownerOf(String playerId) {
    for (final t in allTeams) {
      if (t.findPlayer(playerId) != null) return t;
    }
    return null;
  }

  /// Jogadores de outros clubes, do mais forte para o mais fraco.
  List<(Team, Player)> marketPlayers({
    String? position,
    int? maxPrice,
    bool onlyListed = false,
    String region = 'BRA',
    String query = '',
    int? minAge,
    int? maxAge,
    bool onlyScouted = false,
    String sort = 'overall',
  }) {
    final q = _fold(query.trim());
    final result = <(Team, Player)>[];
    final source = switch (region) {
      'BRA' => teams,
      'ALL' => allTeams,
      'AME' => foreignTeams.where((t) => t.league.isEmpty),
      _ => foreignTeams.where((t) => t.league == region),
    };
    for (final t in source) {
      if (t.id == userTeamId) continue;
      for (final p in t.squad) {
        if (p.onLoan) continue;
        if (position != null && p.position != position) continue;
        if (onlyListed && !p.listed) continue;
        if (minAge != null && p.age < minAge) continue;
        if (maxAge != null && p.age > maxAge) continue;
        if (onlyScouted && !isScouted(p)) continue;
        if (q.isNotEmpty && !_fold(p.name).contains(q) && !_fold(t.name).contains(q)) continue;
        if (maxPrice != null && askingPriceFor(t, p) > maxPrice) continue;
        result.add((t, p));
      }
    }
    int potentialOf(Player p) => isScouted(p) ? p.potential : p.overall;
    switch (sort) {
      case 'potential':
        result.sort((a, b) => potentialOf(b.$2).compareTo(potentialOf(a.$2)));
      case 'price':
        result.sort((a, b) => askingPriceFor(a.$1, a.$2).compareTo(askingPriceFor(b.$1, b.$2)));
      case 'age':
        result.sort((a, b) => a.$2.age != b.$2.age ? a.$2.age.compareTo(b.$2.age) : b.$2.overall.compareTo(a.$2.overall));
      default:
        result.sort((a, b) => b.$2.overall.compareTo(a.$2.overall));
    }
    return result;
  }

  /// Minúsculas sem acento, para a busca por nome.
  static String _fold(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString();
  }

  /// Valor pedido pelo clube da IA para negociar o atleta.
  int askingPriceFor(Team seller, Player p) {
    if (p.listed && p.askingPrice > 0) return p.askingPrice;
    final starter = seller.startingIds.contains(p.id);
    final abroad = seller.isForeign && seller.baseOverall >= 82 ? 1.3 : 1.0;
    return roundTo(p.marketValue * (starter ? 1.5 : 1.2) * abroad, 50000);
  }

  /// Comissão do empresário (5% da transferência).
  int agentFee(int fee) => roundTo(fee * 0.05, 10000);

  /// Salário mensal que o atleta pede para assinar com o clube do usuário.
  int wageDemand(Player p, {Team? from}) {
    final user = userTeam;
    double d = max(p.wage, Player.fairWage(p.overall, p.age)).toDouble();
    if (from == null) {
      d *= 0.9;
    } else if (from.isForeign && from.baseOverall >= 82) {
      d *= 1.5; // trocar a Europa/Arábia pelo Brasil exige salário alto
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
    if (user.squad.length >= GameState.maxSquadSize) {
      return 'Elenco cheio (${GameState.maxSquadSize} atletas). Venda ou dispense alguém antes.';
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
    if (user == null || !managesClub) return const TransferResult(false, 'Você não administra um clube.');
    final seller = ownerOf(playerId);
    if (seller == null || seller.id == user.id) {
      return const TransferResult(false, 'Jogador indisponível.');
    }
    final p = seller.playerById(playerId);
    if (p.onLoan) return TransferResult(false, '${p.name} está emprestado e não pode ser negociado.');
    final full = _squadCheck(user);
    if (full != null) return TransferResult(false, full);
    if (seller.squad.length <= GameState.minSquadSize) {
      return TransferResult(false, 'O ${seller.name} não aceita reduzir mais o elenco.');
    }
    if (!transferWindowOpen) return TransferResult(false, '$windowLabel. Só agentes livres podem ser contratados agora.');
    final commission = agentFee(fee);
    if (user.balance < fee + signingBonus + commission) {
      return TransferResult(false, 'Caixa insuficiente: você tem ${formatMoney(user.balance)} (com a comissão de ${formatMoney(commission)}).');
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
        _notify();
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
    _debit(user, commission, 'Transferências', 'Comissão do empresário de ${p.name}');
    _settleSellOn(p, fee);
    if (p.overall >= 85) _unlock('craque');
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
    _onUserSigning(p);
    _changed();
    return TransferResult(true, '${p.name} assinou por $years temporada(s)!');
  }

  int loanFee(Player p) => roundTo(p.marketValue * 0.1, 50000);

  /// Valor sugerido para a opção de compra num empréstimo.
  int suggestedOptionPrice(Player p) => roundTo(p.marketValue * 1.1, 50000);

  /// Empréstimo de um jogador de outro clube até o fim da temporada.
  /// [fee] = taxa oferecida; com [withOption], [optionPrice] = valor para comprar depois.
  TransferResult proposeLoan(String playerId, {int? fee, bool withOption = false, int? optionPrice}) {
    final user = userTeam;
    if (user == null || !managesClub) return const TransferResult(false, 'Você não administra um clube.');
    final seller = ownerOf(playerId);
    if (seller == null || seller.id == user.id) {
      return const TransferResult(false, 'Jogador indisponível.');
    }
    final p = seller.playerById(playerId);
    if (p.onLoan) return TransferResult(false, '${p.name} já está emprestado.');
    final full = _squadCheck(user);
    if (full != null) return TransferResult(false, full);
    if (seller.squad.length <= GameState.minSquadSize) {
      return TransferResult(false, 'O ${seller.name} não aceita reduzir mais o elenco.');
    }
    if (!transferWindowOpen) return TransferResult(false, '$windowLabel.');
    final wantedFee = loanFee(p) * (withOption ? 2 : 1);
    final offeredFee = fee ?? wantedFee;
    final wantedOption = suggestedOptionPrice(p);
    final offeredOption = optionPrice ?? wantedOption;
    if (user.balance < offeredFee) {
      return TransferResult(false, 'Caixa insuficiente para a taxa de ${formatMoney(offeredFee)}.');
    }
    final starter = seller.startingIds.contains(p.id);
    double chance = (starter ? 0.15 : 0.75) + (p.listed ? 0.15 : 0) + (user.stars - seller.stars) * 0.05;
    // Taxa e opção abaixo do esperado reduzem a chance; acima, aumentam
    chance *= (offeredFee / max(1, wantedFee)).clamp(0.2, 1.4);
    if (withOption) chance *= ((offeredOption / wantedOption - 0.7) / 0.3).clamp(0.05, 1.3);
    if (_rng.nextDouble() > chance) {
      _notify();
      final need = starter ? ' Ele é titular: o clube resiste a emprestar.' : '';
      return TransferResult(false,
          'O ${seller.name} recusou.$need Eles esperam taxa de ${formatMoney(wantedFee)}'
          '${withOption ? ' e opção de compra de ${formatMoney(wantedOption)}' : ''}.');
    }
    seller.squad.remove(p);
    seller.startingIds.remove(p.id);
    seller.balance += offeredFee;
    _debit(user, offeredFee, 'Transferências', 'Empréstimo de ${p.name} (${seller.name})');
    p
      ..loanFromTeamId = seller.id
      ..listed = false
      ..askingPrice = 0;
    user.squad.add(p);
    if (withOption) loanOptions[p.id] = offeredOption;
    _addNews('🔁 ${p.name} chega ao ${user.name} por empréstimo até o fim da temporada'
        '${withOption ? ' (opção de compra: ${formatMoney(offeredOption)})' : ''}.');
    _changed();
    return TransferResult(true,
        '${p.name} emprestado até o fim da temporada. Salário de ${formatMoney(p.wage)}/mês por sua conta.');
  }

  // ---------------------------------------------------------------------------
  // Emprestar jogadores do nosso elenco
  // ---------------------------------------------------------------------------

  /// Clubes interessados em receber [p] por empréstimo, com a taxa que oferecem.
  /// A lista muda a cada data (semente fixa no dia para não mudar com a tela aberta).
  List<(Team, int)> loanSuitors(Player p) {
    final user = userTeam;
    if (user == null) return const [];
    final rng = Random(p.id.hashCode ^ (currentDay * 7919) ^ seasonYear);
    final cands = allTeams
        .where((t) => t.id != user.id && !isHumanTeam(t.id) && (!t.isForeign || t.league.isNotEmpty) &&
            t.squad.length < GameState.maxSquadSize &&
            p.overall >= t.averageOverall - 6 && p.overall <= t.averageOverall + 10)
        .toList()
      ..shuffle(rng);
    // Prefere clubes do Brasil
    cands.sort((a, b) => (a.isForeign ? 1 : 0).compareTo(b.isForeign ? 1 : 0));
    return [
      for (final t in cands.take(6))
        (t, roundTo(loanFee(p) * (0.5 + rng.nextDouble() * 0.7), 50000)),
    ];
  }

  /// Jogadores do clube do usuário que estão emprestados a outros clubes.
  List<(Team, Player)> get loanedOut {
    final id = userTeamId;
    if (id == null) return const [];
    return [
      for (final t in allTeams)
        if (t.id != id)
          for (final p in t.squad)
            if (p.loanFromTeamId == id) (t, p),
    ];
  }

  /// Empresta [playerId] ao clube [toTeamId] até o fim da temporada.
  TransferResult loanOut(String playerId, String toTeamId, {required int fee, bool withOption = false, int? optionPrice}) {
    final user = userTeam;
    final p = user?.findPlayer(playerId);
    final to = teamOrNull(toTeamId);
    if (user == null || p == null || to == null || !managesClub) {
      return const TransferResult(false, 'Negócio indisponível.');
    }
    if (p.onLoan) return TransferResult(false, '${p.name} já é um jogador emprestado ao seu clube.');
    if (!transferWindowOpen) return TransferResult(false, '$windowLabel.');
    if (user.squad.length <= GameState.minSquadSize) {
      return const TransferResult(false, 'Elenco no tamanho mínimo (${GameState.minSquadSize}).');
    }
    final offer = loanSuitors(p).where((s) => s.$1.id == toTeamId).firstOrNull;
    final base = offer?.$2 ?? loanFee(p);
    final option = optionPrice ?? suggestedOptionPrice(p);
    // Pedir mais que a oferta, ou opção de compra cara, pode afastar o clube
    double chance = 0.95 * (base / max(1, fee)).clamp(0.0, 1.0);
    if (withOption) chance *= (suggestedOptionPrice(p) / max(1, option) * 1.1).clamp(0.1, 1.0);
    if (_rng.nextDouble() > chance) {
      _notify();
      return TransferResult(false, 'O ${to.name} não aceitou as condições. Eles oferecem ${formatMoney(base)} de taxa.');
    }
    user.squad.remove(p);
    user.startingIds.remove(p.id);
    incomingOffers.removeWhere((o) => o.playerId == p.id);
    p
      ..listed = false
      ..askingPrice = 0
      ..loanFromTeamId = user.id;
    to.squad.add(p);
    to.balance -= fee;
    _credit(user, fee, 'Transferências', 'Empréstimo de ${p.name} ao ${to.name}');
    if (withOption) loanOptions[p.id] = option;
    _addNews('🔁 ${p.name} é emprestado ao ${to.name} até o fim da temporada'
        '${withOption ? ' (opção de compra: ${formatMoney(option)})' : ''}.');
    _changed();
    return TransferResult(true, '${p.name} emprestado ao ${to.name} (${formatMoney(fee)}). O salário passa a ser pago por eles.');
  }

  /// Traz de volta um jogador emprestado (só com a janela aberta).
  TransferResult recallLoan(String playerId) {
    final user = userTeam;
    final entry = loanedOut.where((e) => e.$2.id == playerId).firstOrNull;
    if (user == null || entry == null) return const TransferResult(false, 'Empréstimo não encontrado.');
    if (!transferWindowOpen) return TransferResult(false, '$windowLabel.');
    final full = _squadCheck(user);
    if (full != null) return TransferResult(false, full);
    final (t, p) = entry;
    t.squad.remove(p);
    t.startingIds.remove(p.id);
    p.loanFromTeamId = null;
    loanOptions.remove(p.id);
    user.squad.add(p);
    _addNews('↩️ ${user.name} encerra o empréstimo e ${p.name} volta do ${t.name}.');
    _changed();
    return TransferResult(true, '${p.name} voltou ao elenco.');
  }

  TransferResult signFreeAgent(String playerId, {required int wage, required int years}) {
    final user = userTeam;
    if (user == null || !managesClub) return const TransferResult(false, 'Você não administra um clube.');
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
    _changed();
    return TransferResult(true, '${p.name} assinou por $years temporada(s)!');
  }

  void setListed(String playerId, bool listed, {int? price}) {
    final p = userTeam?.findPlayer(playerId);
    if (p == null || p.onLoan) return;
    p.listed = listed;
    p.askingPrice = listed ? (price ?? p.marketValue) : 0;
    if (!listed) incomingOffers.removeWhere((o) => o.playerId == playerId);
    _changed();
  }

  int releaseCost(Player p) => p.onLoan ? 0 : p.wage * 3;

  TransferResult releasePlayer(String playerId) {
    final user = userTeam;
    final p = user?.findPlayer(playerId);
    if (user == null || p == null) return const TransferResult(false, 'Jogador não encontrado.');
    if (user.squad.length <= GameState.minSquadSize) {
      return const TransferResult(false, 'Elenco no tamanho mínimo (${GameState.minSquadSize}).');
    }
    user.squad.remove(p);
    user.startingIds.remove(p.id);
    incomingOffers.removeWhere((o) => o.playerId == p.id);
    if (p.onLoan) {
      final owner = teamOrNull(p.loanFromTeamId);
      p.loanFromTeamId = null;
      owner?.squad.add(p);
      _changed();
      return TransferResult(true, '${p.name} foi devolvido ao ${owner?.name ?? 'clube de origem'}.');
    }
    final cost = releaseCost(p);
    _debit(user, cost, 'Transferências', 'Rescisão de ${p.name}');
    p
      ..listed = false
      ..askingPrice = 0
      ..contractYears = 0;
    freeAgents.add(p);
    _changed();
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
      _notify();
      return TransferResult(false, '${p.name} recusou. Ele pede ${formatMoney(demand)}/mês.');
    }
    p
      ..wage = wage
      ..contractYears = years + 1
      ..releaseClause = max(p.releaseClause, p.marketValue * 2)
      ..morale = (p.morale + 5).clamp(0, 100).toInt();
    _addNews('🖊️ ${p.name} renova até ${seasonYear + years}.');
    _changed();
    return TransferResult(true, '${p.name} renovou até ${seasonYear + years}!');
  }

  TransferResult acceptOffer(TransferOffer o, {int sellOnPercent = 0}) {
    final user = userTeam;
    final p = user?.findPlayer(o.playerId);
    final buyer = teamOrNull(o.buyerId);
    if (user == null || p == null || buyer == null) {
      incomingOffers.remove(o);
      _notify();
      return const TransferResult(false, 'A proposta não é mais válida.');
    }
    if (user.squad.length <= GameState.minSquadSize) {
      return const TransferResult(false, 'Elenco no tamanho mínimo: contrate antes de vender.');
    }
    if (buyer.balance < o.amount) {
      incomingOffers.remove(o);
      _notify();
      return TransferResult(false, 'O ${buyer.name} não tem mais caixa e desistiu.');
    }
    // Cláusula de revenda: o comprador paga um pouco menos agora
    final amount = (o.amount * (1 - sellOnPercent / 200)).round();
    buyer.balance -= amount;
    _credit(user, amount, 'Transferências', 'Venda de ${p.name} para o ${buyer.name}');
    if (sellOnPercent > 0) sellOnClauses[p.id] = (user.id, sellOnPercent);
    if (amount >= 50000000) _unlock('venda_50');
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
    _onUserSale(p);
    _changed();
    return TransferResult(true, '${p.name} vendido por ${formatMoney(o.amount)}!');
  }

  void rejectOffer(TransferOffer o) {
    incomingOffers.remove(o);
    _changed();
  }

  /// Pede 15% a mais. O comprador aceita (e o negócio fecha) ou desiste.
  TransferResult counterOffer(TransferOffer o) {
    final buyer = teamOrNull(o.buyerId);
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
    _changed();
    return TransferResult(false, 'O ${buyer?.name ?? 'comprador'} não aceitou pagar ${formatMoney(amount)} e desistiu.');
  }

  void _expireOffers() {
    final user = userTeam;
    incomingOffers.removeWhere((o) =>
        o.expiresRound < currentDay ||
        (user == null && humans.isEmpty) ||
        !teams.any((t) => isHumanTeam(t.id) && t.findPlayer(o.playerId) != null));
  }

  String _neediestPosition(Team t, [Map<String, int> targets = kSquadTargets]) {
    String best = 'ATA';
    int bestGap = -999;
    targets.forEach((pos, target) {
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
      if (t.id == userTeamId && managesClub) continue;
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
    if (user != null && transferWindowOpen) {
      final avg = user.averageOverall;
      for (final p in user.squad) {
        if (p.onLoan || incomingOffers.any((o) => o.playerId == p.id)) continue;
        final chance = p.listed ? 0.35 : (p.overall >= avg + 4 ? 0.02 : 0.0);
        if (chance == 0 || _rng.nextDouble() >= chance) continue;
        final ref = p.listed && p.askingPrice > 0 ? p.askingPrice : p.marketValue;
        final buyers = allTeams
            .where((t) => t.id != user.id && (!t.isForeign || t.league.isNotEmpty) &&
                t.squad.length < GameState.maxSquadSize && t.balance >= ref * 0.7)
            .toList();
        if (buyers.isEmpty) continue;
        final buyer = buyers[_rng.nextInt(buyers.length)];
        final factor = p.listed ? 0.75 + _rng.nextDouble() * 0.3 : 1.1 + _rng.nextDouble() * 0.3;
        final amount = roundTo(min(ref * factor, buyer.balance.toDouble()), 50000);
        incomingOffers.add(TransferOffer(
          playerId: p.id,
          buyerId: buyer.id,
          amount: amount,
          expiresRound: currentDay + 4,
        ));
        _addNews('📩 ${buyer.name} ofereceu ${formatMoney(amount)} por ${p.name}.');
      }
    }
    if (currentDay % 6 == 0) {
      for (final t in teams) {
        if (t.id != userTeamId && t.squad.length < 20) _aiSignFreeAgent(t);
      }
    }
  }

}
