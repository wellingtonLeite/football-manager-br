import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:football_manager_br/main.dart';
import 'package:football_manager_br/game/data.dart';
import 'package:football_manager_br/game/economy.dart';
import 'package:football_manager_br/game/engine.dart';
import 'package:football_manager_br/game/models.dart';

/// Joga a rodada atual inteira (jogo do usuário com placar fixo) e avança.
void playRound(GameState g, {int hg = 1, int ag = 1}) {
  g.simulateOtherMatches();
  final m = g.userMatchCurrent;
  if (m != null) {
    final home = g.teamById(m.homeId);
    final away = g.teamById(m.awayId);
    final userIsHome = m.homeId == g.userTeamId;
    final user = userIsHome ? home : away;
    final ai = userIsHome ? away : home;
    g.finishUserMatch(hg, ag, user.startingPlayers, const [], ai.startingPlayers, const []);
  }
  g.advanceRound();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('liga 2026 tem 20 clubes com elencos completos e ids únicos', () {
    final teams = createLeague();
    expect(teams.length, 20);
    expect(teams.any((t) => t.shortName == 'VIT'), isTrue);
    final ids = <String>{};
    for (final t in teams) {
      expect(t.squad.length, greaterThanOrEqualTo(22), reason: t.name);
      kSquadTargets.forEach((pos, n) {
        expect(t.squad.where((p) => p.position == pos).length, greaterThanOrEqualTo(n),
            reason: '${t.name} $pos');
      });
      for (final p in t.squad) {
        expect(ids.add(p.id), isTrue, reason: 'id duplicado ${p.id}');
      }
      expect(t.balance, initialBudget(t.stars));
    }
  });

  test('duas temporadas completas rodam sem erros', () {
    final g = GameState()..startGame('fla', coachName: 'Teste');
    expect(g.career.name, 'Teste');
    expect(g.userTeam!.coach, 'Teste');
    for (int season = 0; season < 2; season++) {
      while (!g.seasonFinished) {
        playRound(g);
      }
      expect(g.history.length, season + 1);
      expect(g.matches.every((m) => m.isPlayed), isTrue);
      g.startNewSeason();
      expect(g.currentRound, 1);
      for (final t in g.teams) {
        expect(t.squad.length, greaterThanOrEqualTo(GameState.minSquadSize), reason: t.name);
        expect(t.startingIds.length, 11, reason: t.name);
      }
    }
    expect(g.seasonYear, 2028);
  });

  test('finanças: receitas e salários entram no extrato', () {
    final g = GameState()..startGame('pal');
    final start = g.userTeam!.balance;
    for (int i = 0; i < 4; i++) {
      playRound(g, hg: 2, ag: 0);
    }
    final cats = g.ledger.map((e) => e.category).toSet();
    expect(cats, containsAll(['Salários', 'Patrocínio', 'Cotas de TV', 'Premiação']));
    expect(g.userTeam!.balance, isNot(start));
  });

  test('investimento em estrutura cobra e sobe o nível', () {
    final g = GameState()..startGame('fla');
    final t = g.userTeam!;
    final before = t.balance;
    final level = Facility.estadio.levelOf(t);
    final r = g.upgradeFacility(Facility.estadio);
    expect(r.success, isTrue);
    expect(Facility.estadio.levelOf(t), level + 1);
    expect(t.balance, before - facilityCost(level + 1));
  });

  test('mercado: multa rescisória, agente livre, venda e empréstimo', () {
    final g = GameState()..startGame('fla');
    final user = g.userTeam!;
    user.balance = 2000000000;

    // Compra pagando a multa: o clube vendedor não pode recusar
    final seller = g.teamById('rem');
    final target = seller.squad.first;
    final r = g.proposeTransfer(
      playerId: target.id,
      fee: target.releaseClause,
      wage: g.wageDemand(target, from: seller) * 2,
      signingBonus: 0,
      years: 3,
    );
    expect(r.success, isTrue, reason: r.message);
    expect(user.findPlayer(target.id), isNotNull);
    expect(seller.findPlayer(target.id), isNull);

    // Agente livre aceitando o salário pedido
    final fa = g.freeAgents.first;
    final r2 = g.signFreeAgent(fa.id, wage: g.wageDemand(fa) * 2, years: 2);
    expect(r2.success, isTrue, reason: r2.message);
    expect(g.freeAgents.contains(fa), isFalse);

    // Venda: proposta recebida e aceita
    final sold = user.squad.last;
    final buyer = g.teamById('cam');
    final offer = TransferOffer(playerId: sold.id, buyerId: buyer.id, amount: 1000000, expiresRound: 5);
    g.incomingOffers.add(offer);
    final balance = user.balance;
    final r3 = g.acceptOffer(offer);
    expect(r3.success, isTrue, reason: r3.message);
    expect(buyer.findPlayer(sold.id), isNotNull);
    expect(user.balance, balance + 1000000);
  });

  test('empréstimo volta ao clube de origem na nova temporada', () {
    final g = GameState()..startGame('fla');
    final user = g.userTeam!;
    final owner = g.teamById('cha');
    // Jogador jovem e com contrato longo: não se aposenta nem fica livre na virada
    final p = owner.squad.firstWhere((x) => !owner.startingIds.contains(x.id) && x.age < 30);
    p.contractYears = 3;
    // Força o empréstimo (a IA pode recusar aleatoriamente)
    owner.squad.remove(p);
    p.loanFromTeamId = owner.id;
    user.squad.add(p);
    while (!g.seasonFinished) {
      playRound(g);
    }
    g.startNewSeason();
    expect(owner.findPlayer(p.id), isNotNull);
    expect(user.findPlayer(p.id), isNull);
  });

  test('carreira: demissão e convite de emprego', () {
    final g = GameState()..startGame('fla');
    for (int i = 0; i < 6; i++) {
      playRound(g, hg: 0, ag: 3);
    }
    g.career.boardConfidence = 0;
    playRound(g, hg: 0, ag: 3);
    expect(g.career.employed, isFalse);
    expect(g.userTeamId, isNull);
    expect(g.career.offers, isNotEmpty);
    final offer = g.career.offers.first;
    g.acceptJobOffer(offer);
    expect(g.career.employed, isTrue);
    expect(g.userTeamId, offer.teamId);
    expect(g.userTeam!.coach, g.career.name);
  });

  test('save e load preservam o estado', () async {
    final g = GameState()..startGame('cru', coachName: 'Save');
    playRound(g);
    await g.saveToDisk();
    final loaded = await GameState.loadFromDisk();
    expect(loaded, isNotNull);
    expect(loaded!.userTeamId, 'cru');
    expect(loaded.career.name, 'Save');
    expect(loaded.currentRound, g.currentRound);
    expect(loaded.teams.length, 20);
    expect(loaded.userTeam!.balance, g.userTeam!.balance);
    expect(loaded.freeAgents.length, g.freeAgents.length);
  });

  testWidgets('tela inicial abre e oferece nova carreira', (tester) async {
    await tester.pumpWidget(const FootballManagerApp());
    expect(find.text('NOVA CARREIRA'), findsOneWidget);
    expect(find.text('CONTINUAR CARREIRA'), findsNothing);
    await tester.tap(find.text('NOVA CARREIRA'));
    await tester.pumpAndSettle();
    expect(find.text('Escolha seu Clube'), findsOneWidget);
    await tester.tap(find.text('Flamengo'));
    await tester.pumpAndSettle();
    expect(find.text('⚽ Rodada 1'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('💰 Finanças'), 200);
    await tester.tap(find.text('💰 Finanças'));
    await tester.pumpAndSettle();
    expect(find.text('💰 Caixa do clube'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(Scaffold), findsWidgets);
  });
}
