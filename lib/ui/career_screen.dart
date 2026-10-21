import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/engine.dart';
import '../game/models.dart';
import '../game/economy.dart';
import 'shield.dart';
import 'widgets.dart';
import 'extra_screens.dart';

/// Fase 10A — reputação, metas da diretoria, convites e histórico.
class CareerScreen extends StatelessWidget {
  const CareerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final c = game.career;
    final t = game.userTeam;
    return Scaffold(
      appBar: AppBar(title: const Text('Carreira do Técnico'), backgroundColor: kGreen),
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
                  Row(
                    children: [
                      const Text('👔', style: TextStyle(fontSize: 36)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(
                              t == null ? 'Sem clube' : 'Técnico do ${t.name}',
                              style: TextStyle(color: t == null ? Colors.orangeAccent : Colors.greenAccent),
                            ),
                          ],
                        ),
                      ),
                      if (t != null) ClubShield(shortName: t.shortName, size: 36),
                    ],
                  ),
                  const SizedBox(height: 12),
                  meterBar('Reputação', c.reputation),
                  infoRow('Títulos (todas as competições)', '${c.trophies.length} 🏆'),
                  infoRow('Salário', c.employed ? '${formatMoney(c.salary)}/mês' : '—'),
                  infoRow('Ganhos na carreira', formatMoney(c.earnings)),
                  const SizedBox(height: 6),
                  const Text(
                    'Clubes 5★ só contratam técnicos com reputação 75+, clubes 4★ pedem 55+.',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          if (t != null && game.mode == GameMode.tecnico) ...[
            sectionTitle('META DA DIRETORIA'),
            _goalCard(context, game, t),
          ],
          if (game.nationalOffer)
            Card(
              color: Colors.green.shade900,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🇧🇷 Convite da CBF', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text('Assumir a Seleção Brasileira? Você deixa o clube atual.',
                        style: TextStyle(color: Colors.white70)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: game.declineNationalTeam, child: const Text('Recusar')),
                        ElevatedButton(onPressed: game.acceptNationalTeam, child: const Text('Aceitar')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (game.isNationalCoach)
            Card(
              color: Colors.green.shade800,
              child: ListTile(
                leading: const Text('🇧🇷', style: TextStyle(fontSize: 28)),
                title: const Text('Seleção Brasileira', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('${game.national!.wins}V ${game.national!.draws}E ${game.national!.losses}D',
                    style: const TextStyle(color: Colors.white70)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NationalTeamScreen())),
              ),
            ),
          if (t != null && game.clubRecords[t.id] != null) ...[
            sectionTitle('RECORDES NO ${t.name.toUpperCase()}'),
            Builder(builder: (context) {
              final r = game.clubRecords[t.id]!;
              final scorers = r.scorers.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final apps = r.apps.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              return Card(
                color: kCard,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      if (r.biggestWin.isNotEmpty) infoRow('Maior vitória', r.biggestWin),
                      if (r.bestCrowd > 0) infoRow('Maior público', '${r.bestCrowd}'),
                      if (scorers.isNotEmpty) infoRow('Artilheiro', '${scorers.first.key} (${scorers.first.value})'),
                      if (apps.isNotEmpty) infoRow('Mais jogos', '${apps.first.key} (${apps.first.value})'),
                    ],
                  ),
                ),
              );
            }),
          ],
          sectionTitle('CONVITES DE CLUBES'),
          const JobOffersList(),
          if (c.trophies.isNotEmpty) ...[
            sectionTitle('TÍTULOS CONQUISTADOS'),
            for (final tr in c.trophies.reversed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text('🏆 $tr', style: const TextStyle(color: Colors.amber)),
              ),
          ],
          if (game.history.isNotEmpty) ...[
            sectionTitle('PALMARÈS — TEMPORADAS ANTERIORES'),
            for (final h in game.history.reversed) _seasonCard(h),
          ],
          sectionTitle('HISTÓRICO DA CARREIRA'),
          if (c.log.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Sem registros.', style: TextStyle(color: Colors.white54)),
            ),
          for (final line in c.log.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text('• $line', style: const TextStyle(color: Colors.white70)),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _goalCard(BuildContext context, GameState game, Team t) {
    final c = game.career;
    final ppg = t.played == 0 ? 0.0 : t.points / t.played;
    final pos = game.userPosition;
    final onTrack = pos <= c.goal.maxPosition;
    return Card(
      color: kCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.goal.labelFor(t.division), style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            infoRow('Posição atual', '$posº', valueColor: onTrack ? Colors.greenAccent : Colors.redAccent),
            infoRow('Pontos por jogo', '${ppg.toStringAsFixed(2)} (esperado ${c.goal.expectedPpg.toStringAsFixed(2)})',
                valueColor: ppg >= c.goal.expectedPpg ? Colors.greenAccent : Colors.orangeAccent),
            meterBar('Confiança da diretoria', c.boardConfidence),
            const Text(
              'Cumprir a meta rende bônus de 3 salários e renovação automática. '
              'Confiança abaixo de 15% (a partir da 6ª rodada) significa demissão.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    'Pedir demissão?',
                    'Você deixa o ${t.name} agora e perde um pouco de reputação.',
                  );
                  if (ok) game.resign();
                },
                icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                label: const Text('Pedir demissão', style: TextStyle(color: Colors.redAccent)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seasonCard(SeasonRecord h) {
    return Card(
      color: kCard,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${h.season} — 🏆 ${h.champion}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Vice: ${h.runnerUp}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text('Z4: ${h.relegated.join(', ')}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            for (final e in h.titles.entries.where((e) => e.key != 'Série A'))
              Text('${e.key}: ${e.value}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
            if (h.userTeam != null)
              Text(
                'Você: ${h.userTeam} • ${h.userPosition}º • ${h.userPoints} pts • meta ${h.goalMet == true ? '✅' : '❌'} (${h.goal})',
                style: TextStyle(color: h.goalMet == true ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lista de convites com aceitar/recusar (usada na Home sem clube e na Carreira).
class JobOffersList extends StatelessWidget {
  const JobOffersList({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final offers = game.career.offers;
    if (offers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'Nenhum convite no momento. Bons resultados aumentam sua reputação.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return Column(
      children: [
        for (final o in List<JobOffer>.from(offers))
          Builder(builder: (context) {
            final team = game.teamOrNull(o.teamId);
            if (team == null) return const SizedBox.shrink();
            final pos = game.positionOf(team.id);
            return Card(
              color: kCard,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClubShield(shortName: team.shortName, size: 32),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${team.name} ${'★' * team.stars}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text(
                                '${team.played > 0 ? '$posº lugar • ' : ''}Caixa ${formatMoney(team.balance)}',
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (game.mode == GameMode.tecnico) Text('Meta: ${o.goal.labelFor(team.division)}', style: const TextStyle(color: Colors.amber)),
                    Text(compName(divisionComp(team.division)), style: const TextStyle(color: Colors.white60)),
                    if (game.mode == GameMode.tecnico) Text('Salário: ${formatMoney(o.salary)}/mês', style: const TextStyle(color: Colors.white70)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => game.rejectJobOffer(o),
                          child: const Text('Recusar', style: TextStyle(color: Colors.redAccent)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          onPressed: () async {
                            final ok = await confirmDialog(
                              context,
                              'Assumir o ${team.name}?',
                              game.userTeam == null
                                  ? 'Meta: ${o.goal.labelFor(team.division)}.'
                                  : 'Você deixará o ${game.userTeam!.name}. Meta: ${o.goal.labelFor(team.division)}.',
                            );
                            if (ok) game.acceptJobOffer(o);
                          },
                          child: const Text('Aceitar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
