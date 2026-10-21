import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/engine.dart';
import '../game/models.dart';
import '../game/data.dart';
import 'shield.dart';
import 'widgets.dart';

/// Classificações das Séries A–D, estaduais e chaveamentos das copas.
class CompetitionsScreen extends StatelessWidget {
  const CompetitionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final initial = ((game.userTeam?.division ?? 1) - 1).clamp(0, 3);
    return DefaultTabController(
      length: 11,
      initialIndex: initial,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Competições ${game.seasonYear}'),
          backgroundColor: kGreen,
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.amber,
            tabs: [
              Tab(text: 'Série A'),
              Tab(text: 'Série B'),
              Tab(text: 'Série C'),
              Tab(text: 'Série D'),
              Tab(text: 'Estaduais'),
              Tab(text: 'Copa do Brasil'),
              Tab(text: 'Libertadores'),
              Tab(text: 'Sul-Americana'),
              Tab(text: 'Exterior'),
              Tab(text: 'Outras copas'),
              Tab(text: 'Estatísticas'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            LeagueTable(division: 1),
            LeagueTable(division: 2),
            LeagueTable(division: 3),
            _CupTab(comp: 'D'),
            _RegionalTab(),
            _CupTab(comp: 'CDB'),
            _CupTab(comp: 'LIB'),
            _CupTab(comp: 'SUL'),
            _ForeignTab(),
            _OtherCupsTab(),
            _StatsTab(),
          ],
        ),
      ),
    );
  }
}

class LeagueTable extends StatelessWidget {
  final int division;
  final String? league;
  const LeagueTable({super.key, required this.division, this.league});

