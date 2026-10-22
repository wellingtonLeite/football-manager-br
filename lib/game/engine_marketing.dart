part of 'engine.dart';

/// Espaços de patrocínio: (nome, emoji, fração do patrocínio-base do clube).
const Map<String, (String, String, double)> kSponsorSlots = {
  'master': ('Master (frente da camisa)', '👕', 0.75),
  'material': ('Material esportivo', '👟', 0.25),
  'naming': ('Naming rights do estádio', '🏟️', 0.20),
  'costas': ('Costas da camisa', '🔙', 0.12),
  'manga': ('Manga', '💪', 0.08),
  'calcao': ('Calção', '🩳', 0.05),
};

/// Empresas fictícias que procuram o clube.
const List<String> kSponsorCompanies = [
  'Banco Horizonte', 'Ápice Seguros', 'TechNova', 'Rede Vitta Saúde', 'Construtora Pilar',
  'Mercado Nobre', 'Cervejaria Bravia', 'Viação Aurora', 'Energia Solaris', 'Petrol Sul',
  'Fibra Telecom', 'PagueJá', 'Lumen Bank', 'Rota Logística', 'Visão Clara Óptica',
  'Supermercados Bom Preço', 'Atlas Investimentos', 'Nuvem Digital', 'Café Serrano', 'Moda Brisa',
  'Farmácias Bem Viver', 'Auto Center Veloz', 'Universidade Saber', 'Açaí Tropical', 'Imobiliária Lar',
];
const List<String> kKitSuppliers = [
  'Kanto Sports', 'Vortex Sportswear', 'Garra Esportes', 'Ritmo Athletic', 'Fênix Sport', 'Arena Wear',
];

/// Departamento de marketing: propostas de patrocínio que o presidente aceita ou recusa.
extension GameMarketing on GameState {
  /// Valor mensal de referência de um espaço de patrocínio para o clube.
  int sponsorSlotBase(Team t, String slot) {
    final divFactor = const [1.0, 1.0, 0.55, 0.3, 0.18][t.division.clamp(0, 4)];
    return roundTo(baseSponsor(t.stars) * kSponsorSlots[slot]!.$3 * divFactor, 10000);
  }

  int get marketingLevel => staff['marketing'] ?? 0;

  /// No Modo Presidente, quem decide é o usuário; nos outros, a diretoria (IA).
  bool get userDecidesSponsors => mode == GameMode.presidente;

  int sponsorTotal(Team t) => t.sponsorsManaged ? t.sponsors.fold(0, (s, d) => s + d.monthly) : t.sponsorMonthly;

  SponsorDeal? sponsorIn(Team t, String slot) => t.sponsors.where((d) => d.slot == slot).firstOrNull;

  /// Contratos iniciais do clube assumido: master e material esportivo.
  void _initSponsors(Team t) {
    if (t.sponsorsManaged) return;
    t.sponsorsManaged = true;
    final rng = Random(t.id.hashCode ^ seasonYear);
    t.sponsors
      ..add(SponsorDeal(
        slot: 'master',
        company: kSponsorCompanies[rng.nextInt(kSponsorCompanies.length)],
        monthly: sponsorSlotBase(t, 'master'),
        seasonsLeft: 1 + rng.nextInt(2),
      ))
      ..add(SponsorDeal(
        slot: 'material',
        company: kKitSuppliers[rng.nextInt(kKitSuppliers.length)],
        monthly: sponsorSlotBase(t, 'material'),
        seasonsLeft: 1 + rng.nextInt(3),
      ));
    t.sponsorMonthly = sponsorTotal(t);
  }

