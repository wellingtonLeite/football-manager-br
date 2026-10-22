import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/engine.dart';
import '../game/models.dart';
import '../game/economy.dart';
import 'widgets.dart';

/// Fase 10B — mandato, popularidade, crises, técnico e patrimônio.
class PresidentScreen extends StatelessWidget {
  const PresidentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final p = game.president;
    final t = game.userTeam;
    if (p == null || t == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Presidência'), backgroundColor: kGreen),
        body: const Center(child: Text('Você não está presidindo um clube.', style: TextStyle(color: Colors.white70))),
      );
    }
    final value = game.patrimony(t);
    final first = p.patrimonyHistory.isEmpty ? value : p.patrimonyHistory.first;
    return Scaffold(
      appBar: AppBar(title: Text('Presidência - ${t.name}'), backgroundColor: kGreen),
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
                  Text('🏛️ ${game.career.name}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Mandato: ${p.mandateStart} a ${p.mandateEnd} • eleições disputadas: ${p.elections}',
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  meterBar('Popularidade (chance de reeleição)', p.popularity),
                  const SizedBox(height: 4),
                  Text(
                    game.seasonYear >= p.mandateEnd
                        ? '🗳️ Eleição no fim desta temporada!'
                        : 'Próxima eleição: fim de ${p.mandateEnd}.',
                    style: TextStyle(color: game.seasonYear >= p.mandateEnd ? Colors.orangeAccent : Colors.white54),
                  ),
                ],
              ),
            ),
          ),
          sectionTitle('DECISÕES PENDENTES'),
          if (p.pending.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Nenhuma crise no momento.', style: TextStyle(color: Colors.white54)),
            ),
          for (final e in List<CrisisEvent>.from(p.pending))
            Card(
              color: Colors.deepOrange.shade900,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(e.text, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    for (int i = 0; i < e.options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
                            onPressed: () => showResult(context, game.resolveCrisis(e, i)),
                            child: Text(e.options[i]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          sectionTitle('TÉCNICO'),
          Card(
            color: game.coachIsInterim(t) ? Colors.orange.shade900 : kCard,
            child: Column(
              children: [
                ListTile(
                  leading: const Text('👔', style: TextStyle(fontSize: 28)),
                  title: Text('${t.coach} ${'★' * t.coachRating}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    game.coachIsInterim(t)
                        ? 'O auxiliar comanda o time. Escolha o novo técnico!'
                        : 'Salário ${formatMoney(t.coachWage)}/mês • multa para demitir ${formatMoney(game.coachFireCost(t))}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!game.coachIsInterim(t))
                      TextButton(
                        onPressed: () async {
                          final ok = await confirmDialog(context, 'Demitir ${t.coach}?',
                              'O clube paga ${formatMoney(game.coachFireCost(t))} de multa e o auxiliar assume até você escolher o substituto.');
                          if (!ok || !context.mounted) return;
                          showResult(context, game.fireCoach());
                        },
                        child: const Text('Demitir', style: TextStyle(color: Colors.redAccent)),
                      ),
                    TextButton(
                      onPressed: () => _chooseCoach(context, game),
                      child: Text(game.coachIsInterim(t) ? 'Escolher novo técnico' : 'Trocar por outro'),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
          sectionTitle('PATRIMÔNIO DO CLUBE'),
          Card(
            color: kCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  infoRow('Valor atual (elenco + caixa + estrutura)', formatMoney(value),
                      valueColor: value >= first ? Colors.greenAccent : Colors.redAccent),
                  infoRow('Valor ao assumir', formatMoney(first)),
                  infoRow('Variação', '${value >= first ? '+' : ''}${formatMoney(value - first)}',
                      valueColor: value >= first ? Colors.greenAccent : Colors.redAccent),
                  if (p.debt > 0) infoRow('Empréstimo a pagar no fim da temporada', formatMoney(p.debt), valueColor: Colors.redAccent),
                  const Divider(color: Colors.white24),
                  for (int i = 0; i < p.patrimonyHistory.length; i++)
                    infoRow(i == 0 ? 'Na posse' : 'Fim da $iª temporada', formatMoney(p.patrimonyHistory[i])),
                  const SizedBox(height: 6),
                  const Text(
                    'Popularidade sobe com vitórias, títulos, acesso, boas contratações e estrutura. '
                    'Cai com derrotas, caixa negativo, vendas de ídolos e promessas não cumpridas.',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _chooseCoach(BuildContext context, GameState game) {
    final options = game.availableCoaches();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCard,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Técnicos disponíveis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final c in options)
                    ListTile(
                      title: Text('${c.name} ${'★' * c.rating}', style: const TextStyle(color: Colors.white)),
                      subtitle: Text('Pede ${formatMoney(c.wage)}/mês', style: const TextStyle(color: Colors.white60)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final t = game.userTeam!;
                        final ok = await confirmDialog(
                          context,
                          'Contratar ${c.name}?',
                          game.coachIsInterim(t)
                              ? 'Salário de ${formatMoney(c.wage)}/mês.'
                              : 'O técnico atual sai e o clube paga ${formatMoney(game.coachFireCost(t))} de multa. Salário de ${formatMoney(c.wage)}/mês.',
                        );
                        if (!ok || !context.mounted) return;
                        showResult(context, game.hireCoach(c));
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
