import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/engine.dart';
import '../game/models.dart';
import '../game/data.dart';
import '../game/economy.dart';
import 'audio_service.dart';
import 'screens.dart';
import 'shield.dart';
import 'widgets.dart';

/// Fase 10C — criação do atleta.
class PlayerCreateScreen extends StatefulWidget {
  const PlayerCreateScreen({super.key});

  @override
  State<PlayerCreateScreen> createState() => _PlayerCreateScreenState();
}

class _PlayerCreateScreenState extends State<PlayerCreateScreen> {
  final _name = TextEditingController();
  String nationality = 'Brasil';
  String position = 'ATA';
  int age = 17;
  String style = 'Equilibrado';
  late final List<ClubInfo> clubs = startingClubOptions();
  late ClubInfo club = clubs.first;

  static const nationalities = ['Brasil', 'Argentina', 'Uruguai', 'Portugal', 'Colômbia', 'Paraguai'];
  static const positions = {
    'GOL': 'Goleiro', 'ZAG': 'Zagueiro', 'LAT': 'Lateral', 'VOL': 'Volante', 'MEI': 'Meia', 'ATA': 'Atacante',
  };
  static const styles = {
    'Equilibrado': 'Começa sem pontos fracos',
    'Físico': 'Aguenta mais jogos seguidos',
    'Craque da base': '+3 de overall inicial',
  };

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overall = startingOverall(age, style);
    return Scaffold(
      appBar: AppBar(title: const Text('Criar jogador'), backgroundColor: kGreen),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            style: const TextStyle(color: Colors.white),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome do jogador', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
          ),
          const SizedBox(height: 12),
          _row('Nacionalidade', DropdownButton<String>(
            value: nationality,
            dropdownColor: kCard,
            style: const TextStyle(color: Colors.white),
            items: [for (final n in nationalities) DropdownMenuItem(value: n, child: Text(n))],
            onChanged: (v) => setState(() => nationality = v ?? nationality),
          )),
          _row('Posição', DropdownButton<String>(
            value: position,
            dropdownColor: kCard,
            style: const TextStyle(color: Colors.white),
            items: [for (final e in positions.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => position = v ?? position),
          )),
          Text('Idade inicial: $age anos', style: const TextStyle(color: Colors.white70)),
          Slider(value: age.toDouble(), min: 16, max: 20, divisions: 4, onChanged: (v) => setState(() => age = v.round())),
          sectionTitle('ESTILO'),
          RadioGroup<String>(
            groupValue: style,
            onChanged: (v) => setState(() => style = v ?? style),
            child: Column(
              children: [
                for (final e in styles.entries)
                  RadioListTile<String>(
                    value: e.key,
                    title: Text(e.key, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(e.value, style: const TextStyle(color: Colors.white54)),
                  ),
              ],
            ),
          ),
          sectionTitle('PRIMEIRO CLUBE (propostas recebidas)'),
          RadioGroup<String>(
            groupValue: club.shortName,
            onChanged: (v) => setState(() => club = clubs.firstWhere((c) => c.shortName == v)),
            child: Column(
              children: [
                for (final c in clubs)
                  RadioListTile<String>(
                    value: c.shortName,
                    secondary: ClubShield(shortName: c.shortName, size: 28),
                    title: Text(c.name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text('Série ${'ABCD'[c.division - 1]} • ${c.state} • ${c.stadium}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Overall inicial: $overall', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () {
                context.read<AudioService>().playButton();
                context.read<GameState>().startPlayerCareer(
                      name: _name.text,
                      nationality: nationality,
                      position: position,
                      age: age,
                      style: style,
                      teamId: club.shortName.toLowerCase(),
                    );
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
              },
              child: const Text('⚽ Começar a carreira', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, Widget child) => Row(
        children: [Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))), child],
      );
}

/// Fase 10C — carreira do atleta: números, contrato, propostas e aposentadoria.
class PlayerCareerScreen extends StatelessWidget {
  const PlayerCareerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final pc = game.playerCareer;
    if (pc == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Minha carreira'), backgroundColor: kGreen),
        body: const Center(child: Text('Sem carreira de jogador.', style: TextStyle(color: Colors.white70))),
      );
    }
    final p = game.userPlayer;
    final team = game.userTeam;
    final s = game.currentPlayerStats;
    return Scaffold(
      appBar: AppBar(title: Text(game.career.name), backgroundColor: kGreen),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (p != null && team != null)
            Card(
              color: kCard,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        overallAvatar(p, radius: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${p.position} • ${p.age} anos • ${pc.nationality}', style: const TextStyle(color: Colors.white)),
                              Text(team.name, style: const TextStyle(color: Colors.greenAccent)),
                            ],
                          ),
                        ),
                        ClubShield(shortName: team.shortName, size: 32),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    infoRow('Salário', '${formatMoney(p.wage)}/mês'),
                    infoRow('Contrato até', '${game.seasonYear + p.contractYears - 1}'),
                    infoRow('Valor de mercado', formatMoney(p.marketValue)),
                    infoRow('Situação', team.startingIds.contains(p.id) ? 'Titular' : 'Reserva'),
                    infoRow('Energia / moral', '⚡${p.energy} • 😊${p.morale}'),
                    infoRow('Seleção Brasileira', '${pc.caps} jogos'),
                    infoRow('Última nota', pc.lastRating == 0 ? '—' : pc.lastRating.toStringAsFixed(1)),
                    infoRow('Ganhos na carreira', formatMoney(game.career.earnings)),
                  ],
                ),
              ),
            ),
          sectionTitle('TEMPORADA ${game.seasonYear}'),
          Card(
            color: kCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: s == null || s.games == 0
                  ? const Text('Ainda sem jogos nesta temporada.', style: TextStyle(color: Colors.white54))
                  : Column(
                      children: [
                        infoRow('Jogos', '${s.games}'),
                        infoRow('Gols', '${s.goals}'),
                        infoRow('Assistências', '${s.assists}'),
                        infoRow('Nota média', s.avgRating.toStringAsFixed(2),
                            valueColor: s.avgRating >= 7 ? Colors.greenAccent : (s.avgRating < 6 ? Colors.redAccent : Colors.white)),
                      ],
                    ),
            ),
          ),
          if (!pc.retired && p != null) ...[
            sectionTitle('NEGOCIAÇÕES'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => showResult(context, game.askRaise()),
                  icon: const Icon(Icons.attach_money),
                  label: const Text('Pedir aumento'),
                ),
                ElevatedButton.icon(
                  onPressed: pc.transferRequested ? null : () => showResult(context, game.requestTransfer()),
                  icon: const Icon(Icons.flight_takeoff),
                  label: Text(pc.transferRequested ? 'Transferência pedida' : 'Pedir transferência'),
                ),
                if (p.age >= 33)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, foregroundColor: Colors.white),
                    onPressed: () async {
                      final ok = await confirmDialog(context, 'Pendurar as chuteiras?', 'Sua carreira de jogador termina agora.');
                      if (ok) game.retirePlayer();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Aposentar'),
                  ),
              ],
            ),
            sectionTitle('PROPOSTAS DE CLUBES'),
            if (game.career.offers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Nenhuma proposta. Boas notas e o pedido de transferência atraem clubes.',
                    style: TextStyle(color: Colors.white54)),
              ),
            for (final o in List<JobOffer>.from(game.career.offers))
              Builder(builder: (context) {
                final t = game.teamById(o.teamId);
                return Card(
                  color: kCard,
                  child: ListTile(
                    leading: ClubShield(shortName: t.shortName, size: 28),
                    title: Text('${t.name} (${compName(divisionComp(t.division))})', style: const TextStyle(color: Colors.white)),
                    subtitle: Text('Salário ${formatMoney(o.salary)}/mês', style: const TextStyle(color: Colors.white60)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.redAccent),
                          onPressed: () => game.rejectJobOffer(o),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.greenAccent),
                          onPressed: () async {
                            final ok = await confirmDialog(context, 'Ir para o ${t.name}?', 'Contrato de 3 temporadas.');
                            if (ok && context.mounted) showResult(context, game.acceptPlayerOffer(o));
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
          sectionTitle('HISTÓRICO POR TEMPORADA'),
          for (final x in pc.seasons.reversed.where((x) => x.games > 0))
            ListTile(
              dense: true,
              title: Text('${x.season} • ${x.team}', style: const TextStyle(color: Colors.white)),
              subtitle: Text('${x.games} jogos • ${x.goals} gols • ${x.assists} assist. • nota ${x.avgRating.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white60)),
            ),
          if (game.career.trophies.isNotEmpty) ...[
            sectionTitle('TÍTULOS'),
            for (final t in game.career.trophies.reversed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text('🏆 $t', style: const TextStyle(color: Colors.amber)),
              ),
          ],
          sectionTitle('LINHA DO TEMPO'),
          for (final line in game.career.log.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Text('• $line', style: const TextStyle(color: Colors.white70)),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
