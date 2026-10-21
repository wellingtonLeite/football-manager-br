import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../game/engine.dart';
import '../game/models.dart';
import '../game/data.dart';
import '../game/economy.dart';
import 'shield.dart';
import 'audio_service.dart';
import 'prematch_screen.dart';
import 'finances_screen.dart';
import 'marketplace_screen.dart';
import 'career_screen.dart';
import 'competitions_screen.dart';
import 'president_screen.dart';
import 'player_screens.dart';
import 'widgets.dart';
import 'help_screen.dart';
import 'club_screen.dart';
import 'extra_screens.dart';
import 'multiplayer_screen.dart';

/// Tela inicial: 3 espaços de save, com backup (exportar/importar).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late Future<List<Map<String, dynamic>?>> _slots = GameState.slotSummaries();

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _slots = GameState.slotSummaries();
    });
  }

  Future<void> _open(int slot, Map<String, dynamic>? meta) async {
    final game = context.read<GameState>();
    context.read<AudioService>().playButton();
    try {
      await game.switchSlot(slot);
    } catch (e) {
      // Nunca falhar em silêncio: mostra o erro para o jogador
      if (mounted) showResult(context, TransferResult(false, 'Não foi possível abrir o espaço $slot: $e'));
      return;
    }
    if (!mounted) return;
    if (meta == null || !game.started) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const ModeSelectScreen()));
      _refresh();
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  Future<void> _export(int slot) async {
    final game = context.read<GameState>();
    await game.switchSlot(slot);
    final bytes = Uint8List.fromList(utf8.encode(game.exportSave()));
    final name = 'carreira_${game.career.name.replaceAll(' ', '_')}_${game.seasonYear}.json';
    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/json', name: name)],
        fileNameOverrides: [name],
        subject: 'Backup Football Manager BR',
      ));
    } catch (e) {
      if (mounted) showResult(context, TransferResult(false, 'Não foi possível exportar: $e'));
    }
  }

  Future<void> _import(int slot) async {
    final game = context.read<GameState>();
    try {
      // Seletor nativo do Android (MainActivity.kt), sem plugin externo
      final raw = await const MethodChannel('fmbr/backup').invokeMethod<String>('pickText');
      if (raw == null) return;
      await game.switchSlot(slot);
      final ok = await game.importSave(raw);
      if (!mounted) return;
      showResult(context, TransferResult(ok, ok ? 'Carreira importada no espaço $slot!' : 'Arquivo de backup inválido.'));
      _refresh();
    } catch (e) {
      if (mounted) showResult(context, TransferResult(false, 'Não foi possível importar: $e'));
    }
  }

  Future<void> _delete(int slot) async {
    final ok = await confirmDialog(context, 'Apagar o espaço $slot?', 'A carreira salva aqui será perdida.');
    if (!ok || !mounted) return;
    final game = context.read<GameState>();
    await game.switchSlot(slot);
    await game.deleteSave();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white70),
            tooltip: 'Como jogar',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          const Icon(Icons.sports_soccer, size: 72, color: Colors.white),
          const SizedBox(height: 12),
          const Text(
            'FOOTBALL MANAGER\nBRASIL 2026',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text('Séries A–D • Copas • Ligas do exterior',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 24),
          FutureBuilder<List<Map<String, dynamic>?>>(
            future: _slots,
            builder: (context, snap) {
              final slots = snap.data ?? List<Map<String, dynamic>?>.filled(GameState.slotCount, null);
              return Column(
                children: [
                  for (int i = 0; i < slots.length; i++) _slotCard(i + 1, slots[i]),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Dica: exporte a carreira (⋮) para guardar um backup no Drive ou no WhatsApp.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _slotCard(int slot, Map<String, dynamic>? meta) {
    final mode = meta == null ? null : GameMode.values.where((m) => m.name == meta['mode']).firstOrNull;
    return Card(
      color: meta == null ? const Color(0xFF1A1A1A) : kCard,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Text(meta == null ? '➕' : (mode?.emoji ?? '⚽'), style: const TextStyle(fontSize: 28)),
        title: Text(
          meta == null ? 'Espaço $slot — vazio' : '${meta['name']} • ${meta['club']}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          meta == null ? 'Toque para começar uma nova carreira' : '${mode?.label ?? ''} • temporada ${meta['season']} • data ${meta['day']}',
          style: const TextStyle(color: Colors.white60),
        ),
        onTap: () => _open(slot, meta),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white70),
          color: kCard,
          onSelected: (v) {
            if (v == 'export') _export(slot);
            if (v == 'import') _import(slot);
            if (v == 'delete') _delete(slot);
          },
          itemBuilder: (_) => [
            if (meta != null) const PopupMenuItem(value: 'export', child: Text('📤 Exportar backup')),
            const PopupMenuItem(value: 'import', child: Text('📥 Importar backup aqui')),
            if (meta != null) const PopupMenuItem(value: 'delete', child: Text('🗑️ Apagar')),
          ],
        ),
      ),
    );
  }
}

/// Escolha do modo de carreira (Técnico, Presidente ou Jogador).
class ModeSelectScreen extends StatelessWidget {
  const ModeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modo de carreira'), backgroundColor: kGreen),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: kCard,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Text('👥', style: TextStyle(fontSize: 36)),
              title: const Text('Multiplayer local', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: const Text('2 a 4 técnicos no mesmo celular, cada um com seu clube.', style: TextStyle(color: Colors.white70)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MultiplayerSetupScreen())),
            ),
          ),
          for (final m in GameMode.values)
            Card(
              color: kCard,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Text(m.emoji, style: const TextStyle(fontSize: 36)),
                title: Text(m.label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                subtitle: Text(m.description, style: const TextStyle(color: Colors.white70)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () {
                  context.read<AudioService>().playButton();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => m == GameMode.jogador ? const PlayerCreateScreen() : TeamSelectScreen(mode: m),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class TeamSelectScreen extends StatefulWidget {
  final GameMode mode;
  const TeamSelectScreen({super.key, this.mode = GameMode.tecnico});

  @override
  State<TeamSelectScreen> createState() => _TeamSelectScreenState();
}

class _TeamSelectScreenState extends State<TeamSelectScreen> {
  final _nameCtrl = TextEditingController();
  int difficulty = 1;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _start(ClubInfo c) {
    context.read<AudioService>().playButton();
    final game = context.read<GameState>();
    final id = c.shortName.toLowerCase();
    if (widget.mode == GameMode.presidente) {
      game.startPresident(id, name: _nameCtrl.text, difficulty: difficulty);
    } else {
      game.startGame(id, coachName: _nameCtrl.text, difficulty: difficulty);
    }
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final lists = [kClubs, kClubsB, kClubsC, kClubsD];
    final president = widget.mode == GameMode.presidente;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(president ? 'Clube que vai presidir' : 'Escolha seu Clube'),
          backgroundColor: kGreen,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.amber,
            tabs: [Tab(text: 'Série A'), Tab(text: 'Série B'), Tab(text: 'Série C'), Tab(text: 'Série D')],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: president ? 'Seu nome (presidente)' : 'Nome do técnico',
                  hintText: 'Ex.: Wellington Leite',
                  prefixIcon: const Icon(Icons.person),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Fácil')),
                  ButtonSegment(value: 1, label: Text('Normal')),
                  ButtonSegment(value: 2, label: Text('Difícil')),
                ],
                selected: {difficulty},
                onSelectionChanged: (v) => setState(() => difficulty = v.first),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final list in lists)
                    ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final c = list[i];
                        return ListTile(
                          leading: ClubShield(shortName: c.shortName, size: 32),
                          title: Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          subtitle: Text('${c.state} • ${c.stadium} • Téc.: ${c.coach}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          trailing: Text(c.stars == 0 ? '—' : '★' * c.stars, style: const TextStyle(color: Colors.amber)),
                          onTap: () => _start(c),
                        );
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

void showSoundSettings(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: kCard,
    builder: (ctx) => Consumer<AudioService>(
      builder: (ctx, audio, _) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Som, vibração e velocidade', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            SwitchListTile(
              value: audio.soundOn,
              onChanged: audio.setSound,
              title: const Text('🔊 Sons (apito, gol, torcida)', style: TextStyle(color: Colors.white)),
            ),
            ListTile(
              leading: const Icon(Icons.volume_up, color: Colors.white70),
              title: const Text('Testar som', style: TextStyle(color: Colors.white)),
              subtitle: audio.lastError == null
                  ? null
                  : Text('Erro: ${audio.lastError}', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              onTap: audio.testSound,
            ),
            SwitchListTile(
              value: audio.vibrationOn,
              onChanged: audio.setVibration,
              title: const Text('📳 Vibração', style: TextStyle(color: Colors.white)),
            ),
            const ListTile(title: Text('⏱️ Velocidade da narração', style: TextStyle(color: Colors.white))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SegmentedButton<int>(
                segments: [
                  for (final e in AudioService.speeds.entries) ButtonSegment(value: e.value, label: Text(e.key)),
                ],
                selected: {audio.matchSpeedMs},
                onSelectionChanged: (v) => audio.setMatchSpeed(v.first),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final audio = context.watch<AudioService>();
    final soundButton = IconButton(
      icon: Icon(audio.soundOn ? Icons.volume_up : Icons.volume_off),
      tooltip: 'Som e vibração',
      onPressed: () => showSoundSettings(context),
    );
    final team = game.userTeam;
    final retired = game.playerCareer?.retired ?? false;
    if (retired) return _retired(context, game);
    if (team == null) return _unemployed(context, game, soundButton);

    final dayButton = _menuButton(
      context,
      game.seasonFinished ? '🏆 Fim de Temporada' : '📅 Data ${game.currentDay} de ${game.totalDays}',
      Colors.green,
      () => _push(context, const DayScreen()),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(game.isMultiplayer ? '${game.career.name} • ${team.name}' : team.name),
        backgroundColor: kGreen,
        actions: [
          if (game.isMultiplayer)
            PopupMenuButton<int>(
              icon: const Icon(Icons.people),
              tooltip: 'Trocar de técnico',
              color: kCard,
              onSelected: game.setActiveHuman,
              itemBuilder: (_) => [
                for (int i = 0; i < game.humans.length; i++)
                  PopupMenuItem(
                    value: i,
                    child: Text('${i == game.activeHuman ? '▶ ' : ''}${game.humans[i].career.name} • '
                        '${game.humans[i].teamId == null ? 'sem clube' : game.teamById(game.humans[i].teamId!).name}'),
                  ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Como jogar',
            onPressed: () => _push(context, const HelpScreen()),
          ),
          soundButton,
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          switch (game.mode) {
            GameMode.tecnico => _coachCard(game, team),
            GameMode.presidente => _presidentCard(game, team),
            GameMode.jogador => _playerCard(game, team),
          },
          if (game.mode == GameMode.presidente && (game.president?.pending.isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Card(
              color: Colors.deepOrange.shade900,
              child: ListTile(
                leading: const Text('🏛️', style: TextStyle(fontSize: 24)),
                title: Text('${game.president!.pending.length} decisão(ões) pendente(s)',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Toque para resolver na Presidência', style: TextStyle(color: Colors.white70)),
                onTap: () => _push(context, const PresidentScreen()),
              ),
            ),
          ],
          const SizedBox(height: 16),
          dayButton,
          const SizedBox(height: 12),
          _menuButton(context, '🏆 Competições', Colors.orange, () => _push(context, const CompetitionsScreen())),
          const SizedBox(height: 12),
          _menuButton(context, game.controlsTeam ? '👥 Elenco e Escalação' : '👥 Elenco', Colors.blue,
              () => _push(context, const SquadScreen())),
          if (game.managesClub) ...[
            const SizedBox(height: 12),
            _menuButton(context, '💰 Finanças', Colors.teal, () => _push(context, const FinancesScreen())),
            const SizedBox(height: 12),
            _menuButton(
              context,
              game.incomingOffers.isEmpty ? '🔄 Mercado' : '🔄 Mercado (${game.incomingOffers.length} proposta${game.incomingOffers.length > 1 ? 's' : ''})',
              Colors.deepPurple,
              () => _push(context, const MarketplaceScreen()),
            ),
          ],
          if (game.managesClub) ...[
            const SizedBox(height: 12),
            _menuButton(context, '🏟️ Clube (treino, base, olheiros, ingressos)', Colors.blueGrey, () => _push(context, const ClubScreen())),
          ],
          if (game.mode == GameMode.presidente) ...[
            const SizedBox(height: 12),
            _menuButton(context, '🏛️ Presidência', Colors.indigo, () => _push(context, const PresidentScreen())),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _menuButton(context, '🏅 Conquistas', Colors.amber.shade800, () => _push(context, const AchievementsScreen()))),
              const SizedBox(width: 12),
              Expanded(child: _menuButton(context, '✏️ Editor', Colors.grey.shade700, () => _push(context, const EditorScreen()))),
            ],
          ),
          const SizedBox(height: 12),
          if (game.mode == GameMode.jogador)
            _menuButton(
              context,
              game.career.offers.isEmpty ? '⚽ Minha Carreira' : '⚽ Minha Carreira (${game.career.offers.length} proposta${game.career.offers.length > 1 ? 's' : ''})',
              Colors.brown,
              () => _push(context, const PlayerCareerScreen()),
            )
          else
            _menuButton(
              context,
              game.career.offers.isEmpty ? '📜 Carreira e Palmarès' : '📜 Carreira (${game.career.offers.length} convite${game.career.offers.length > 1 ? 's' : ''})',
              Colors.brown,
              () => _push(context, const CareerScreen()),
            ),
          const SizedBox(height: 16),
          NewsCard(news: game.news),
        ],
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Widget _header(GameState game, Team team, List<Widget> extra) {
    final next = game.nextUserMatch;
    return Card(
      color: kCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClubShield(shortName: team.shortName, size: 64),
            const SizedBox(height: 6),
            Text(team.stars == 0 ? '' : '★' * team.stars, style: const TextStyle(color: Colors.amber, fontSize: 18)),
            Text(
              game.seasonFinished
                  ? 'Temporada ${game.seasonYear} encerrada!'
                  : '${compName(divisionComp(team.division))} ${game.seasonYear} • ${team.played == 0 ? '—' : '${game.userPosition}º'} • ${team.points} pts',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            Text('${team.played} jogos na liga • ${team.stadium}', style: const TextStyle(color: Colors.white70)),
            ...extra,
            if (next != null && !game.seasonFinished) ...[
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final opp = game.teamById(next.homeId == team.id ? next.awayId : next.homeId);
                final casa = next.homeId == team.id;
                return Text(
                  'Próximo: ${opp.name} (${casa ? 'casa' : 'fora'})\n${matchLabel(next)} • data ${next.day}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _coachCard(GameState game, Team team) => _header(game, team, [
        const SizedBox(height: 4),
        Text('Técnico: ${team.coach}', style: TextStyle(color: Colors.amber.shade300, fontSize: 13)),
        Text('Meta: ${game.career.goal.labelFor(team.division)}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Text('Caixa: ${formatMoney(team.balance)}',
            style: TextStyle(color: team.balance >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _moraleIndicator('👥 Torcida', team.fanMorale),
            _moraleIndicator('📰 Imprensa', team.pressMorale),
            _moraleIndicator('👔 Diretoria', game.career.boardConfidence),
          ],
        ),
      ]);

  Widget _presidentCard(GameState game, Team team) {
    final p = game.president!;
    return _header(game, team, [
      const SizedBox(height: 4),
      Text('Presidente: ${game.career.name} • mandato até ${p.mandateEnd}',
          style: TextStyle(color: Colors.amber.shade300, fontSize: 13)),
      Text('Técnico: ${team.coach} ${'★' * team.coachRating}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
      const SizedBox(height: 4),
      Text('Caixa: ${formatMoney(team.balance)} • Patrimônio: ${formatMoney(game.patrimony(team))}',
          textAlign: TextAlign.center,
          style: TextStyle(color: team.balance >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _moraleIndicator('🗳️ Popularidade', p.popularity),
          _moraleIndicator('👥 Torcida', team.fanMorale),
          _moraleIndicator('📰 Imprensa', team.pressMorale),
        ],
      ),
    ]);
  }

  Widget _playerCard(GameState game, Team team) {
    final p = game.userPlayer;
    final s = game.currentPlayerStats;
    if (p == null) return _header(game, team, const []);
    return Column(
      children: [
        Card(
          color: Colors.indigo.shade900,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                overallAvatar(p, radius: 30),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('${p.position} • ${p.age} anos • ${game.playerCareer!.nationality}',
                          style: const TextStyle(color: Colors.white70)),
                      Text('${formatMoney(p.wage)}/mês • valor ${formatMoney(p.marketValue)}',
                          style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        s == null || s.games == 0
                            ? 'Ainda sem jogos na temporada'
                            : '${s.games} jogos • ${s.goals} gols • ${s.assists} assist. • nota ${s.avgRating.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                      ),
                      if (game.playerCareer!.caps > 0)
                        Text('🇧🇷 ${game.playerCareer!.caps} jogos pela Seleção',
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                      Text(team.startingIds.contains(p.id) ? '✅ Titular' : '🪑 Reserva',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _header(game, team, [
          const SizedBox(height: 4),
          Text('Técnico: ${team.coach}', style: TextStyle(color: Colors.amber.shade300, fontSize: 13)),
        ]),
      ],
    );
  }

  Widget _retired(BuildContext context, GameState game) {
    final pc = game.playerCareer!;
    return Scaffold(
      appBar: AppBar(title: const Text('Carreira encerrada'), backgroundColor: Colors.grey.shade800),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: kCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('👋', style: TextStyle(fontSize: 48)),
                  Text(game.career.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${pc.totalGames} jogos • ${pc.totalGoals} gols • ${pc.totalAssists} assistências',
                      style: const TextStyle(color: Colors.white70)),
                  Text('${pc.caps} jogos pela Seleção • ${game.career.trophies.length} títulos',
                      style: const TextStyle(color: Colors.white70)),
                  Text('Ganhos: ${formatMoney(game.career.earnings)}', style: const TextStyle(color: Colors.greenAccent)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _menuButton(context, '⚽ Ver minha carreira', Colors.brown, () => _push(context, const PlayerCareerScreen())),
          const SizedBox(height: 12),
          _menuButton(context, '🆕 Nova carreira', Colors.green, () async {
            await game.deleteSave();
            if (!context.mounted) return;
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()), (_) => false);
          }),
        ],
      ),
    );
  }

  Widget _unemployed(BuildContext context, GameState game, Widget soundButton) {
    final c = game.career;
    final role = game.mode == GameMode.presidente ? 'presidente' : 'técnico';
    return Scaffold(
      appBar: AppBar(
        title: Text(game.isNationalCoach ? 'Seleção Brasileira' : 'Sem clube'),
        backgroundColor: Colors.grey.shade800,
        actions: [soundButton],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: kCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(game.mode.emoji, style: const TextStyle(fontSize: 48)),
                  Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  if (game.isNationalCoach)
                    const Text('Técnico da Seleção Brasileira 🇧🇷', style: TextStyle(color: Colors.greenAccent)),
                  const SizedBox(height: 4),
                  Text(
                    game.seasonFinished
                        ? 'Temporada ${game.seasonYear} encerrada'
                        : 'Temporada ${game.seasonYear} • data ${game.currentDay}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  meterBar('Reputação', c.reputation),
                  const SizedBox(height: 4),
                  Text(
                    'Aguarde convites para $role enquanto a temporada segue. '
                    'Clubes 5★ exigem reputação 75, 4★ 55, 3★ 30 e 2★ 15.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          if (game.isNationalCoach) ...[
            const SizedBox(height: 8),
            _menuButton(context, '🇧🇷 Seleção Brasileira', Colors.green.shade800, () => _push(context, const NationalTeamScreen())),
          ],
          sectionTitle('CONVITES'),
          const JobOffersList(),
          const SizedBox(height: 16),
          _menuButton(context, game.seasonFinished ? '🏆 Fim de Temporada' : '⏩ Acompanhar data ${game.currentDay}', Colors.green,
              () => _push(context, const DayScreen())),
          const SizedBox(height: 12),
          _menuButton(context, '🏆 Competições', Colors.orange, () => _push(context, const CompetitionsScreen())),
          const SizedBox(height: 12),
          _menuButton(context, '📜 Carreira', Colors.brown, () => _push(context, const CareerScreen())),
          const SizedBox(height: 16),
          NewsCard(news: game.news),
        ],
      ),
    );
  }

  Widget _moraleIndicator(String label, int value) {
    final color = value >= 70 ? Colors.green : (value <= 40 ? Colors.red : Colors.orange);
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: color, width: 1)),
          child: Text('$value%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  static Widget _menuButton(BuildContext context, String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: () {
          context.read<AudioService>().playButton();
          onTap();
        },
        child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class NewsCard extends StatelessWidget {
  final List<NewsItem> news;
  const NewsCard({super.key, required this.news});

  @override
  Widget build(BuildContext context) {
    if (news.isEmpty) return const SizedBox.shrink();
    return Card(
      color: kCard,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🗞️ Últimas notícias', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final n in news.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('D${n.round} • ${n.text}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Jogos da data atual (todas as competições) e avanço do calendário.
class DayScreen extends StatelessWidget {
  const DayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    if (game.seasonFinished) return _seasonEnd(context, game);

    final matches = game.dayMatches;
    final played = game.dayPlayed;
    final userMatch = game.userMatchCurrent;
    final byComp = <String, List<Match>>{};
    for (final m in matches) {
      (byComp[m.comp] ??= []).add(m);
    }
    final userComp = matches.where((m) => game.userTeamId != null && m.involves(game.userTeamId!)).map((m) => m.comp).firstOrNull;
    final comps = byComp.keys.toList()..sort((a, b) => (a == userComp ? 0 : 1).compareTo(b == userComp ? 0 : 1));
    final lastDay = game.currentDay == game.totalDays;
    final audio = context.read<AudioService>();

    return Scaffold(
      appBar: AppBar(title: Text('Data ${game.currentDay} de ${game.totalDays}'), backgroundColor: kGreen),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                for (final c in comps)
                  ExpansionTile(
                    initiallyExpanded: c == userComp || comps.length == 1,
                    iconColor: Colors.white70,
                    collapsedIconColor: Colors.white54,
                    title: Text(_compTitle(game, c, byComp[c]!), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    children: [for (final m in byComp[c]!) MatchTile(match: m)],
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!played && game.isMultiplayer && game.humansWithMatchToday().isNotEmpty) ...[
                    for (final i in game.humansWithMatchToday())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                onPressed: () {
                                  audio.playButton();
                                  game.setActiveHuman(i);
                                  game.simulateOtherMatches();
                                  game.ensureUserLineup();
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PreMatchScreen())).then((_) {
                                    if (context.mounted && game.userMatchCurrent == null && game.started) {
                                      _showPressConference(context, game);
                                    }
                                  });
                                },
                                child: Text('⚽ Vez de ${game.humans[i].career.name}', overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                              onPressed: () {
                                game.setActiveHuman(i);
                                game.simulateOtherMatches();
                                game.simulateUserMatchQuick();
                              },
                              child: const Text('⏩'),
                            ),
                          ],
                        ),
                      ),
                  ] else if (!played && userMatch != null && game.controlsTeam) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: () {
                          audio.playButton();
                          game.simulateOtherMatches();
                          game.ensureUserLineup();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PreMatchScreen())).then((_) {
                            if (context.mounted && game.userMatchCurrent == null && game.started) {
                              _showPressConference(context, game);
                            }
                          });
                        },
                        child: const Text('⚽ Preparar o jogo (tática e titulares)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                        onPressed: () {
                          audio.playButton();
                          game.simulateOtherMatches();
                          game.simulateUserMatchQuick();
                        },
                        child: const Text('⏩ Simular meu jogo sem assistir'),
                      ),
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: played ? Colors.orange : Colors.green, foregroundColor: Colors.white),
                        onPressed: () {
                          audio.playButton();
                          if (played) {
                            game.advanceDay();
                          } else {
                            game.simulateOtherMatches();
                          }
                        },
                        child: Text(
                          played ? (lastDay ? 'Encerrar temporada →' : 'Avançar para a data ${game.currentDay + 1} →') : '⚽ Simular a data ${game.currentDay}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _compTitle(GameState game, String comp, List<Match> list) {
    final m = list.first;
    final label = matchLabel(m);
    return label;
  }

  Widget _seasonEnd(BuildContext context, GameState game) {
    final record = game.history.isEmpty ? null : game.history.last;
    final user = game.userTeam;
    return Scaffold(
      appBar: AppBar(title: Text('Temporada ${game.seasonYear}'), backgroundColor: kGreen),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: Text('🏆', style: TextStyle(fontSize: 56))),
          Center(
            child: Text('Campeões de ${game.seasonYear}',
                style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          if (record != null)
            Card(
              color: kCard,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [for (final e in record.titles.entries) infoRow(e.key, e.value, valueColor: Colors.amber)],
                ),
              ),
            ),
          if (user != null) ...[
            const SizedBox(height: 8),
            Text(
              '${user.name}: ${game.userPosition}º na ${compName(divisionComp(user.division))}'
              '${game.pendingDivisions[user.id] == null ? '' : (game.pendingDivisions[user.id]! < user.division ? ' • ACESSO! 🎉' : ' • rebaixado 💔')}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            if (game.managesClub)
              const Text('Antes de virar a temporada, renove contratos em Mercado › Meu Elenco.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompetitionsScreen())),
              child: const Text('Ver classificações e copas'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () {
                context.read<AudioService>().playButton();
                game.startNewSeason();
              },
              child: Text('🔄 Iniciar Temporada ${game.seasonYear + 1}'),
            ),
          ),
        ],
      ),
    );
  }

  void _showPressConference(BuildContext context, GameState game) {
    final questions = game.generatePressConference();
    if (questions.isEmpty) return;
    showDialog(context: context, builder: (dlg) => PressConferenceDialog(questions: questions, game: game));
  }
}

/// Mantido para compatibilidade: a antiga tela de rodada agora é a tela da data.
class RoundScreen extends DayScreen {
  const RoundScreen({super.key});
}

class MatchTile extends StatelessWidget {
  final Match match;
  const MatchTile({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameState>();
    final m = match;
    final home = game.teamById(m.homeId);
    final away = game.teamById(m.awayId);
    final isUser = game.userTeamId != null && m.involves(game.userTeamId!);
    String score = m.isPlayed ? '${m.homeGoals} x ${m.awayGoals}' : 'vs';
    if (m.homePens != null) score += '\n(${m.homePens}x${m.awayPens} pên.)';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(color: isUser ? kGreen : kCard, borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            ClubShield(shortName: home.shortName, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(home.name, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(6)),
              child: Text(score, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            Expanded(
              child: Text(away.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            const SizedBox(width: 6),
            ClubShield(shortName: away.shortName, size: 18),
          ],
        ),
      ),
    );
  }
}

class PressConferenceDialog extends StatefulWidget {
  final List<PressConference> questions;
  final GameState game;

  const PressConferenceDialog({super.key, required this.questions, required this.game});

  @override
  State<PressConferenceDialog> createState() => _PressConferenceDialogState();
}

class _PressConferenceDialogState extends State<PressConferenceDialog> {
  int currentQ = 0;
  String? feedback;
  bool answered = false;

  @override
  Widget build(BuildContext context) {
    if (currentQ >= widget.questions.length) {
      return AlertDialog(
        backgroundColor: kCard,
        title: const Text('📰 Coletiva Encerrada', style: TextStyle(color: Colors.white)),
        content: const Text('Obrigado pelas respostas!', style: TextStyle(color: Colors.white70)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
      );
    }

    final q = widget.questions[currentQ];
    final positive = feedback != null && feedback!.contains('(+');
    return AlertDialog(
      backgroundColor: kCard,
      title: Row(
        children: [
          const Text('📰', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(child: Text('Coletiva (${currentQ + 1}/${widget.questions.length})', style: const TextStyle(color: Colors.white))),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.question, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            if (!answered)
              ...List.generate(q.answers.length, (idx) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft, side: const BorderSide(color: Colors.white24), foregroundColor: Colors.white),
                    onPressed: () {
                      setState(() {
                        answered = true;
                        feedback = idx == q.correctIndex ? q.correctFeedback : q.wrongFeedback;
                        widget.game.applyPressAnswer(currentQ, idx);
                      });
                    },
                    child: Text(q.answers[idx]),
                  ),
                );
              })
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: positive ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(feedback!,
                    style: TextStyle(color: positive ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
      actions: [
        if (answered)
          TextButton(
            onPressed: () => setState(() {
              currentQ++;
              answered = false;
              feedback = null;
            }),
            child: const Text('Próxima Pergunta'),
          ),
      ],
    );
  }
}

class SquadScreen extends StatelessWidget {
  const SquadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final team = game.userTeam;
    if (team == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Elenco'), backgroundColor: kGreen),
        body: const Center(child: Text('Você está sem clube.', style: TextStyle(color: Colors.white70))),
      );
    }
    final editable = game.controlsTeam;
    const order = ['GOL', 'ZAG', 'LAT', 'VOL', 'MEI', 'ATA'];
    final widgets = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(
          editable
              ? 'Titulares: ${team.startingIds.length}/11 • Toque no jogador para colocar ou tirar do time. '
                  'Com 11 titulares, o reserva entra no lugar do titular mais fraco da posição.'
              : 'Quem escala é o técnico ${team.coach}.',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ),
    ];
    for (final pos in order) {
      final list = team.squad.where((p) => p.position == pos).toList()..sort((a, b) => b.overall.compareTo(a.overall));
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(pos, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 3)),
      ));
      for (final p in list) {
        final tit = team.startingIds.contains(p.id);
        final isMe = p.id == game.playerCareer?.playerId;
        widgets.add(ListTile(
          dense: true,
          tileColor: isMe ? Colors.indigo.withValues(alpha: 0.4) : null,
          onTap: !editable
              ? null
              : () {
                  final err = game.toggleStarter(p.id);
                  if (err != null) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(err)));
                  }
                },
          leading: overallAvatar(p),
          title: Row(
            children: [
              if (tit)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                  child: const Text('TIT', style: TextStyle(fontSize: 9, color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              if (p.injured) const Padding(padding: EdgeInsets.only(right: 6), child: Text('🚑', style: TextStyle(fontSize: 12))),
              if (p.suspended > 0) const Padding(padding: EdgeInsets.only(right: 6), child: Text('🟥', style: TextStyle(fontSize: 12))),
              if (p.onLoan) const Padding(padding: EdgeInsets.only(right: 6), child: Text('🔁', style: TextStyle(fontSize: 12))),
              Expanded(child: Text(isMe ? '${p.name} (VOCÊ)' : p.name, style: const TextStyle(color: Colors.white))),
            ],
          ),
          subtitle: Text(
            '${p.position} • ${p.age} anos • ${formatMoney(p.wage)}/mês • até ${game.seasonYear + p.contractYears - 1}\n'
            '⚡${p.energy} • 😊${p.morale} • ⭐${p.xp}/${Player.xpToNext}'
            '${p.potential > 0 ? ' • pot. ${p.potential}' : ''}${p.nat != 'BRA' ? ' • ${p.nat}' : ''}'
            '${p.yellowCards > 0 ? ' • 🟨${p.yellowCards}' : ''}${p.suspended > 0 ? ' • suspenso' : ''}'
            '${p.injured ? ' • lesionado (${game.roundsOut(p)} jogo(s))' : ''}',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ));
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Elenco - ${team.name}'),
        backgroundColor: kGreen,
        actions: [
          if (editable)
            IconButton(icon: const Icon(Icons.auto_fix_high), tooltip: 'Escalação automática', onPressed: game.resetUserLineup),
        ],
      ),
      body: ListView(children: widgets),
    );
  }
}

/// Mantido para compatibilidade: abre as competições na divisão do usuário.
class TableScreen extends StatelessWidget {
  const TableScreen({super.key});

  @override
  Widget build(BuildContext context) => const CompetitionsScreen();
}
