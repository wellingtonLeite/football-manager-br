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
  int? maxPrice;

  static const Map<String, int?> _priceFilters = {
    'Sem limite': null,
    'Até R\$ 5 mi': 5000000,
    'Até R\$ 10 mi': 10000000,
    'Até R\$ 20 mi': 20000000,
    'Até R\$ 50 mi': 50000000,
  };

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final list = game.marketPlayers(position: position, maxPrice: maxPrice, onlyListed: onlyListed, region: region);
    final regions = <String, String>{
      'BRA': '🇧🇷 Brasil',
      for (final e in kLeagueNames.entries) e.key: '${kLeagueCountry[e.key]} • ${e.value}',
      'AME': '🌎 América do Sul (copas)',
    };
    return Column(
      children: [
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _chip('Todos', position == null, () => setState(() => position = null)),
              for (final p in kPositions) _chip(p, position == p, () => setState(() => position = p)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Switch(value: onlyListed, onChanged: (v) => setState(() => onlyListed = v)),
              const Text('Só listados', style: TextStyle(color: Colors.white70)),
              const Spacer(),
              DropdownButton<int?>(
                value: maxPrice,
                dropdownColor: kCard,
                style: const TextStyle(color: Colors.white),
                items: [
                  for (final e in _priceFilters.entries)
                    DropdownMenuItem<int?>(value: e.value, child: Text(e.key)),
                ],
                onChanged: (v) => setState(() => maxPrice = v),
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
                    final asking = game.askingPriceFor(team, p);
                    return ListTile(
                      dense: true,
                      leading: overallAvatar(p),
                      title: Row(
                        children: [
                          if (p.listed)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Text('📋', style: TextStyle(fontSize: 12)),
                            ),
                          Expanded(child: Text(p.name, style: const TextStyle(color: Colors.white))),
                          ClubShield(shortName: team.shortName, size: 16),
                        ],
                      ),
                      subtitle: Text(
                        '${p.position} • ${p.age} anos • ${team.shortName} • Pedem ${formatMoney(asking)}'
                        '${game.isScouted(p) ? ' • pot. ${p.potential}' : ''}${p.nat != 'BRA' ? ' • ${p.nat}' : ''}',
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => _OfferDialog(seller: team, player: p),
                      ),
                    );
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

class _OfferDialog extends StatefulWidget {
  final Team seller;
  final Player player;
  const _OfferDialog({required this.seller, required this.player});

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  late int fee;
  late int wage;
  int bonus = 0;
  int years = 3;
  bool loanOption = false;
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
  }

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameState>();
    final p = widget.player;
    final feeMax = max(p.releaseClause, asking * 2);
    final starter = widget.seller.startingIds.contains(p.id);
    return AlertDialog(
      backgroundColor: kCard,
      title: Text('${p.name} (${p.overall})', style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            infoRow('Clube', widget.seller.name),
            infoRow('Posição / idade', '${p.position} • ${p.age} anos'),
            infoRow('Valor de mercado', formatMoney(p.marketValue)),
            infoRow('Preço pedido', formatMoney(asking)),
            infoRow('Multa rescisória', formatMoney(p.releaseClause)),
            infoRow('Salário atual', '${formatMoney(p.wage)}/mês'),
            infoRow('Situação', starter ? 'Titular no clube' : (p.listed ? 'Na lista de transferências' : 'Reserva')),
            infoRow('Potencial', game.isScouted(p) ? '${p.potential}' : '? (observe o jogador)'),
            infoRow('Nacionalidade', p.nat),
            if (!game.isScouted(p))
              TextButton(
                onPressed: () => setState(() => showResult(context, game.scoutPlayer(p.id))),
                child: const Text('🔭 Mandar observar (R\$ 50 mil)'),
              ),
            infoRow('Comissão do empresário (5%)', formatMoney(game.agentFee(fee))),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: loanOption,
              onChanged: (v) => setState(() => loanOption = v),
              title: const Text('Empréstimo com opção de compra', style: TextStyle(color: Colors.white70, fontSize: 13)),
              subtitle: Text('Taxa dobrada; compra depois por ${formatMoney(roundTo(p.marketValue * 1.1, 50000))}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ),
            const Divider(color: Colors.white24),
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
            Text(
              'Total agora: ${formatMoney(fee + bonus)}',
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        TextButton(
          onPressed: () {
            final r = game.proposeLoan(p.id, withOption: loanOption);
            showResult(context, r);
            Navigator.pop(context);
          },
          child: Text('Empréstimo (${formatMoney(game.loanFee(p) * (loanOption ? 2 : 1))})'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          onPressed: () {
            final r = game.proposeTransfer(
              playerId: p.id,
              fee: fee,
              wage: wage,
              signingBonus: bonus,
              years: years,
            );
            showResult(context, r);
            Navigator.pop(context);
          },
          child: const Text('Enviar proposta'),
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
          onTap: () => showDialog(context: context, builder: (_) => _FreeAgentDialog(player: p)),
        );
      },
    );
  }
}

class _FreeAgentDialog extends StatefulWidget {
  final Player player;
  const _FreeAgentDialog({required this.player});

  @override
  State<_FreeAgentDialog> createState() => _FreeAgentDialogState();
}

class _FreeAgentDialogState extends State<_FreeAgentDialog> {
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
    final buyer = game.teams.where((x) => x.id == o.buyerId).firstOrNull;
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
