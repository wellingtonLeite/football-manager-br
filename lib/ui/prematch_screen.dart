import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/engine.dart';
import '../game/models.dart';
import 'audio_service.dart';
import 'live_match_screen.dart';
import 'shield.dart';
import 'widgets.dart';

/// Antes do apito: escolha da tática e dos 11 titulares.
class PreMatchScreen extends StatelessWidget {
  const PreMatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final m = game.userMatchCurrent;
    final team = game.userTeam;
    if (m == null || team == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pré-jogo'), backgroundColor: kGreen),
        body: const Center(child: Text('Nenhum jogo hoje.', style: TextStyle(color: Colors.white70))),
      );
    }
    final opp = game.teamById(m.homeId == team.id ? m.awayId : m.homeId);
    final home = m.homeId == team.id;
    final agg = game.aggregateBefore(m);
    final starters = team.startingPlayers;
    final bench = team.squad.where((p) => !team.startingIds.contains(p.id)).toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    const order = ['GOL', 'ZAG', 'LAT', 'VOL', 'MEI', 'ATA'];
    starters.sort((a, b) => order.indexOf(a.position).compareTo(order.indexOf(b.position)));
    final strength = game.teamStrength(team, starters);
    final oppStrength = game.teamStrength(opp, opp.startingPlayers);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pré-jogo'),
        backgroundColor: kGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Escalação automática',
            onPressed: game.resetUserLineup,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: kCard,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(matchLabel(m), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _side(team, strength),
                      const Text('x', style: TextStyle(color: Colors.white, fontSize: 22)),
                      _side(opp, oppStrength),
                    ],
                  ),
                  Text(home ? 'Em casa (${team.stadium})' : 'Fora de casa (${opp.stadium})',
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  if (agg != null)
                    Text('Ida: ${team.shortName} ${agg.$1} x ${agg.$2} ${opp.shortName}',
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                  if (m.isKnockout && m.leg != 1)
                    const Text('Mata-mata: empate no placar (ou no agregado) vai para os pênaltis.',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ),
          sectionTitle('FORMAÇÃO'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in Formation.values)
                ChoiceChip(
                  label: Text(f.label),
                  selected: team.formation == f,
                  selectedColor: Colors.green,
                  backgroundColor: Colors.grey.shade900,
                  labelStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  onSelected: (_) => game.setFormation(f),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Escalação ideal: ${team.formation.quota.entries.where((e) => e.key != 'GOL').map((e) => '${e.value} ${e.key}').join(', ')}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          sectionTitle('TÁTICA'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in Tactic.values)
                ChoiceChip(
                  label: Text(kTacticLabels[t] ?? ''),
                  selected: game.userTactic == t,
                  selectedColor: Colors.green,
                  backgroundColor: Colors.grey.shade900,
                  labelStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  onSelected: (_) => game.setUserTactic(t),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(kTacticDesc[game.userTactic] ?? '', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ),
          sectionTitle('TITULARES (${starters.length}/11) — toque para trocar'),
          for (final p in starters)
            ListTile(
              dense: true,
              leading: overallAvatar(p),
              title: Text(p.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text('${p.position} • ⚡${p.energy} • 😊${p.morale}${p.injured ? ' • 🚑' : ''}${p.suspended > 0 ? ' • 🟥 suspenso' : ''}${p.yellowCards == 2 ? ' • 🟨🟨 pendurado' : ''}',
                  style: TextStyle(color: p.energy < 60 ? Colors.orangeAccent : Colors.white60, fontSize: 11)),
              trailing: const Icon(Icons.swap_vert, color: Colors.white54),
              onTap: () => _pickReplacement(context, game, p, bench),
            ),
          sectionTitle('RESERVAS'),
          for (final p in bench)
            ListTile(
              dense: true,
              leading: overallAvatar(p, radius: 16),
              title: Text('${p.injured ? '🚑 ' : ''}${p.suspended > 0 ? '🟥 ' : ''}${p.name}', style: const TextStyle(color: Colors.white70)),
              subtitle: Text('${p.position} • ⚡${p.energy}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              onTap: p.unavailable
                  ? null
                  : () {
                      final err = game.toggleStarter(p.id);
                      if (err != null) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(content: Text(err)));
                      }
                    },
            ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: starters.length < 11
                  ? null
                  : () async {
                      context.read<AudioService>().playButton();
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveMatchScreen()));
                      // Fim de jogo: volta direto para a tela da data (e a coletiva)
                      if (context.mounted) Navigator.pop(context);
                    },
              child: Text(starters.length < 11 ? 'Escale 11 titulares' : '▶️ Começar a partida',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _side(Team t, double strength) => Column(
        children: [
          ClubShield(shortName: t.shortName, size: 40),
          const SizedBox(height: 4),
          Text(t.shortName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text('Força ${strength.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      );

  void _pickReplacement(BuildContext context, GameState game, Player out, List<Player> bench) {
    final options = bench.where((p) => !p.unavailable).toList()
      ..sort((a, b) {
        final pa = a.position == out.position ? 0 : 1;
        final pb = b.position == out.position ? 0 : 1;
        return pa != pb ? pa.compareTo(pb) : b.overall.compareTo(a.overall);
      });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCard,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.65,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Quem entra no lugar de ${out.name} (${out.position})?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final p in options)
                    ListTile(
                      leading: overallAvatar(p, radius: 16),
                      title: Text(p.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${p.position} • ⚡${p.energy}',
                          style: TextStyle(color: p.position == out.position ? Colors.greenAccent : Colors.white54)),
                      onTap: () {
                        game.swapStarter(out.id, p.id);
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
