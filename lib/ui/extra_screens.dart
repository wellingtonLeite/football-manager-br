import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/engine.dart';
import '../game/models.dart';
import '../game/data.dart';
import 'shield.dart';
import 'widgets.dart';

/// Conquistas desbloqueadas na carreira.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final done = game.achievements;
    return Scaffold(
      appBar: AppBar(title: Text('Conquistas (${done.length}/${kAchievements.length})'), backgroundColor: kGreen),
      body: ListView(
        children: [
          for (final e in kAchievements.entries)
            ListTile(
              leading: Text(done.contains(e.key) ? e.value.$1 : '🔒', style: const TextStyle(fontSize: 26)),
              title: Text(e.value.$2,
                  style: TextStyle(color: done.contains(e.key) ? Colors.amber : Colors.white54, fontWeight: FontWeight.bold)),
              subtitle: Text(e.value.$3, style: const TextStyle(color: Colors.white60)),
            ),
        ],
      ),
    );
  }
}

/// Seleção Brasileira: convocação, retrospecto e jogos.
class NationalTeamScreen extends StatelessWidget {
  const NationalTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final n = game.national;
    if (n == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seleção Brasileira'), backgroundColor: kGreen),
        body: const Center(child: Text('Você não é o técnico da Seleção.', style: TextStyle(color: Colors.white70))),
      );
    }
    final pool = game.brazilianPool(n: 60);
    return Scaffold(
      appBar: AppBar(title: const Text('🇧🇷 Seleção Brasileira'), backgroundColor: Colors.green.shade800),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: kCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Retrospecto: ${n.wins}V ${n.draws}E ${n.losses}D • gols ${n.goalsFor} x ${n.goalsAgainst}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Convocados: ${n.squad.length}/26 • Jogos nas Datas FIFA (a cada 20 datas). '
                      'Copa América nos anos 2028, 2032... e Copa do Mundo em 2030, 2034... (no fim da temporada).',
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ),
          sectionTitle('CONVOCAÇÃO (toque para chamar ou cortar)'),
          for (final (t, p) in pool)
            CheckboxListTile(
              dense: true,
              value: n.squad.contains(p.id),
              onChanged: (v) {
                final list = List<String>.from(n.squad);
                if (v == true && list.length < 26) {
                  list.add(p.id);
                } else {
                  list.remove(p.id);
                }
                game.setNationalSquad(list);
              },
              secondary: overallAvatar(p),
              title: Text(p.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text('${p.position} • ${p.age} anos • ${t.name}${p.injured ? ' • 🚑' : ''}',
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ),
          sectionTitle('ÚLTIMOS JOGOS'),
          for (final l in n.log.reversed.take(20))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text('• $l', style: const TextStyle(color: Colors.white70)),
            ),
        ],
      ),
    );
  }
}

/// Editor: corrigir nomes de clubes, técnicos, estádios e jogadores.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  String filter = 'BRA1';

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final options = <String, String>{
      'BRA1': 'Série A', 'BRA2': 'Série B', 'BRA3': 'Série C', 'BRA4': 'Série D',
      for (final e in kLeagueNames.entries) e.key: e.value,
      'CUP': 'Outros clubes das copas',
    };
    final list = game.allTeams
        .where((t) => filter == 'CUP' ? (t.isForeign && t.league.isEmpty) : t.leagueKey == filter)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(title: const Text('Editor'), backgroundColor: kGreen),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
              value: filter,
              isExpanded: true,
              dropdownColor: kCard,
              style: const TextStyle(color: Colors.white),
              items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() => filter = v ?? filter),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final t in list)
                  ListTile(
                    leading: ClubShield(shortName: t.shortName, size: 28),
                    title: Text(t.name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${t.coach} • ${t.stadium}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    trailing: const Icon(Icons.edit, color: Colors.white54),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _TeamEditor(teamId: t.id))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamEditor extends StatelessWidget {
  final String teamId;
  const _TeamEditor({required this.teamId});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final t = game.teamById(teamId);
    final squad = List<Player>.from(t.squad)..sort((a, b) => kPositions.indexOf(a.position).compareTo(kPositions.indexOf(b.position)));
    return Scaffold(
      appBar: AppBar(title: Text('Editar ${t.name}'), backgroundColor: kGreen),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _field(context, 'Nome do clube', t.name, (v) => game.editTeam(t.id, name: v)),
          _field(context, 'Técnico', t.coach, (v) => game.editTeam(t.id, coach: v)),
          _field(context, 'Estádio', t.stadium, (v) => game.editTeam(t.id, stadium: v)),
          sectionTitle('JOGADORES (toque para editar)'),
          for (final p in squad)
            ListTile(
              dense: true,
              leading: overallAvatar(p),
              title: Text(p.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text('${p.position} • ${p.age} anos • ${p.nat}', style: const TextStyle(color: Colors.white60)),
              onTap: () => showDialog(context: context, builder: (_) => _PlayerEditor(teamId: t.id, player: p)),
            ),
        ],
      ),
    );
  }

  Widget _field(BuildContext context, String label, String value, void Function(String) onSave) => ListTile(
        title: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        subtitle: Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
        trailing: const Icon(Icons.edit, color: Colors.white54),
        onTap: () async {
          final ctrl = TextEditingController(text: value);
          final v = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: kCard,
              title: Text(label, style: const TextStyle(color: Colors.white)),
              content: TextField(controller: ctrl, style: const TextStyle(color: Colors.white), autofocus: true),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Salvar')),
              ],
            ),
          );
          if (v != null && v.trim().isNotEmpty) onSave(v.trim());
        },
      );
}

class _PlayerEditor extends StatefulWidget {
  final String teamId;
  final Player player;
  const _PlayerEditor({required this.teamId, required this.player});

  @override
  State<_PlayerEditor> createState() => _PlayerEditorState();
}

class _PlayerEditorState extends State<_PlayerEditor> {
  late final TextEditingController name = TextEditingController(text: widget.player.name);
  late int age = widget.player.age;
  late int overall = widget.player.overall;
  late String position = widget.player.position;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kCard,
      title: const Text('Editar jogador', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nome')),
            Row(children: [
              const Expanded(child: Text('Posição', style: TextStyle(color: Colors.white70))),
              DropdownButton<String>(
                value: position,
                dropdownColor: kCard,
                style: const TextStyle(color: Colors.white),
                items: [for (final p in kPositions) DropdownMenuItem(value: p, child: Text(p))],
                onChanged: (v) => setState(() => position = v ?? position),
              ),
            ]),
            Text('Idade: $age', style: const TextStyle(color: Colors.white70)),
            Slider(value: age.toDouble(), min: 15, max: 42, divisions: 27, onChanged: (v) => setState(() => age = v.round())),
            Text('Overall: $overall', style: const TextStyle(color: Colors.white70)),
            Slider(value: overall.toDouble(), min: 40, max: 95, divisions: 55, onChanged: (v) => setState(() => overall = v.round())),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(
          onPressed: () {
            context.read<GameState>().editPlayer(widget.teamId, widget.player.id,
                name: name.text.trim(), age: age, overall: overall, position: position);
            Navigator.pop(context);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
