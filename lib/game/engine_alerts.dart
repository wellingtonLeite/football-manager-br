part of 'engine.dart';

/// Tela para onde um aviso leva.
enum AlertTarget { market, marketing, president, squad, finances, career }

/// Algo que está esperando uma ação do jogador (mostrado na tela inicial).
class GameAlert {
  final String icon;
  final String text;
  final AlertTarget target;
  final bool urgent;
  const GameAlert(this.icon, this.text, this.target, {this.urgent = false});
}

/// Central de avisos: reúne pendências espalhadas pelo jogo.
extension GameAlerts on GameState {
  List<GameAlert> get alerts {
    final t = userTeam;
    if (t == null || !managesClub) return const [];
    final out = <GameAlert>[];

    final pending = president?.pending.length ?? 0;
    if (mode == GameMode.presidente && pending > 0) {
      out.add(GameAlert('🏛️', '$pending decisão(ões) pendente(s) na Presidência', AlertTarget.president, urgent: true));
    }
    if (mode == GameMode.presidente && coachIsInterim(t)) {
      out.add(const GameAlert('👔', 'Time com técnico interino: escolha o novo técnico', AlertTarget.president, urgent: true));
    }
    if (t.balance < 0) {
      out.add(GameAlert('⚠️', 'Caixa negativo (${formatMoney(t.balance)}): salários atrasados derrubam o elenco', AlertTarget.finances,
          urgent: true));
    }
    if (controlsTeam && !seasonFinished) {
      final out0 = t.startingPlayers.where((p) => p.unavailable).length;
      if (out0 > 0) {
        out.add(GameAlert('🩹', '$out0 titular(es) lesionado(s) ou suspenso(s): ajuste a escalação', AlertTarget.squad, urgent: true));
      }
    }
    if (mode == GameMode.tecnico && career.employed && career.offers.isNotEmpty) {
      out.add(GameAlert('📨', '${career.offers.length} convite(s) de outros clubes', AlertTarget.career));
    }
    if (nationalOffer) {
      out.add(const GameAlert('🇧🇷', 'A CBF quer você na Seleção Brasileira', AlertTarget.career, urgent: true));
    }
    if (incomingOffers.isNotEmpty) {
      final best = incomingOffers.reduce((a, b) => a.amount >= b.amount ? a : b);
      out.add(GameAlert('💸', '${incomingOffers.length} proposta(s) por seus jogadores (até ${formatMoney(best.amount)})', AlertTarget.market));
    }
    if (userDecidesSponsors && t.sponsorOffers.isNotEmpty) {
      out.add(GameAlert('📣', '${t.sponsorOffers.length} proposta(s) de patrocínio aguardando', AlertTarget.marketing));
    }
    if (transferWindowOpen && !seasonFinished) {
      final end = currentDay <= (stageDays['WIN:1:end'] ?? 14) ? stageDays['WIN:1:end'] : stageDays['WIN:2:end'];
      final left = (end ?? currentDay) - currentDay;
      if (left <= 2) {
        out.add(GameAlert('🔄', 'A janela de transferências fecha em ${left + 1} data(s)', AlertTarget.market));
      }
    }
    final expiring = t.squad.where((p) => !p.onLoan && p.contractYears <= 1).length;
    if (expiring > 0 && currentDay >= totalDays * 0.5 && !seasonFinished) {
      out.add(GameAlert('🖊️', '$expiring contrato(s) terminam no fim da temporada', AlertTarget.market));
    }
    out.sort((a, b) => (b.urgent ? 1 : 0).compareTo(a.urgent ? 1 : 0));
    return out;
  }
}
