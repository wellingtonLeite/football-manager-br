import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/engine.dart';
import '../game/data.dart';
import 'audio_service.dart';
import 'screens.dart';
import 'shield.dart';
import 'widgets.dart';

/// Multiplayer local: 2 a 4 técnicos, cada um com seu clube, revezando o celular.
class MultiplayerSetupScreen extends StatefulWidget {
  const MultiplayerSetupScreen({super.key});

  @override
  State<MultiplayerSetupScreen> createState() => _MultiplayerSetupScreenState();
}

class _MultiplayerSetupScreenState extends State<MultiplayerSetupScreen> {
  final List<TextEditingController> names = [TextEditingController(), TextEditingController()];
  final List<ClubInfo?> clubs = [null, null];
  int difficulty = 1;

  @override
  void dispose() {
    for (final c in names) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickClub(int i) async {
    final taken = {for (int j = 0; j < clubs.length; j++) if (j != i && clubs[j] != null) clubs[j]!.shortName};
    final chosen = await showModalBottomSheet<ClubInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCard,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.8,
        child: DefaultTabController(
          length: 4,
          child: Column(
            children: [
              const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: [Tab(text: 'A'), Tab(text: 'B'), Tab(text: 'C'), Tab(text: 'D')],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final list in [kClubs, kClubsB, kClubsC, kClubsD])
                      ListView(
                        children: [
                          for (final c in list)
                            ListTile(
                              enabled: !taken.contains(c.shortName),
                              leading: ClubShield(shortName: c.shortName, size: 26),
                              title: Text(c.name, style: TextStyle(color: taken.contains(c.shortName) ? Colors.white30 : Colors.white)),
                              trailing: Text(c.stars == 0 ? '—' : '★' * c.stars, style: const TextStyle(color: Colors.amber)),
                              onTap: () => Navigator.pop(ctx, c),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) setState(() => clubs[i] = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final ready = clubs.every((c) => c != null);
    return Scaffold(
      appBar: AppBar(title: const Text('Multiplayer local'), backgroundColor: kGreen),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Cada técnico escolhe um clube. Na tela da data, cada um joga a sua partida na sua vez.',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          for (int i = 0; i < names.length; i++)
            Card(
              color: kCard,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: names[i],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(labelText: 'Técnico ${i + 1}', prefixIcon: const Icon(Icons.person)),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: clubs[i] == null ? const Icon(Icons.shield, color: Colors.white38) : ClubShield(shortName: clubs[i]!.shortName, size: 28),
                      title: Text(clubs[i]?.name ?? 'Escolher clube', style: const TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                      onTap: () => _pickClub(i),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              if (names.length < 4)
                TextButton.icon(
                  onPressed: () => setState(() {
                    names.add(TextEditingController());
                    clubs.add(null);
                  }),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Adicionar técnico'),
                ),
              const Spacer(),
              if (names.length > 2)
                TextButton.icon(
                  onPressed: () => setState(() {
                    names.removeLast().dispose();
                    clubs.removeLast();
                  }),
                  icon: const Icon(Icons.person_remove),
                  label: const Text('Remover'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Fácil')),
              ButtonSegment(value: 1, label: Text('Normal')),
              ButtonSegment(value: 2, label: Text('Difícil')),
            ],
            selected: {difficulty},
            onSelectionChanged: (v) => setState(() => difficulty = v.first),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: !ready
                  ? null
                  : () {
                      context.read<AudioService>().playButton();
                      context.read<GameState>().startMultiplayer([
                        for (int i = 0; i < names.length; i++) (names[i].text, clubs[i]!.shortName.toLowerCase()),
                      ], difficulty: difficulty);
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
                    },
              child: Text(ready ? '▶️ Começar' : 'Escolha o clube de todos'),
            ),
          ),
        ],
      ),
    );
  }
}
