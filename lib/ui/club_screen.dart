import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/engine.dart';
import '../game/models.dart';
import '../game/economy.dart';
import 'widgets.dart';

/// Treino, comissão técnica, base, olheiros, ingressos e sócios.
class ClubScreen extends StatelessWidget {
  const ClubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final t = game.userTeam;
    if (t == null || !game.managesClub) {
      return Scaffold(
        appBar: AppBar(title: const Text('Clube'), backgroundColor: kGreen),
        body: const Center(child: Text('Você não administra um clube.', style: TextStyle(color: Colors.white70))),
      );
    }
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Clube - ${t.name}'),
          backgroundColor: kGreen,
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.amber,
            tabs: [Tab(text: 'Treino'), Tab(text: 'Comissão'), Tab(text: 'Base'), Tab(text: 'Olheiros'), Tab(text: 'Ingressos')],
          ),
        ),
        body: const TabBarView(children: [_TrainingTab(), _StaffTab(), _AcademyTab(), _ScoutTab(), _TicketsTab()]),
      ),
    );
  }
}

class _TrainingTab extends StatelessWidget {
  const _TrainingTab();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sectionTitle('FOCO DO TREINO'),
        RadioGroup<String>(
          groupValue: game.trainingFocus,
          onChanged: (v) => game.setTraining(focus: v),
          child: Column(
            children: [
              for (final e in kTrainingFocus.entries)
                RadioListTile<String>(
                  value: e.key,
                  title: Text(e.value, style: const TextStyle(color: Colors.white)),
                ),
            ],
          ),
        ),
        sectionTitle('INTENSIDADE'),
        RadioGroup<String>(
          groupValue: game.trainingIntensity,
          onChanged: (v) => game.setTraining(intensity: v),
          child: Column(
            children: [
              for (final e in kTrainingIntensity.entries)
                RadioListTile<String>(
                  value: e.key,
                  title: Text(e.value, style: const TextStyle(color: Colors.white)),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('O treino acontece todo dia: dá experiência a todos e mexe na energia do elenco.',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      ],
    );
  }
}

class _StaffTab extends StatelessWidget {
  const _StaffTab();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final (key, label, emoji, effect) in kStaffRoles)
          Card(
            color: kCard,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text(effect, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                        Text('Nível ${game.staff[key] ?? 0} • ${formatMoney(game.staffWage(game.staff[key] ?? 0))}/mês',
                            style: const TextStyle(color: Colors.amber, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: (game.staff[key] ?? 0) >= 3
                        ? null
                        : () async {
                            final lvl = (game.staff[key] ?? 0) + 1;
                            final ok = await confirmDialog(context, '$label nível $lvl',
                                'Contratação: ${formatMoney(game.staffWage(lvl) * 3)}. Salário: ${formatMoney(game.staffWage(lvl))}/mês.');
                            if (ok && context.mounted) showResult(context, game.hireStaff(key));
                          },
                    child: Text((game.staff[key] ?? 0) >= 3 ? 'Máximo' : 'Melhorar'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AcademyTab extends StatelessWidget {
  const _AcademyTab();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final list = List<Player>.from(game.academy)..sort((a, b) => b.potential.compareTo(a.potential));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Garotos de 15 a 19 anos. Chegam 4 por temporada e treinam todo dia (o CT acelera). '
            'Aos 20 anos, quem não subir vai embora.',
            style: TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 8),
        if (list.isEmpty) const Text('A base está vazia.', style: TextStyle(color: Colors.white54)),
        for (final y in list)
          Card(
            color: kCard,
            child: ListTile(
              leading: overallAvatar(y),
              title: Text(y.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text('${y.position} • ${y.age} anos • potencial ${y.potential}',
                  style: const TextStyle(color: Colors.white60)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Dispensar',
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    onPressed: () => game.releaseYouth(y.id),
                  ),
                  IconButton(
                    tooltip: 'Subir para o profissional',
                    icon: const Icon(Icons.arrow_upward, color: Colors.greenAccent),
                    onPressed: () => showResult(context, game.promoteYouth(y.id)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ScoutTab extends StatelessWidget {
  const _ScoutTab();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final regions = game.scoutRegions;
    final pool = <(String, Player)>[];
    for (final t in game.allTeams) {
      if (t.id == game.userTeamId) continue;
      for (final p in t.squad) {
        if (game.scouted.contains(p.id) && p.potential - p.overall >= 6 && p.age <= 23) pool.add((t.name, p));
      }
    }
    for (final p in game.freeAgents) {
      if (game.scouted.contains(p.id) && p.potential - p.overall >= 6) pool.add(('Agente livre', p));
    }
    pool.sort((a, b) => b.$2.potential.compareTo(a.$2.potential));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            const Expanded(child: Text('Região observada', style: TextStyle(color: Colors.white70))),
            DropdownButton<String>(
              value: game.scoutRegion,
              dropdownColor: kCard,
              style: const TextStyle(color: Colors.white),
              items: [for (final (k, v) in regions) DropdownMenuItem(value: k, child: Text(v))],
              onChanged: (v) => game.setScoutRegion(v ?? game.scoutRegion),
            ),
          ],
        ),
        Text('Jogadores observados: ${game.scouted.length}. O olheiro-chefe (Comissão) aumenta o ritmo.',
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
        sectionTitle('PROMESSAS ENCONTRADAS'),
        if (pool.isEmpty) const Text('Nenhuma promessa ainda. Volte em alguns dias.', style: TextStyle(color: Colors.white54)),
        for (final (club, p) in pool.take(40))
          ListTile(
            dense: true,
            leading: overallAvatar(p),
            title: Text(p.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text('${p.position} • ${p.age} anos • $club • potencial ${p.potential}',
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ),
      ],
    );
  }
}

class _TicketsTab extends StatelessWidget {
  const _TicketsTab();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final t = game.userTeam!;
    final crowd = (attendance(t, game.positionOf(t.id)) * game.ticketDemand(t)).round().clamp(0, t.effectiveCapacity);
    final members = game.expectedMembers(t);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        sectionTitle('INGRESSOS'),
        Text('Preço médio: ${formatMoney(game.ticketPriceFor(t))} (${(game.ticketMultiplier * 100).round()}% do preço base)',
            style: const TextStyle(color: Colors.white)),
        Slider(
          value: game.ticketMultiplier,
          min: 0.5,
          max: 2.0,
          divisions: 15,
          label: '${(game.ticketMultiplier * 100).round()}%',
          onChanged: game.setTicketMultiplier,
        ),
        infoRow('Público estimado por jogo', '$crowd de ${t.effectiveCapacity}'),
        infoRow('Renda estimada por jogo', formatMoney(crowd * game.ticketPriceFor(t))),
        sectionTitle('SÓCIO-TORCEDOR'),
        Text('Mensalidade: ${formatMoney(game.memberPrice)}', style: const TextStyle(color: Colors.white)),
        Slider(
          value: game.memberPrice.toDouble(),
          min: 10,
          max: 200,
          divisions: 38,
          label: formatMoney(game.memberPrice),
          onChanged: (v) => game.setMemberPrice(v.round()),
        ),
        infoRow('Sócios estimados', '$members'),
        infoRow('Receita mensal estimada', formatMoney(members * game.memberPrice)),
        const Text('A torcida feliz traz mais público e mais sócios.', style: TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }
}