  /// Rotina diária: o marketing traz propostas; sem presidente humano, a diretoria decide.
  void _marketingDaily() {
    final t = userTeam;
    if (t == null || !managesClub) return;
    _initSponsors(t);
    t.sponsorOffers.removeWhere((o) => o.expiresDay < currentDay);
    if (t.sponsorOffers.length >= 4 || seasonFinished) return;
    final level = marketingLevel;
    if (_rng.nextDouble() > 0.18 + 0.08 * level) return;
    // Prefere espaços vagos ou com contrato no último ano
    final slots = kSponsorSlots.keys.toList();
    final open = slots.where((s) => sponsorIn(t, s) == null || sponsorIn(t, s)!.seasonsLeft <= 1).toList();
    final slot = open.isNotEmpty && _rng.nextDouble() < 0.8 ? open[_rng.nextInt(open.length)] : slots[_rng.nextInt(slots.length)];
    if (t.sponsorOffers.any((o) => o.slot == slot)) return;
    final pos = userPosition;
    double form = 0.75 + t.fanMorale / 350.0;
    if (pos > 0 && pos <= 4) form += 0.1;
    if (pos >= 17) form -= 0.1;
    final value = roundTo(sponsorSlotBase(t, slot) * (0.75 + _rng.nextDouble() * 0.5) * (1 + 0.08 * level) * form, 10000);
    final current = sponsorIn(t, slot);
    if (current != null && value <= current.monthly) return; // só traz propostas melhores
    final names = slot == 'material' ? kKitSuppliers : kSponsorCompanies;
    final used = t.sponsors.map((d) => d.company).toSet();
    final free = names.where((n) => !used.contains(n)).toList();
    final offer = SponsorOffer(
      slot: slot,
      company: (free.isEmpty ? names : free)[_rng.nextInt((free.isEmpty ? names : free).length)],
      monthly: value,
      seasons: 1 + _rng.nextInt(3),
      signingBonus: roundTo(value * (1 + _rng.nextDouble() * 2), 10000),
      expiresDay: currentDay + 8,
    );
    if (!userDecidesSponsors) {
      // A diretoria fecha se o espaço está vago ou a proposta é bem melhor
      if (current == null || offer.monthly >= current.monthly * 1.1) {
        _signSponsor(t, offer, byBoard: true);
      }
      return;
    }
    t.sponsorOffers.add(offer);
    _addNews('📣 Marketing: ${offer.company} quer o espaço "${kSponsorSlots[slot]!.$1}" por ${formatMoney(value)}/mês.');
  }

  void _signSponsor(Team t, SponsorOffer o, {bool byBoard = false}) {
    t.sponsors.removeWhere((d) => d.slot == o.slot);
    t.sponsors.add(SponsorDeal(slot: o.slot, company: o.company, monthly: o.monthly, seasonsLeft: o.seasons));
    t.sponsorOffers.remove(o);
    t.sponsorMonthly = sponsorTotal(t);
    _credit(t, o.signingBonus, 'Patrocínio', 'Luvas de assinatura: ${o.company}');
    _addNews('🤝 ${byBoard ? 'A diretoria fechou' : 'Fechado'}: ${o.company} no espaço "${kSponsorSlots[o.slot]!.$1}" '
        '(${formatMoney(o.monthly)}/mês por ${o.seasons} temporada${o.seasons > 1 ? 's' : ''}).');
  }

  TransferResult acceptSponsorOffer(SponsorOffer o) {
    final t = userTeam;
    if (t == null || !managesClub || !t.sponsorOffers.contains(o)) {
      return const TransferResult(false, 'A proposta não está mais disponível.');
    }
    if (!userDecidesSponsors) return const TransferResult(false, 'Quem decide os patrocínios é o presidente.');
    _signSponsor(t, o);
    president?.popularity = (president!.popularity + 2).clamp(0, 100).toInt();
    _changed();
    return TransferResult(true, 'Contrato assinado! Luvas de ${formatMoney(o.signingBonus)} já estão no caixa.');
  }

  void rejectSponsorOffer(SponsorOffer o) {
    userTeam?.sponsorOffers.remove(o);
    _changed();
  }

  /// Fim da temporada: contratos perdem um ano; os vencidos saem.
  void _sponsorSeasonEnd() {
    for (final t in allTeams.where((t) => t.sponsorsManaged)) {
      if (!isHumanTeam(t.id)) {
        // Clube voltou para a IA: segue com o patrocínio padrão
        t
          ..sponsorsManaged = false
          ..sponsorMonthly = baseSponsor(t.stars);
        t.sponsors.clear();
        t.sponsorOffers.clear();
        continue;
      }
      for (final d in t.sponsors.toList()) {
        d.seasonsLeft--;
        if (d.seasonsLeft <= 0) {
          t.sponsors.remove(d);
          if (isHumanTeam(t.id)) _addNews('📃 Terminou o contrato com ${d.company} (${kSponsorSlots[d.slot]!.$1}). O marketing vai buscar outro.');
        }
      }
      t.sponsorOffers.clear();
      t.sponsorMonthly = sponsorTotal(t);
    }
  }
}
