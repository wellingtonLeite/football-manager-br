import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/engine.dart';
import '../game/models.dart';
import '../game/economy.dart';
import 'widgets.dart';

/// Fase 8 — caixa, folha, receitas x despesas, investimentos e extrato.
class FinancesScreen extends StatelessWidget {
  const FinancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final t = game.userTeam;
    if (t == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Finanças'), backgroundColor: kGreen),
        body: const Center(child: Text('Você está sem clube.', style: TextStyle(color: Colors.white70))),
      );
    }

    final season = game.ledger.where((e) => e.season == game.seasonYear).toList();
    final income = season.where((e) => e.amount > 0).fold<int>(0, (s, e) => s + e.amount);
    final expense = season.where((e) => e.amount < 0).fold<int>(0, (s, e) => s - e.amount);
    final byCategory = <String, int>{};
    for (final e in season) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    final categories = byCategory.entries.toList()..sort((a, b) => a.value.compareTo(b.value));

    const months = 10;
    final monthIn = List<int>.filled(months, 0);
    final monthOut = List<int>.filled(months, 0);
    for (final e in season) {
      final m = min(months - 1, (e.round - 1) ~/ 4);
      if (e.amount > 0) {
        monthIn[m] += e.amount;
      } else {
        monthOut[m] -= e.amount;
      }
    }

    final pos = game.userPosition;
    final crowd = attendance(t, pos);
    final sponsorDone = t.sponsorRenegotiatedSeason == game.seasonYear;

    return Scaffold(
      appBar: AppBar(title: Text('Finanças - ${t.name}'), backgroundColor: kGreen),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: kCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('💰 Caixa do clube', style: TextStyle(color: Colors.white70)),
                  Text(
                    formatMoney(t.balance),
                    style: TextStyle(
                      color: t.balance >= 0 ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (t.balance < 0)
                    const Text(
                      'Caixa negativo: juros de 2% ao mês e queda na moral do elenco!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  const Divider(color: Colors.white24),
                  infoRow('Folha salarial (mês)', formatMoney(t.payroll), valueColor: Colors.redAccent),
                  infoRow('Salário do técnico (mês)', formatMoney(game.career.salary), valueColor: Colors.redAccent),
                  infoRow('Manutenção da estrutura (mês)', formatMoney(monthlyMaintenance(t)), valueColor: Colors.redAccent),
                  infoRow('Patrocínio master (mês)', formatMoney(t.sponsorMonthly), valueColor: Colors.greenAccent),
                  infoRow('Cotas de TV (mês)', formatMoney(tvRights(t.stars)), valueColor: Colors.greenAccent),
                  const SizedBox(height: 4),
                  const Text(
                    'Salários, patrocínio e TV são lançados a cada 4 rodadas (1 mês).',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          sectionTitle('TEMPORADA ${game.seasonYear}'),
          Card(
            color: kCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  infoRow('Receitas', formatMoney(income), valueColor: Colors.greenAccent),
                  infoRow('Despesas', formatMoney(-expense), valueColor: Colors.redAccent),
                  infoRow('Resultado', formatMoney(income - expense),
                      valueColor: income - expense >= 0 ? Colors.greenAccent : Colors.redAccent),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: CustomPaint(painter: _CashflowPainter(monthIn, monthOut)),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Legend(color: Colors.greenAccent, label: 'Entradas'),
                      SizedBox(width: 12),
                      _Legend(color: Colors.redAccent, label: 'Saídas'),
                      SizedBox(width: 12),
                      _Legend(color: Colors.amber, label: 'Acumulado'),
                    ],
                  ),
                  if (categories.isNotEmpty) const Divider(color: Colors.white24),
                  for (final c in categories)
                    infoRow(c.key, formatMoney(c.value),
                        valueColor: c.value >= 0 ? Colors.greenAccent : Colors.redAccent),
                ],
              ),
            ),
          ),
          sectionTitle('BILHETERIA E PATROCÍNIO'),
          Card(
            color: kCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  infoRow('Estádio', t.stadium),
                  infoRow('Capacidade', '${t.effectiveCapacity} lugares'),
                  infoRow('Público estimado', '$crowd pagantes'),
                  infoRow('Ingresso médio', formatMoney(ticketPrice(t))),
                  infoRow('Renda estimada por jogo', formatMoney(crowd * ticketPrice(t))),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      onPressed: sponsorDone
                          ? null
                          : () async {
                              final ok = await confirmDialog(
                                context,
                                'Renegociar patrocínio?',
                                'Uma tentativa por temporada. A chance de aumento depende da torcida e da campanha.',
                              );
                              if (!ok || !context.mounted) return;
                              showResult(context, game.renegotiateSponsor());
                            },
                      icon: const Icon(Icons.handshake),
                      label: Text(sponsorDone ? 'Patrocínio já renegociado' : 'Renegociar patrocínio'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          sectionTitle('INVESTIMENTOS'),
          for (final f in Facility.values) _facilityCard(context, game, t, f),
          sectionTitle('EXTRATO'),
          if (game.ledger.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Nenhum lançamento ainda. Jogue uma rodada!', style: TextStyle(color: Colors.white54)),
            ),
          for (final e in game.ledger.reversed.take(60)) _entryTile(e),
        ],
      ),
    );
  }

  Widget _facilityCard(BuildContext context, GameState game, Team t, Facility f) {
    final level = f.levelOf(t);
    final maxed = level >= kMaxFacilityLevel;
    final cost = maxed ? 0 : facilityCost(level + 1);
    return Card(
      color: kCard,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(f.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(f.effect, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      for (int i = 1; i <= kMaxFacilityLevel; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            i <= level ? Icons.star : Icons.star_border,
                            size: 16,
                            color: Colors.amber,
                          ),
                        ),
                      Text('Nível $level', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: maxed
                  ? null
                  : () async {
                      final ok = await confirmDialog(
                        context,
                        '${f.label}: nível ${level + 1}',
                        'Investir ${formatMoney(cost)}? Caixa atual: ${formatMoney(t.balance)}.',
                      );
                      if (!ok || !context.mounted) return;
                      showResult(context, game.upgradeFacility(f));
                    },
              child: Text(maxed ? 'Máximo' : formatMoney(cost)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryTile(FinanceEntry e) {
    final positive = e.amount >= 0;
    return ListTile(
      dense: true,
      leading: Icon(
        positive ? Icons.arrow_downward : Icons.arrow_upward,
        color: positive ? Colors.greenAccent : Colors.redAccent,
      ),
      title: Text(e.description, style: const TextStyle(color: Colors.white)),
      subtitle: Text('${e.season} • R${e.round} • ${e.category}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
      trailing: Text(
        formatMoney(e.amount),
        style: TextStyle(color: positive ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

/// Barras mensais de entrada/saída e linha do saldo acumulado da temporada.
class _CashflowPainter extends CustomPainter {
  final List<int> incomes;
  final List<int> expenses;

  _CashflowPainter(this.incomes, this.expenses);

  @override
  void paint(Canvas canvas, Size size) {
    final n = incomes.length;
    final cumulative = <int>[];
    int acc = 0;
    for (int i = 0; i < n; i++) {
      acc += incomes[i] - expenses[i];
      cumulative.add(acc);
    }
    final maxBar = [...incomes, ...expenses, 1].reduce(max).toDouble();
    final maxAbsCum = cumulative.map((v) => v.abs()).fold<int>(1, max).toDouble();
    const labelH = 14.0;
    final chartH = size.height - labelH;
    final slot = size.width / n;
    final barW = slot * 0.3;

    final axis = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, chartH), Offset(size.width, chartH), axis);

    final inPaint = Paint()..color = Colors.greenAccent;
    final outPaint = Paint()..color = Colors.redAccent;
    for (int i = 0; i < n; i++) {
      final x = i * slot + slot * 0.15;
      final hIn = chartH * incomes[i] / maxBar;
      final hOut = chartH * expenses[i] / maxBar;
      canvas.drawRect(Rect.fromLTWH(x, chartH - hIn, barW, hIn), inPaint);
      canvas.drawRect(Rect.fromLTWH(x + barW + 2, chartH - hOut, barW, hOut), outPaint);
      final tp = TextPainter(
        text: TextSpan(text: '${i + 1}', style: const TextStyle(color: Colors.white54, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(i * slot + (slot - tp.width) / 2, chartH + 2));
    }

    // Linha do acumulado (zero no meio da área do gráfico)
    final mid = chartH / 2;
    final line = Paint()
      ..color = Colors.amber
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (int i = 0; i < n; i++) {
      final x = i * slot + slot / 2;
      final y = mid - (cumulative[i] / maxAbsCum) * (chartH / 2 - 4);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _CashflowPainter old) =>
      old.incomes != incomes || old.expenses != expenses;
}
