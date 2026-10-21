import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/engine.dart';
import '../game/models.dart';
import '../game/data.dart';
import '../game/economy.dart';
import 'shield.dart';
import 'widgets.dart';

/// Fase 9 — Contratar, Agentes Livres e Meu Elenco (vendas, renovações, propostas).
class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final t = game.userTeam;
    if (t == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mercado'), backgroundColor: kGreen),
        body: const Center(child: Text('Você está sem clube.', style: TextStyle(color: Colors.white70))),
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mercado de Transferências'),
          backgroundColor: kGreen,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.amber,
            tabs: [
              const Tab(text: 'Contratar'),
              const Tab(text: 'Agentes Livres'),
              Tab(text: game.incomingOffers.isEmpty ? 'Meu Elenco' : 'Meu Elenco (${game.incomingOffers.length})'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.black38,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Caixa: ${formatMoney(t.balance)} • Elenco: ${t.squad.length}/${GameState.maxSquadSize} • Folha: ${formatMoney(t.payroll)}/mês',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '${game.transferWindowOpen ? '🟢' : '🔴'} ${game.windowLabel}',
                    style: TextStyle(color: game.transferWindowOpen ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [_BuyTab(), _FreeAgentsTab(), _MySquadTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Contratar
// -----------------------------------------------------------------------------

class _BuyTab extends StatefulWidget {
  const _BuyTab();

  @override
  State<_BuyTab> createState() => _BuyTabState();
}

class _BuyTabState extends State<_BuyTab> {
  String? position;
  String region = 'BRA';
  bool onlyListed = false;
  bool onlyScouted = false;
  int? maxPrice;
  String age = 'Todas';
  String sort = 'overall';
  String query = '';
  bool showFilters = false;
  final _search = TextEditingController();

  static const Map<String, int?> _priceFilters = {
    'Qualquer preço': null,
    'Até R\$ 2 mi': 2000000,
    'Até R\$ 5 mi': 5000000,
    'Até R\$ 10 mi': 10000000,
    'Até R\$ 20 mi': 20000000,
    'Até R\$ 50 mi': 50000000,
  };

  static const Map<String, (int?, int?)> _ageFilters = {
    'Todas': (null, null),
    'Até 21': (null, 21),
    'Até 23': (null, 23),
    '24 a 29': (24, 29),
    '30+': (30, null),
  };

  static const Map<String, String> _sorts = {
    'overall': 'Melhor overall',
    'potential': 'Maior potencial',
    'price': 'Mais barato',
    'age': 'Mais jovem',
  };

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int get _activeFilters =>
      (position != null ? 1 : 0) + (onlyListed ? 1 : 0) + (onlyScouted ? 1 : 0) + (maxPrice != null ? 1 : 0) + (age != 'Todas' ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final (minAge, maxAge) = _ageFilters[age]!;
    final list = game.marketPlayers(
      position: position,
      maxPrice: maxPrice,
      onlyListed: onlyListed,
      region: region,
      query: query,
      minAge: minAge,
      maxAge: maxAge,
      onlyScouted: onlyScouted,
      sort: sort,
    );
    final regions = <String, String>{
      'BRA': '🇧🇷 Brasil (Séries A–D)',
      'ALL': '🌍 Todos os clubes',
      for (final e in kLeagueNames.entries) e.key: '${kLeagueCountry[e.key]} • ${e.value}',
      'AME': '🌎 América do Sul (copas)',
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Buscar jogador ou clube',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54),
                            onPressed: () => setState(() {
                              _search.clear();
                              query = '';
                            }),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              IconButton(
                tooltip: 'Filtros',
                onPressed: () => setState(() => showFilters = !showFilters),
                icon: Badge(
                  isLabelVisible: _activeFilters > 0,
                  label: Text('$_activeFilters'),
                  child: Icon(showFilters ? Icons.filter_alt_off : Icons.filter_alt, color: Colors.white),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Ordenar',
                icon: const Icon(Icons.sort, color: Colors.white),
                color: kCard,
                initialValue: sort,
                onSelected: (v) => setState(() => sort = v),
                itemBuilder: (_) => [
                  for (final e in _sorts.entries)
                    PopupMenuItem(value: e.key, child: Text('${e.key == sort ? '✓ ' : ''}${e.value}')),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<String>(
            value: region,
            isExpanded: true,
            dropdownColor: kCard,
            style: const TextStyle(color: Colors.white),
            items: [for (final e in regions.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => region = v ?? region),
          ),
        ),
        if (showFilters) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                _chip('Todas posições', position == null, () => setState(() => position = null)),
                for (final p in kPositions) _chip(p, position == p, () => setState(() => position = p)),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                for (final a in _ageFilters.keys)
                  _chip(a == 'Todas' ? 'Todas idades' : a, age == a, () => setState(() => age = a)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('📋 À venda'),
                  selected: onlyListed,
                  onSelected: (v) => setState(() => onlyListed = v),
                ),
                FilterChip(
                  label: const Text('🔭 Observados'),
                  selected: onlyScouted,
                  onSelected: (v) => setState(() => onlyScouted = v),
                ),
                DropdownButton<int?>(
                  value: maxPrice,
                  dropdownColor: kCard,
                  style: const TextStyle(color: Colors.white),
                  items: [
                    for (final e in _priceFilters.entries) DropdownMenuItem<int?>(value: e.value, child: Text(e.key)),
                  ],
                  onChanged: (v) => setState(() => maxPrice = v),
                ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
          child: Row(
            children: [
              Text('${list.length} jogadores • ${_sorts[sort]}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const Spacer(),
              if (_activeFilters > 0 || query.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() {
                    position = null;
                    onlyListed = false;
                    onlyScouted = false;
                    maxPrice = null;
                    age = 'Todas';
                    query = '';
                    _search.clear();
                  }),
                  child: const Text('Limpar filtros', style: TextStyle(color: Colors.amber, fontSize: 11)),
                ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('Nenhum jogador com esses filtros.', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final (team, p) = list[i];
                    return MarketPlayerTile(team: team, player: p);
                  },
                ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          selectedColor: Colors.green,
          backgroundColor: Colors.grey.shade900,
          labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
          onSelected: (_) => onTap(),
        ),
      );
}

/// Linha de jogador do mercado (também usada pelos olheiros).
class MarketPlayerTile extends StatelessWidget {
  final Team team;
  final Player player;
  const MarketPlayerTile({super.key, required this.team, required this.player});

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameState>();
    final p = player;
    final asking = game.askingPriceFor(team, p);
    final scouted = game.isScouted(p);
    return ListTile(
      dense: true,
      leading: overallAvatar(p),
      title: Row(
        children: [
          if (p.listed) const Text('📋 ', style: TextStyle(fontSize: 12)),
          Expanded(
            child: Text(p.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          if (scouted)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
              child: Text('pot ${p.potential}', style: const TextStyle(color: Colors.amber, fontSize: 10)),
            ),
          ClubShield(shortName: team.shortName, size: 16),
        ],
      ),
      subtitle: Text(
        '${p.position} • ${p.age} anos • ${p.nat} • ${team.name}\n'
        'Pedem ${formatMoney(asking)} • salário ${formatMoney(p.wage)}',
        style: const TextStyle(color: Colors.white60, fontSize: 11),
      ),
      isThreeLine: true,
      onTap: () => showDialog(context: context, builder: (_) => OfferDialog(seller: team, player: p)),
    );
  }
}

class OfferDialog extends StatefulWidget {
  final Team seller;
  final Player player;
  const OfferDialog({super.key, required this.seller, required this.player});

  @override
  State<OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<OfferDialog> {
  late int fee;
  late int wage;
  int bonus = 0;
  int years = 3;
  bool loanMode = false;
  bool loanOption = true;
  late int loanFeeOffer;
  late int optionPrice;
  late int asking;
  late int demand;

  @override
  void initState() {
    super.initState();
    final game = context.read<GameState>();
    asking = game.askingPriceFor(widget.seller, widget.player);
    demand = game.wageDemand(widget.player, from: widget.seller);
    fee = asking;
    wage = demand;
    loanFeeOffer = game.loanFee(widget.player) * 2;
    optionPrice = game.suggestedOptionPrice(widget.player);
  }

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameState>();
    final p = widget.player;
    final feeMax = max(p.releaseClause, asking * 2);
    final starter = widget.seller.startingIds.contains(p.id);
    final baseLoan = game.loanFee(p);
    final wantedLoan = max(50000, baseLoan * (loanOption ? 2 : 1));
    final loanMin = roundTo(wantedLoan * 0.4, 50000);
    final loanMax = max(wantedLoan * 2, loanMin + 50000);
    return AlertDialog(
      backgroundColor: kCard,
      title: Row(
        children: [
          ClubShield(shortName: widget.seller.shortName, size: 26),
          const SizedBox(width: 8),
          Expanded(child: Text('${p.name} (${p.overall})', style: const TextStyle(color: Colors.white))),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            infoRow('Clube', widget.seller.name),
            infoRow('Posição / idade', '${p.position} • ${p.age} anos • ${p.nat}'),
            infoRow('Valor de mercado', formatMoney(p.marketValue)),
            infoRow('Situação', starter ? 'Titular no clube' : (p.listed ? 'Na lista de transferências' : 'Reserva')),
            infoRow('Salário atual', '${formatMoney(p.wage)}/mês'),
            infoRow('Potencial', game.isScouted(p) ? '${p.potential}' : '? (observe o jogador)'),
            if (!game.isScouted(p))
              TextButton(
                onPressed: () => setState(() => showResult(context, game.scoutPlayer(p.id))),
                child: const Text('🔭 Mandar observar (R\$ 50 mil)'),
              ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Comprar'), icon: Icon(Icons.shopping_cart)),
                ButtonSegment(value: true, label: Text('Empréstimo'), icon: Icon(Icons.swap_horiz)),
              ],
              selected: {loanMode},
              onSelectionChanged: (v) => setState(() => loanMode = v.first),
            ),
            const Divider(color: Colors.white24),
            if (!loanMode) ...[
              infoRow('Preço pedido', formatMoney(asking)),
              infoRow('Multa rescisória', formatMoney(p.releaseClause)),
              MoneySlider(
                label: 'Proposta ao clube',
                value: fee,
                min: roundTo(asking * 0.5, 50000),
                max: feeMax,
                step: 50000,
                onChanged: (v) => setState(() => fee = v),
              ),
              TextButton(
                onPressed: () => setState(() => fee = p.releaseClause),
                child: Text('Pagar a multa (${formatMoney(p.releaseClause)})'),
              ),
              MoneySlider(
                label: 'Salário oferecido (pede ${formatMoney(demand)})',
                value: wage,
                min: roundTo(demand * 0.6, 1000),
                max: roundTo(demand * 2, 1000),
                step: 1000,
                onChanged: (v) => setState(() => wage = v),
              ),
              MoneySlider(
                label: 'Luvas',
                value: bonus,
                min: 0,
                max: roundTo(demand * 12, 10000),
                step: 10000,
                onChanged: (v) => setState(() => bonus = v),
              ),
              YearsPicker(value: years, onChanged: (v) => setState(() => years = v)),
              infoRow('Comissão do empresário (5%)', formatMoney(game.agentFee(fee))),
              Text(
                'Total agora: ${formatMoney(fee + bonus + game.agentFee(fee))}',
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
              ),
            ] else ...[
              const Text('Até o fim da temporada. O salário do jogador fica por sua conta.',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: loanOption,
                onChanged: (v) => setState(() {
                  loanOption = v;
                  loanFeeOffer = max(50000, baseLoan * (v ? 2 : 1));
                }),
                title: const Text('Com opção de compra', style: TextStyle(color: Colors.white70, fontSize: 13)),
                subtitle: const Text('Você decide no fim do empréstimo se compra o jogador.',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ),
              MoneySlider(
                label: 'Taxa de empréstimo (esperam ${formatMoney(wantedLoan)})',
                value: loanFeeOffer.clamp(loanMin, loanMax).toInt(),
                min: loanMin,
                max: loanMax,
                step: 50000,
                onChanged: (v) => setState(() => loanFeeOffer = v),
              ),
              if (loanOption)
                MoneySlider(
                  label: 'Valor da opção de compra (sugerido ${formatMoney(game.suggestedOptionPrice(p))})',
                  value: optionPrice,
                  min: roundTo(p.marketValue * 0.6, 50000),
                  max: max(roundTo(p.marketValue * 2, 50000), roundTo(p.marketValue * 0.6, 50000) + 50000),
                  step: 50000,
                  onChanged: (v) => setState(() => optionPrice = v),
                ),
              Text(
                starter ? '⚠️ Titular: o clube dificilmente empresta.' : 'Reserva: o clube tende a aceitar.',
                style: TextStyle(color: starter ? Colors.orangeAccent : Colors.greenAccent, fontSize: 12),
              ),
              Text('Total agora: ${formatMoney(loanFeeOffer.clamp(loanMin, loanMax).toInt())}',
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          onPressed: () {
            final r = loanMode
                ? game.proposeLoan(p.id,
                    fee: loanFeeOffer.clamp(loanMin, loanMax).toInt(), withOption: loanOption, optionPrice: optionPrice)
                : game.proposeTransfer(playerId: p.id, fee: fee, wage: wage, signingBonus: bonus, years: years);
            showResult(context, r);
            // Recusa: mantém a tela aberta para ajustar a proposta
            if (r.success) Navigator.pop(context);
          },
          child: Text(loanMode ? 'Propor empréstimo' : 'Enviar proposta'),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Agentes livres
// -----------------------------------------------------------------------------

class _FreeAgentsTab extends StatelessWidget {
  const _FreeAgentsTab();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final list = List<Player>.from(game.freeAgents)..sort((a, b) => b.overall.compareTo(a.overall));
    if (list.isEmpty) {
      return const Center(child: Text('Nenhum agente livre no momento.', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) {
        final p = list[i];
        return ListTile(
          dense: true,
          leading: overallAvatar(p),
          title: Text(p.name, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            '${p.position} • ${p.age} anos • pede ${formatMoney(game.wageDemand(p))}/mês • sem taxa',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          onTap: () => showDialog(context: context, builder: (_) => FreeAgentDialog(player: p)),
        );
      },
    );
  }
}

class FreeAgentDialog extends StatefulWidget {
  final Player player;
  const FreeAgentDialog({super.key, required this.player});

  @override
  State<FreeAgentDialog> createState() => _FreeAgentDialogState();
}

class _FreeAgentDialogState extends State<FreeAgentDialog> {
  late int demand;
  late int wage;
  int years = 2;

  @override
  void initState() {
    super.initState();
    demand = context.read<GameState>().wageDemand(widget.player);
    wage = demand;
  }

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameState>();
    final p = widget.player;
    return AlertDialog(
      backgroundColor: kCard,
      title: Text('${p.name} (${p.overall})', style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          infoRow('Posição / idade', '${p.position} • ${p.age} anos'),
          infoRow('Salário pedido', '${formatMoney(demand)}/mês'),
          MoneySlider(
            label: 'Salário oferecido',
            value: wage,
            min: roundTo(demand * 0.6, 1000),
            max: roundTo(demand * 1.5, 1000),
            step: 1000,
            onChanged: (v) => setState(() => wage = v),
          ),
          YearsPicker(value: years, onChanged: (v) => setState(() => years = v)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          onPressed: () {
            final r = game.signFreeAgent(p.id, wage: wage, years: years);
            showResult(context, r);
            Navigator.pop(context);
          },
          child: const Text('Assinar'),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Meu elenco: propostas recebidas, venda, renovação e rescisão
// -----------------------------------------------------------------------------

class _MySquadTab extends StatelessWidget {
  const _MySquadTab();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final t = game.userTeam!;
    final squad = List<Player>.from(t.squad)..sort((a, b) => b.overall.compareTo(a.overall));
    return ListView(
      children: [
        if (game.incomingOffers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: sectionTitle('PROPOSTAS RECEBIDAS'),
          ),
          for (final o in List<TransferOffer>.from(game.incomingOffers)) _offerCard(context, game, t, o),
        ],
        if (game.loanedOut.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: sectionTitle('EMPRESTADOS A OUTROS CLUBES'),
          ),
          for (final (club, p) in game.loanedOut)
            ListTile(
              dense: true,
              leading: overallAvatar(p),
              title: Text(p.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                '${p.position} • ${p.age} anos • no ${club.name} até o fim da temporada'
                '${game.loanOptions[p.id] != null ? ' • opção ${formatMoney(game.loanOptions[p.id]!)}' : ''}',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              trailing: ClubShield(shortName: club.shortName, size: 22),
              onTap: () async {
                final ok = await confirmDialog(context, 'Trazer ${p.name} de volta?',
                    'O empréstimo ao ${club.name} será encerrado agora (só com a janela aberta).');
                if (!ok || !context.mounted) return;
                showResult(context, game.recallLoan(p.id));
              },
            ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: sectionTitle('MEU ELENCO'),
        ),
        for (final p in squad)
          ListTile(
            dense: true,
            leading: overallAvatar(p),
            title: Row(
              children: [
                if (p.listed)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Text('📋', style: TextStyle(fontSize: 12)),
                  ),
                if (p.onLoan)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Text('🔁', style: TextStyle(fontSize: 12)),
                  ),
                Expanded(child: Text(p.name, style: const TextStyle(color: Colors.white))),
                if (!p.onLoan && p.contractYears <= 1)
                  const Text('último ano', style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
              ],
            ),
            subtitle: Text(
              '${p.position} • ${p.age} anos • ${formatMoney(p.wage)}/mês • '
              '${p.onLoan ? 'emprestado' : 'até ${game.seasonYear + p.contractYears - 1}'} • valor ${formatMoney(p.marketValue)}'
              '${p.listed ? ' • à venda por ${formatMoney(p.askingPrice)}' : ''}',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
            onTap: () => _actions(context, game, p),
          ),
      ],
    );
  }

  Widget _offerCard(BuildContext context, GameState game, Team t, TransferOffer o) {
    final p = t.findPlayer(o.playerId);
    final buyer = game.teamOrNull(o.buyerId);
    if (p == null || buyer == null) return const SizedBox.shrink();
    return Card(
      color: kCard,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClubShield(shortName: buyer.shortName, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${buyer.name} oferece ${formatMoney(o.amount)} por ${p.name}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Text(
              'Valor de mercado: ${formatMoney(p.marketValue)} • expira na rodada ${o.expiresRound}',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => game.rejectOffer(o),
                  child: const Text('Recusar', style: TextStyle(color: Colors.redAccent)),
                ),
                TextButton(
                  onPressed: () => showResult(context, game.counterOffer(o)),
                  child: const Text('Pedir +15%'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () async {
                    final pct = await showDialog<int>(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        backgroundColor: kCard,
                        title: const Text('Cláusula de revenda?', style: TextStyle(color: Colors.white)),
                        children: [
                          for (final v in [0, 10, 20])
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, v),
                              child: Text(
                                v == 0
                                    ? 'Sem cláusula: ${formatMoney(o.amount)}'
                                    : '$v% da próxima venda: ${formatMoney((o.amount * (1 - v / 200)).round())} agora',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    );
                    if (pct == null || !context.mounted) return;
                    showResult(context, game.acceptOffer(o, sellOnPercent: pct));
                  },
                  child: const Text('Aceitar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _actions(BuildContext context, GameState game, Player p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('${p.name} (${p.overall})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('Valor ${formatMoney(p.marketValue)} • multa ${formatMoney(p.releaseClause)}',
                  style: const TextStyle(color: Colors.white60)),
            ),
            if (!p.onLoan)
              ListTile(
                leading: Icon(p.listed ? Icons.remove_shopping_cart : Icons.sell, color: Colors.amber),
                title: Text(p.listed ? 'Retirar da lista de transferências' : 'Colocar à venda',
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (p.listed) {
                    game.setListed(p.id, false);
                  } else {
                    showDialog(context: context, builder: (_) => _ListDialog(player: p));
                  }
                },
              ),
            if (!p.onLoan)
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.orangeAccent),
                title: const Text('Emprestar a outro clube', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Ele joga fora até o fim da temporada e o outro clube paga o salário.',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(context: context, builder: (_) => _LoanOutDialog(player: p));
                },
              ),
            if (!p.onLoan)
              ListTile(
                leading: const Icon(Icons.edit_document, color: Colors.lightBlueAccent),
                title: const Text('Renovar contrato', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(context: context, builder: (_) => _RenewDialog(player: p));
                },
              ),
            if (p.onLoan && game.loanOptions.containsKey(p.id))
              ListTile(
                leading: const Icon(Icons.verified, color: Colors.greenAccent),
                title: Text('Exercer opção de compra (${formatMoney(game.loanOptions[p.id]!)})',
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  showResult(context, game.exerciseLoanOption(p.id));
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: Text(p.onLoan ? 'Devolver ao clube de origem' : 'Rescindir contrato',
                  style: const TextStyle(color: Colors.white)),
              subtitle: p.onLoan
                  ? null
                  : Text('Custo: ${formatMoney(game.releaseCost(p))} (3 salários)',
                      style: const TextStyle(color: Colors.white60)),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await confirmDialog(
                  context,
                  p.onLoan ? 'Devolver ${p.name}?' : 'Rescindir com ${p.name}?',
                  p.onLoan
                      ? 'O empréstimo será encerrado agora.'
                      : 'Ele vira agente livre e o clube paga ${formatMoney(game.releaseCost(p))}.',
                );
                if (!ok || !context.mounted) return;
                showResult(context, game.releasePlayer(p.id));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ListDialog extends StatefulWidget {
  final Player player;
  const _ListDialog({required this.player});

  @override
  State<_ListDialog> createState() => _ListDialogState();
}

class _ListDialogState extends State<_ListDialog> {
  late int price;

  @override
  void initState() {
    super.initState();
    price = widget.player.marketValue;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    return AlertDialog(
      backgroundColor: kCard,
      title: Text('Vender ${p.name}', style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          infoRow('Valor de mercado', formatMoney(p.marketValue)),
          MoneySlider(
            label: 'Preço pedido',
            value: price,
            min: roundTo(p.marketValue * 0.5, 50000),
            max: roundTo(p.marketValue * 2, 50000),
            step: 50000,
            onChanged: (v) => setState(() => price = v),
          ),
          const Text(
            'Clubes da IA mandam propostas a cada rodada. Preço alto = menos propostas.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          onPressed: () {
            context.read<GameState>().setListed(p.id, true, price: price);
            Navigator.pop(context);
          },
          child: const Text('Colocar à venda'),
        ),
      ],
    );
  }
}

class _RenewDialog extends StatefulWidget {
  final Player player;
  const _RenewDialog({required this.player});

  @override
  State<_RenewDialog> createState() => _RenewDialogState();
}

class _RenewDialogState extends State<_RenewDialog> {
  late int demand;
  late int wage;
  int years = 2;

  @override
  void initState() {
    super.initState();
    demand = context.read<GameState>().renewalDemand(widget.player);
    wage = demand;
  }

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameState>();
    final p = widget.player;
    return AlertDialog(
      backgroundColor: kCard,
      title: Text('Renovar com ${p.name}', style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          infoRow('Salário atual', '${formatMoney(p.wage)}/mês'),
          infoRow('Pedido para renovar', '${formatMoney(demand)}/mês'),
          infoRow('Contrato atual', 'até ${game.seasonYear + p.contractYears - 1}'),
          MoneySlider(
            label: 'Novo salário',
            value: wage,
            min: roundTo(demand * 0.7, 1000),
            max: roundTo(demand * 1.5, 1000),
            step: 1000,
            onChanged: (v) => setState(() => wage = v),
          ),
          YearsPicker(
            label: 'Temporadas a mais',
            value: years,
            onChanged: (v) => setState(() => years = v),
          ),
          Text('Novo contrato até ${game.seasonYear + years}',
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          onPressed: () {
            final r = game.renewContract(p.id, wage: wage, years: years);
            showResult(context, r);
            Navigator.pop(context);
          },
          child: const Text('Propor'),
        ),
      ],
    );
  }
}

/// Emprestar um jogador do nosso elenco: escolhe o clube interessado e as condições.
class _LoanOutDialog extends StatefulWidget {
  final Player player;
  const _LoanOutDialog({required this.player});

  @override
  State<_LoanOutDialog> createState() => _LoanOutDialogState();
}

class _LoanOutDialogState extends State<_LoanOutDialog> {
  Team? club;
  int fee = 0;
  bool withOption = false;
  late int optionPrice;

  @override
  void initState() {
    super.initState();
    optionPrice = context.read<GameState>().suggestedOptionPrice(widget.player);
  }

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameState>();
    final p = widget.player;
    final suitors = game.loanSuitors(p);
    final offered = suitors.where((s) => s.$1.id == club?.id).firstOrNull?.$2 ?? 0;
    return AlertDialog(
      backgroundColor: kCard,
      title: Text('Emprestar ${p.name}', style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              game.transferWindowOpen
                  ? 'Clubes interessados (o salário de ${formatMoney(p.wage)}/mês passa para eles):'
                  : '🔴 ${game.windowLabel}. Empréstimos só com a janela aberta.',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            if (suitors.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Nenhum clube interessado agora.', style: TextStyle(color: Colors.white54)),
              ),
            for (final (t, f) in suitors)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                selected: club?.id == t.id,
                selectedTileColor: Colors.white10,
                leading: ClubShield(shortName: t.shortName, size: 22),
                title: Text(t.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text('${t.isForeign ? t.country : 'Série ${'ABCD'[t.division - 1]}'} • oferece ${formatMoney(f)}',
                    style: const TextStyle(color: Colors.white60, fontSize: 11)),
                trailing: Icon(club?.id == t.id ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: club?.id == t.id ? Colors.orangeAccent : Colors.white38),
                onTap: () => setState(() {
                  club = t;
                  fee = f;
                }),
              ),
            if (club != null) ...[
              const Divider(color: Colors.white24),
              MoneySlider(
                label: 'Taxa pedida (oferta ${formatMoney(offered)})',
                value: fee,
                min: 0,
                max: max(offered * 2, 100000),
                step: 50000,
                onChanged: (v) => setState(() => fee = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: withOption,
                onChanged: (v) => setState(() => withOption = v),
                title: const Text('Incluir opção de compra', style: TextStyle(color: Colors.white70, fontSize: 13)),
                subtitle: const Text('No fim do empréstimo o clube pode comprá-lo por esse valor.',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ),
              if (withOption)
                MoneySlider(
                  label: 'Valor da opção',
                  value: optionPrice,
                  min: roundTo(p.marketValue * 0.6, 50000),
                  max: max(roundTo(p.marketValue * 2, 50000), roundTo(p.marketValue * 0.6, 50000) + 50000),
                  step: 50000,
                  onChanged: (v) => setState(() => optionPrice = v),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
          onPressed: club == null
              ? null
              : () {
                  final r = game.loanOut(p.id, club!.id, fee: fee, withOption: withOption, optionPrice: optionPrice);
                  showResult(context, r);
                  if (r.success) Navigator.pop(context);
                },
          child: const Text('Emprestar'),
        ),
      ],
    );
  }
}