  Color? _zoneColor(int idx, int length) {
    if (league != null) {
      if (idx < 4) return Colors.green.withValues(alpha: 0.25);
      if (idx >= length - 3) return Colors.red.withValues(alpha: 0.2);
      return null;
    }
    if (division == 1) {
      if (idx < 6) return Colors.green.withValues(alpha: 0.25);
      if (idx < 13) return Colors.teal.withValues(alpha: 0.18);
    } else if (idx < 4) {
      return Colors.green.withValues(alpha: 0.25);
    }
    if (division < 4 && idx >= length - 4) return Colors.red.withValues(alpha: 0.25);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final table = league != null ? game.standingsOfLeague(league!) : game.standingsOf(division);
    final legend = league != null
        ? ['🟩 Zona de classificação para as copas', '🟥 Zona de rebaixamento']
        : division == 1
        ? ['🟩 1º–6º: Libertadores', '🟦 7º–13º: Sul-Americana', '🟥 17º–20º: Série B']
        : division == 4
            ? ['🟩 1º–4º: acesso à Série C']
            : ['🟩 1º–4º: acesso à Série ${'ABC'[division - 2]}', '🟥 17º–20º: Série ${'BCD'[division - 1]}'];
    return ListView.builder(
      itemCount: table.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text('Clube', style: TextStyle(color: Colors.white54))),
                SizedBox(width: 32, child: Text('P', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))),
                SizedBox(width: 24, child: Text('J', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))),
                SizedBox(width: 32, child: Text('SG', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))),
              ],
            ),
          );
        }
        if (index == table.length + 1) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final l in legend) Text(l, style: const TextStyle(color: Colors.white70))],
            ),
          );
        }
        final i = index - 1;
        final t = table[i];
        final isUser = t.id == game.userTeamId;
        return Container(
          color: _zoneColor(i, table.length),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: isUser ? Colors.amber : Colors.grey.shade800,
              child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            title: Row(
              children: [
                ClubShield(shortName: t.shortName, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isUser ? '${t.name} (VOCÊ)' : t.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontWeight: isUser ? FontWeight.bold : FontWeight.normal),
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 32, child: Text('${t.points}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                SizedBox(width: 24, child: Text('${t.played}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
                SizedBox(width: 32, child: Text('${t.goalDifference > 0 ? '+' : ''}${t.goalDifference}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Tabela compacta de grupo (estaduais e fase de grupos das copas).
class GroupTableView extends StatelessWidget {
  final String title;
  final List<StandingRow> rows;
  final int qualify;
  const GroupTableView({super.key, required this.title, required this.rows, this.qualify = 2});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<GameState>().userTeamId;
    return Card(
      color: kCard,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            for (int i = 0; i < rows.length; i++)
              Container(
                color: i < qualify ? Colors.green.withValues(alpha: 0.18) : null,
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(width: 18, child: Text('${i + 1}', style: const TextStyle(color: Colors.white54, fontSize: 12))),
                    ClubShield(shortName: rows[i].team.shortName, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(rows[i].team.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: rows[i].team.id == userId ? FontWeight.bold : FontWeight.normal)),
                    ),
                    SizedBox(width: 26, child: Text('${rows[i].points}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    SizedBox(width: 22, child: Text('${rows[i].played}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 12))),
                    SizedBox(width: 30, child: Text('${rows[i].goalDifference > 0 ? '+' : ''}${rows[i].goalDifference}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 12))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RegionalTab extends StatefulWidget {
  const _RegionalTab();

  @override
  State<_RegionalTab> createState() => _RegionalTabState();
}

class _RegionalTabState extends State<_RegionalTab> {
  String? selected;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final keys = game.regionalGroups.keys.toList()
      ..sort((a, b) => (kRegionalNames[a] ?? a).compareTo(kRegionalNames[b] ?? b));
    if (keys.isEmpty) {
      return const Center(child: Text('Sem estaduais nesta temporada.', style: TextStyle(color: Colors.white54)));
    }
    final userState = game.regionalGroups.entries
        .where((e) => game.userTeamId != null && e.value.contains(game.userTeamId))
        .map((e) => e.key)
        .firstOrNull;
    final key = selected ?? userState ?? keys.first;
    final comp = 'EST:$key';
    final finalMatch = game.stageMatches(comp, 'F').firstOrNull;
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: DropdownButton<String>(
            value: key,
            isExpanded: true,
            dropdownColor: kCard,
            style: const TextStyle(color: Colors.white),
            items: [for (final k in keys) DropdownMenuItem(value: k, child: Text(kRegionalNames[k] ?? k))],
            onChanged: (v) => setState(() => selected = v),
          ),
        ),
        GroupTableView(title: '${compName(comp)} — 1ª fase (2 primeiros vão à final)', rows: game.groupTable(comp, '')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: sectionTitle('FINAL (data 8)'),
        ),
        if (finalMatch == null)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('A final é definida ao fim da 1ª fase.', style: TextStyle(color: Colors.white54)),
          )
        else
          _TieView(comp: comp, stage: 'F', slot: 0),
      ],
    );
  }
}

class _CupTab extends StatelessWidget {
  final String comp;
  const _CupTab({super.key, required this.comp});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final stages = switch (comp) {
      'CDB' => ['R32', 'R16', 'QF', 'SF', 'F'],
      'D' => ['QF', 'SF', 'F'],
      'MUN' => ['SF', 'F'],
      'SUP' || 'REC' => ['F'],
      _ => ['R16', 'QF', 'SF', 'F'],
    };
    final groups = game.groupsOf(comp);
    final champion = game.tieWinner(comp, 'F', 0);
    final children = <Widget>[];
    if (champion != null) {
      children.add(Card(
        color: Colors.amber.shade900,
        margin: const EdgeInsets.all(12),
        child: ListTile(
          leading: const Text('🏆', style: TextStyle(fontSize: 28)),
          title: Text(game.teamById(champion).name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text('Campeão da ${compName(comp)} ${game.seasonYear}', style: const TextStyle(color: Colors.white70)),
        ),
      ));
    }
    for (final stage in stages.reversed) {
      final ms = game.stageMatches(comp, stage);
      if (ms.isEmpty) continue;
      final slots = ms.map((m) => m.round).toSet().toList()..sort();
      children.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: sectionTitle(stageName(stage).toUpperCase()),
      ));
      for (final s in slots) {
        children.add(_TieView(comp: comp, stage: stage, slot: s));
      }
    }
    if (groups.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: sectionTitle(comp == 'D'
            ? 'GRUPOS REGIONAIS (2 primeiros vão às quartas; semifinalistas sobem)'
            : 'FASE DE GRUPOS (2 primeiros avançam)'),
      ));
      for (final g in groups) {
        children.add(GroupTableView(title: 'Grupo $g', rows: game.groupTable(comp, g)));
      }
    }
    if (children.isEmpty) {
      final day = game.stageDays['$comp:R32'] ?? game.stageDays['$comp:G:1'] ?? game.stageDays['$comp:R16:1'] ??
          game.stageDays['$comp:SF'] ?? game.stageDays['$comp:F'] ?? game.stageDays['$comp:F:1'];
      children.add(Padding(
        padding: const EdgeInsets.all(24),
        child: Text('A ${compName(comp)} começa na data ${day ?? '-'}.',
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
      ));
    }
    return ListView(children: children);
  }
}

/// Confronto de mata-mata (um ou dois jogos) com o classificado em destaque.
class _TieView extends StatelessWidget {
  final String comp;
  final String stage;
  final int slot;
  const _TieView({required this.comp, required this.stage, required this.slot});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final legs = game.stageMatches(comp, stage).where((m) => m.round == slot).toList();
    if (legs.isEmpty) return const SizedBox.shrink();
    final winner = game.tieWinner(comp, stage, slot);
    final a = game.teamById(legs.first.leg == 1 ? legs.first.awayId : legs.first.homeId);
    final b = game.teamById(legs.first.leg == 1 ? legs.first.homeId : legs.first.awayId);
    String legText(Match m) {
      if (!m.isPlayed) return 'data ${m.day}';
      final pens = m.homePens == null ? '' : ' (${m.homePens}x${m.awayPens} pên.)';
      return '${game.teamById(m.homeId).shortName} ${m.homeGoals}x${m.awayGoals} ${game.teamById(m.awayId).shortName}$pens';
    }

