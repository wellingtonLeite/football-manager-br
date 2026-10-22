import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/engine.dart';
import '../game/models.dart';
import '../game/economy.dart';
import 'widgets.dart';

/// Departamento de marketing: contratos por espaço e propostas de patrocínio.
class MarketingScreen extends StatelessWidget {
  const MarketingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final t = game.userTeam;
    if (t == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Marketing'), backgroundColor: kGreen),
        body: const Center(child: Text('Você está sem clube.', style: TextStyle(color: Colors.white70))),
      );
    }
    final level = game.marketingLevel;
    return Scaffold(
      appBar: AppBar(title: const Text('Marketing e patrocínios'), backgroundColor: kGreen),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: kCard,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Patrocínios: ${formatMoney(game.sponsorTotal(t))}/mês',
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Diretor de marketing: ${level == 0 ? 'não contratado' : 'nível $level'} '
                    '(contrate em Clube › Comissão para receber mais propostas e mais valiosas).',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    game.userDecidesSponsors
                        ? 'Como presidente, você aceita ou recusa cada proposta. As luvas entram na hora no caixa; as parcelas, todo mês.'
                        : 'Quem decide é o presidente do clube: a diretoria fecha os contratos e o dinheiro entra no caixa.',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          sectionTitle('PROPOSTAS (${t.sponsorOffers.length})'),
          if (t.sponsorOffers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Nenhuma proposta agora. O marketing segue buscando patrocinadores.',
                  style: TextStyle(color: Colors.white54)),
            ),
          for (final o in List<SponsorOffer>.from(t.sponsorOffers)) _offerCard(context, game, t, o),
          sectionTitle('CONTRATOS'),
          for (final e in kSponsorSlots.entries) _slotTile(game, t, e.key, e.value),
        ],
      ),
    );
  }

  Widget _offerCard(BuildContext context, GameState game, Team t, SponsorOffer o) {
    final slot = kSponsorSlots[o.slot]!;
    final current = game.sponsorIn(t, o.slot);
    return Card(
      color: kCard,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${slot.$2} ${o.company}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            Text(slot.$1, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 6),
            infoRow('Valor', '${formatMoney(o.monthly)}/mês por ${o.seasons} temporada${o.seasons > 1 ? 's' : ''}'),
            infoRow('Luvas na assinatura', formatMoney(o.signingBonus)),
            infoRow('Contrato atual', current == null ? 'espaço vago' : '${current.company}: ${formatMoney(current.monthly)}/mês'),
            Text('Válida até a data ${o.expiresDay}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            if (game.userDecidesSponsors)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => game.rejectSponsorOffer(o),
                    child: const Text('Recusar', style: TextStyle(color: Colors.redAccent)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: () => showResult(context, game.acceptSponsorOffer(o)),
                    child: Text(current == null ? 'Aceitar' : 'Aceitar e trocar'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _slotTile(GameState game, Team t, String key, (String, String, double) slot) {
    final d = game.sponsorIn(t, key);
    return ListTile(
      dense: true,
      leading: Text(slot.$2, style: const TextStyle(fontSize: 24)),
      title: Text(d?.company ?? 'Vago', style: TextStyle(color: d == null ? Colors.white38 : Colors.white)),
      subtitle: Text(
        d == null
            ? '${slot.$1} • referência ${formatMoney(game.sponsorSlotBase(t, key))}/mês'
            : '${slot.$1} • ${d.seasonsLeft} temporada${d.seasonsLeft > 1 ? 's' : ''} restante${d.seasonsLeft > 1 ? 's' : ''}',
        style: const TextStyle(color: Colors.white60, fontSize: 11),
      ),
      trailing: d == null
          ? null
          : Text('${formatMoney(d.monthly)}/mês', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
    );
  }
}