    Widget name(Team t) => Expanded(
          child: Row(
            children: [
              ClubShield(shortName: t.shortName, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(t.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: winner == null || winner == t.id ? Colors.white : Colors.white38,
                      fontWeight: winner == t.id || t.id == game.userTeamId ? FontWeight.bold : FontWeight.normal,
                    )),
              ),
            ],
          ),
        );

    return Card(
      color: kCard,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [name(a), const Text('x', style: TextStyle(color: Colors.white54)), const SizedBox(width: 8), name(b)]),
            const SizedBox(height: 4),
            Text(legs.map(legText).join('  •  '), style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}


/// Ligas estrangeiras: Inglaterra, Espanha, Itália, Alemanha, França, Portugal, Arábia e Argentina.
class _ForeignTab extends StatefulWidget {
  const _ForeignTab();

  @override
  State<_ForeignTab> createState() => _ForeignTabState();
}

class _ForeignTabState extends State<_ForeignTab> {
  String league = 'ENG';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<String>(
            value: league,
            isExpanded: true,
            dropdownColor: kCard,
            style: const TextStyle(color: Colors.white),
            items: [
              for (final e in kLeagueNames.entries)
                DropdownMenuItem(value: e.key, child: Text('${e.value} (${kLeagueCountry[e.key]})')),
            ],
            onChanged: (v) => setState(() => league = v ?? league),
          ),
        ),
        Expanded(child: LeagueTable(division: 0, league: league)),
      ],
    );
  }
}

/// Supercopa, Recopa, Liga dos Campeões e Copa Intercontinental.
class _OtherCupsTab extends StatefulWidget {
  const _OtherCupsTab();

  @override
  State<_OtherCupsTab> createState() => _OtherCupsTabState();
}

class _OtherCupsTabState extends State<_OtherCupsTab> {
  String comp = 'SUP';

  @override
  Widget build(BuildContext context) {
    const comps = ['SUP', 'REC', 'UCL', 'MUN'];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<String>(
            value: comp,
            isExpanded: true,
            dropdownColor: kCard,
            style: const TextStyle(color: Colors.white),
            items: [for (final c in comps) DropdownMenuItem(value: c, child: Text(compName(c)))],
            onChanged: (v) => setState(() => comp = v ?? comp),
          ),
        ),
        Expanded(child: _CupTab(key: ValueKey(comp), comp: comp)),
      ],
    );
  }
}

/// Artilharia, assistências e seleção da rodada.
class _StatsTab extends StatefulWidget {
  const _StatsTab();

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  String comp = 'A';

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final comps = ['A', 'B', 'C', 'D', 'CDB', 'LIB', 'SUL', 'UCL', ...kLeagueNames.keys];
    final scorers = game.topScorers(comp);
    final assists = game.topAssists();
    String club(String id) => game.allTeams.where((t) => t.id == id).firstOrNull?.shortName ?? '';
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            const Expanded(child: Text('Artilharia', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
            DropdownButton<String>(
              value: comp,
              dropdownColor: kCard,
              style: const TextStyle(color: Colors.white),
              items: [for (final c in comps) DropdownMenuItem(value: c, child: Text(compName(c)))],
              onChanged: (v) => setState(() => comp = v ?? comp),
            ),
          ],
        ),
        if (scorers.isEmpty) const Text('Ainda sem gols.', style: TextStyle(color: Colors.white54)),
        for (int i = 0; i < scorers.length; i++)
          ListTile(
            dense: true,
            leading: Text('${i + 1}º', style: const TextStyle(color: Colors.white70)),
            title: Text(scorers[i].name, style: const TextStyle(color: Colors.white)),
            subtitle: Text('${club(scorers[i].teamId)} • ${scorers[i].position}', style: const TextStyle(color: Colors.white54)),
            trailing: Text('${scorers[i].goalsByComp[comp]} ⚽', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        sectionTitle('ASSISTÊNCIAS (CLUBES BRASILEIROS)'),
        for (final a in assists)
          ListTile(
            dense: true,
            title: Text(a.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text(club(a.teamId), style: const TextStyle(color: Colors.white54)),
            trailing: Text('${a.assists} 🅰️', style: const TextStyle(color: Colors.lightBlueAccent)),
          ),
        if (game.bestOfRound.isNotEmpty) ...[
          sectionTitle('SELEÇÃO DA RODADA'),
          for (final l in game.bestOfRound)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(l, style: const TextStyle(color: Colors.white70)),
            ),
        ],
      ],
    );
  }
}
