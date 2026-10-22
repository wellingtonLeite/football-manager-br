import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:football_manager_br/main.dart';
import 'package:football_manager_br/game/data.dart';
import 'package:football_manager_br/game/economy.dart';
import 'package:football_manager_br/game/engine.dart';
import 'package:football_manager_br/game/models.dart';
import 'package:football_manager_br/ui/audio_service.dart';
import 'package:football_manager_br/ui/live_match_screen.dart';
import 'package:football_manager_br/ui/prematch_screen.dart';
import 'package:football_manager_br/ui/marketing_screen.dart';

/// Joga a data atual inteira (jogo do usuário com placar fixo) e avança.
void playDay(GameState g, {int hg = 1, int ag = 1}) {
  g.simulateOtherMatches();
  final m = g.userMatchCurrent;
  if (m != null) {
    final home = g.teamById(m.homeId);
    final away = g.teamById(m.awayId);
    final userIsHome = m.homeId == g.userTeamId;
    final user = userIsHome ? home : away;
    final ai = userIsHome ? away : home;
    final ug = userIsHome ? hg : ag;
    final og = userIsHome ? ag : hg;
    int? hp, ap;
    if (g.needsPenalties(m, hg, ag)) (hp, ap) = (5, 4);
    g.finishUserMatch(hg, ag, user.startingPlayers, const [], ai.startingPlayers, const [],
        homePens: hp, awayPens: ap);
    expect(ug + og, hg + ag);
  }
  g.advanceDay();
}

void playSeason(GameState g) {
  while (!g.seasonFinished) {
    playDay(g);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AudioService.enabled = false;
  });

  test('80 clubes brasileiros e 191 estrangeiros (8 ligas + copas), com ids únicos', () {
    final teams = createLeague();
    final foreign = createForeignTeams();
    expect(teams.length, 80);
    expect(foreign.where((t) => t.league.isNotEmpty).length, 152);
    expect(foreign.length, 191);
    final realMadrid = foreign.firstWhere((t) => t.name == 'Real Madrid');
    expect(realMadrid.squad.any((p) => p.name == 'Kylian Mbappé' && p.overall == 91), isTrue);
    for (int d = 1; d <= 4; d++) {
      expect(teams.where((t) => t.division == d).length, 20, reason: 'divisão $d');
    }
    final ids = <String>{};
    for (final t in [...teams, ...foreign]) {
      expect(ids.add(t.id), isTrue, reason: 'clube repetido ${t.id}');
      expect(t.squad.length, greaterThanOrEqualTo(GameState.minSquadSize), reason: t.name);
    }
    final playerIds = <String>{for (final t in [...teams, ...foreign]) for (final p in t.squad) p.id};
    expect(playerIds.length, [...teams, ...foreign].fold<int>(0, (s, t) => s + t.squad.length));
  });

  test('calendário: estaduais, 38 rodadas por divisão e copas', () {
    final g = GameState()..startGame('fla');
    for (final div in ['A', 'B', 'C', 'ENG', 'ESP', 'ITA', 'ARG']) {
      expect(g.matches.where((m) => m.comp == div).length, 380, reason: div);
    }
    expect(g.matches.where((m) => m.comp == 'GER').length, 306);
    expect(g.matches.where((m) => m.comp == 'D' && m.stage == 'G').length, 80);
    expect(g.matches.where((m) => m.comp == 'SUP').length, 1);
    expect(g.matches.where((m) => m.comp == 'REC').length, 2);
    expect(g.matches.where((m) => m.comp == 'UCL').length, 16);
    expect(g.matches.where((m) => m.comp == 'CDB').length, 16);
    expect(g.matches.where((m) => m.comp == 'LIB').length, 96);
    expect(g.matches.where((m) => m.comp == 'SUL').length, 96);
    expect(g.regionalGroups.keys, containsAll(['SP', 'RJ', 'MG', 'RS']));
    // Nenhum clube joga duas vezes na mesma data
    for (int d = 1; d <= g.totalDays; d++) {
      final ids = <String>[];
      for (final m in g.matchesOfDay(d)) {
        ids
          ..add(m.homeId)
          ..add(m.awayId);
      }
      expect(ids.length, ids.toSet().length, reason: 'data $d');
    }
  });

  test('temporada completa: campeões, mata-matas, acesso e rebaixamento', () {
    final g = GameState()..startGame('pal', coachName: 'Teste');
    playSeason(g);
    final record = g.history.single;
    expect(record.titles.keys, containsAll(['Série A', 'Série B', 'Série C', 'Série D', 'Copa do Brasil', 'Libertadores',
        'Sul-Americana', 'Supercopa do Brasil', 'Recopa Sul-Americana', 'Liga dos Campeões', 'Copa Intercontinental',
        'Premier League', 'La Liga', '🏅 Bola de Ouro', '👟 Artilheiro da Série A']));
    expect(g.matches.every((m) => m.isPlayed), isTrue);
    expect(g.topScorers('A').first.goalsByComp['A'], greaterThan(5));
    for (final comp in ['CDB', 'LIB', 'SUL', 'D', 'UCL', 'MUN']) {
      expect(g.tieWinner(comp, 'F', 0), isNotNull, reason: comp);
    }
    expect(g.pendingDivisions.length, 24);
    final relegatedA = g.standingsOf(1).sublist(16).map((t) => t.id).toList();
    final promotedB = g.standingsOf(2).take(4).map((t) => t.id).toList();
    g.startNewSeason();
    expect(g.seasonYear, 2027);
    for (final id in relegatedA) {
      expect(g.teamById(id).division, 2);
    }
    for (final id in promotedB) {
      expect(g.teamById(id).division, 1);
    }
    for (int d = 1; d <= 4; d++) {
      expect(g.teams.where((t) => t.division == d).length, 20);
    }
    for (final t in g.teams) {
      expect(t.squad.length, greaterThanOrEqualTo(GameState.minSquadSize), reason: t.name);
    }
    playSeason(g);
    expect(g.history.length, 2);
  });

  test('pênaltis decidem empate em jogo único de mata-mata', () {
    final g = GameState()..startGame('fla');
    final m = Match(round: 0, homeId: 'fla', awayId: 'pal', comp: 'CDB', stage: 'R32', day: 1);
    expect(g.needsPenalties(m, 1, 1), isTrue);
    expect(g.needsPenalties(m, 2, 1), isFalse);
    final (h, a) = g.shootout(g.teamById('fla'), g.teamById('pal'));
    expect(h == a, isFalse);
  });

  test('finanças: receitas e salários entram no extrato', () {
    final g = GameState()..startGame('pal');
    final start = g.userTeam!.balance;
    for (int i = 0; i < 7; i++) {
      playDay(g, hg: 2, ag: 0);
    }
    final cats = g.ledger.map((e) => e.category).toSet();
    expect(cats, containsAll(['Salários', 'Patrocínio', 'Cotas de TV']));
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

  test('mercado: multa rescisória, agente livre e venda', () {
    final g = GameState()..startGame('fla');
    final user = g.userTeam!;
    user.balance = 2000000000;
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

    final fa = g.freeAgents.first;
    final r2 = g.signFreeAgent(fa.id, wage: g.wageDemand(fa) * 2, years: 2);
    expect(r2.success, isTrue, reason: r2.message);

    final sold = user.squad.last;
    final buyer = g.teamById('cam');
    final offer = TransferOffer(playerId: sold.id, buyerId: buyer.id, amount: 1000000, expiresRound: 99);
    g.incomingOffers.add(offer);
    final balance = user.balance;
    final r3 = g.acceptOffer(offer);
    expect(r3.success, isTrue, reason: r3.message);
    expect(user.balance, balance + 1000000);
  });

  test('pré-jogo: troca de titular e tática escolhida', () {
    final g = GameState()..startGame('fla');
    final t = g.userTeam!;
    g.ensureUserLineup();
    final out = t.startingPlayers.first;
    final inn = t.squad.firstWhere((p) => !t.startingIds.contains(p.id));
    g.swapStarter(out.id, inn.id);
    expect(t.startingIds.contains(inn.id), isTrue);
    expect(t.startingIds.contains(out.id), isFalse);
    g.setUserTactic(Tactic.ofensivo);
    expect(g.userTactic, Tactic.ofensivo);
  });

  test('carreira de técnico: demissão e novo emprego', () {
    final g = GameState()..startGame('fla');
    // Com tantas derrotas a diretoria pode demitir antes da 6ª partida
    while (g.career.employed && g.userTeam!.played < 6) {
      playDay(g, hg: 0, ag: 3);
    }
    if (g.career.employed) {
      g.career.boardConfidence = 0;
      playDay(g, hg: 0, ag: 3);
    }
    expect(g.career.employed, isFalse);
    expect(g.career.offers, isNotEmpty);
    final offer = g.career.offers.first;
    g.acceptJobOffer(offer);
    expect(g.userTeamId, offer.teamId);
    expect(g.userTeam!.coach, g.career.name);
  });

  test('Modo Presidente: crises, técnico, patrimônio e eleição', () {
    final g = GameState()..startPresident('cru', name: 'Pres');
    expect(g.mode, GameMode.presidente);
    expect(g.president, isNotNull);
    g.userTeam!.balance = 500000000;
    final coaches = g.availableCoaches();
    expect(coaches, isNotEmpty);
    expect(g.hireCoach(coaches.first).success, isTrue);
    expect(g.userTeam!.coach, coaches.first.name);
    for (int season = 0; season < 3 && g.president != null; season++) {
      while (!g.seasonFinished) {
        g.simulateOtherMatches();
        expect(g.userMatchCurrent, isNull, reason: 'presidente não joga ao vivo');
        for (final e in List.of(g.president?.pending ?? <CrisisEvent>[])) {
          g.resolveCrisis(e, 1);
        }
        g.advanceDay();
      }
      g.startNewSeason();
    }
    // Ao fim do 3º ano houve eleição (reeleito ou fora do clube)
    expect(g.president == null || g.president!.elections == 1, isTrue);
  });

  test('Modo Jogador: notas, gols, Seleção e aposentadoria', () {
    final g = GameState();
    g.startPlayerCareer(name: 'Craque', nationality: 'Brasil', position: 'ATA', age: 18, style: 'Craque da base', teamId: 'por');
    final p = g.userPlayer!;
    expect(p.overall, startingOverall(18, 'Craque da base'));
    p.overall = 80; // titular garantido para o teste
    while (!g.seasonFinished) {
      g.simulateOtherMatches();
      g.advanceDay();
    }
    final s = g.currentPlayerStats!;
    expect(s.games, greaterThanOrEqualTo(6)); // Série D é curta: grupos + mata-mata
    expect(s.avgRating, inInclusiveRange(3.0, 10.0));
    expect(g.requestTransfer().success, isTrue);
    g.startNewSeason();
    expect(g.userPlayer, isNotNull);
    g.retirePlayer();
    expect(g.playerCareer!.retired, isTrue);
  });

  test('save e load preservam o estado', () async {
    final g = GameState()..startGame('cru', coachName: 'Save');
    for (int i = 0; i < 10; i++) {
      playDay(g);
    }
    await g.saveToDisk();
    final loaded = await GameState.loadFromDisk();
    expect(loaded, isNotNull);
    expect(loaded!.userTeamId, 'cru');
    expect(loaded.career.name, 'Save');
    expect(loaded.currentDay, g.currentDay);
    expect(loaded.teams.length, 80);
    expect(loaded.foreignTeams.length, 191);
    expect(loaded.matches.length, g.matches.length);
    expect(loaded.userTeam!.balance, g.userTeam!.balance);
    // O jogo continua normalmente depois de carregar
    playDay(loaded);
    expect(loaded.currentDay, g.currentDay + 1);
  });

  test('cartões: 3 amarelos ou vermelho suspendem e o suspenso não é escalado', () {
    final g = GameState()..startGame('fla');
    final t = g.userTeam!;
    final p = t.startingPlayers.first;
    p.yellowCards = 2;
    final m = g.userMatchCurrent!;
    final opp = g.teamById(m.homeId == t.id ? m.awayId : m.homeId);
    g.simulateOtherMatches();
    g.finishUserMatch(1, 0, t.startingPlayers, const [], opp.startingPlayers, const [], yellowIds: [p.id]);
    expect(p.suspended, 1);
    expect(p.yellowCards, 0);
    g.advanceDay();
    g.ensureUserLineup();
    expect(t.startingIds.contains(p.id), isFalse);
  });

  test('mercado: janela, clube estrangeiro, comissão e cláusula de revenda', () {
    final g = GameState()..startGame('fla');
    final user = g.userTeam!;
    user.balance = 3000000000;
    expect(g.transferWindowOpen, isTrue);
    final city = g.foreignTeams.firstWhere((t) => t.name == 'Manchester City');
    final target = city.squad.firstWhere((p) => p.overall < 85);
    final r = g.proposeTransfer(playerId: target.id, fee: target.releaseClause,
        wage: g.wageDemand(target, from: city) * 2, signingBonus: 0, years: 3);
    expect(r.success, isTrue, reason: r.message);
    expect(g.ledger.any((e) => e.description.startsWith('Comissão do empresário')), isTrue);
    // Fecha a janela: compra bloqueada, agente livre liberado
    while (g.transferWindowOpen) {
      playDay(g);
    }
    final other = g.teamById('rem').squad.first;
    expect(g.proposeTransfer(playerId: other.id, fee: other.releaseClause, wage: 999999999, signingBonus: 0, years: 2).success, isFalse);
    final fa = g.freeAgents.first;
    expect(g.signFreeAgent(fa.id, wage: g.wageDemand(fa) * 2, years: 1).success, isTrue);
  });

  test('clube: treino, comissão, base, olheiro e sócios', () {
    final g = GameState()..startGame('cru');
    g.userTeam!.balance = 500000000;
    g.setTraining(focus: 'finalizacao', intensity: 'intensa');
    expect(g.trainingAttack(g.userTeam!), greaterThan(0));
    expect(g.hireStaff('olheiro').success, isTrue);
    expect(g.academy, isNotEmpty);
    final y = g.academy.first;
    expect(g.promoteYouth(y.id).success, isTrue);
    expect(g.userTeam!.findPlayer(y.id), isNotNull);
    final before = g.scouted.length;
    playDay(g);
    expect(g.scouted.length, greaterThan(before));
    g.setMemberPrice(100);
    expect(g.expectedMembers(g.userTeam!), greaterThan(0));
    g.setFormation(Formation.f433);
    g.ensureUserLineup();
    expect(g.userTeam!.startingPlayers.where((p) => p.position == 'ATA').length, 3);
  });

  test('Seleção Brasileira: convite, convocação e jogos', () {
    final g = GameState()..startGame('fla');
    g.career.reputation = 90;
    g.nationalOffer = true;
    g.acceptNationalTeam();
    expect(g.isNationalCoach, isTrue);
    expect(g.national!.squad.length, 23);
    while (!g.seasonFinished) {
      g.simulateOtherMatches();
      g.advanceDay();
    }
    final n = g.national;
    expect(n == null || n.wins + n.draws + n.losses >= 6, isTrue);
  });

  test('backup: exportar e importar a carreira', () async {
    final g = GameState()..startGame('bot', coachName: 'Backup');
    playDay(g);
    final raw = g.exportSave();
    final other = GameState();
    expect(await other.importSave(raw), isTrue);
    expect(other.career.name, 'Backup');
    expect(other.userTeamId, 'bot');
    expect(await other.importSave('lixo'), isFalse);
  });

  test('multiplayer local: dois técnicos, cada um com seu clube e suas finanças', () async {
    final g = GameState()..startMultiplayer([('Ana', 'fla'), ('Beto', 'pal')]);
    expect(g.isMultiplayer, isTrue);
    expect(g.teamById('fla').coach, 'Ana');
    expect(g.teamById('pal').coach, 'Beto');
    for (int d = 0; d < 15; d++) {
      g.simulateOtherMatches();
      for (final i in g.humansWithMatchToday()) {
        g.setActiveHuman(i);
        g.simulateUserMatchQuick();
      }
      expect(g.dayPlayed, isTrue, reason: 'data ${g.currentDay}');
      g.advanceDay();
    }
    g.setActiveHuman(1);
    expect(g.userTeamId, 'pal');
    expect(g.career.name, 'Beto');
    expect(g.ledger.any((e) => e.teamId == 'pal'), isTrue);
    expect(g.ledger.any((e) => e.teamId == 'fla'), isTrue);
    g.setTraining(focus: 'defesa');
    g.setActiveHuman(0);
    expect(g.trainingFocus, 'equilibrado');
    final copy = GameState();
    expect(await copy.importSave(g.exportSave()), isTrue);
    expect(copy.humans.length, 2);
    expect(copy.humans[1].club.trainingFocus, 'defesa');
  });

  test('1ª temporada: só os classificados reais para a Libertadores e Sul-Americana 2026', () {
    final g = GameState()..startGame('bah');
    Set<String> brs(String comp) => {
          for (final m in g.matches.where((m) => m.comp == comp))
            for (final id in [m.homeId, m.awayId])
              if (!g.teamById(id).isForeign) id,
        };
    expect(brs('LIB'), {'fla', 'pal', 'cru', 'mir', 'flu', 'cor'});
    expect(brs('SUL'), {'cam', 'sao', 'san', 'bot', 'gre', 'vas', 'rbb'});
  });

  test('emprestar jogador do elenco: sai, o outro clube paga o salário e ele volta no fim', () {
    final g = GameState()..startGame('fla');
    final user = g.userTeam!;
    final p = user.squad.firstWhere((x) => !user.startingIds.contains(x.id));
    final payroll = user.payroll;
    final suitors = g.loanSuitors(p);
    expect(suitors, isNotEmpty);
    TransferResult? r;
    for (int i = 0; i < 30 && !(r?.success ?? false); i++) {
      r = g.loanOut(p.id, suitors.first.$1.id, fee: suitors.first.$2);
    }
    expect(r!.success, isTrue, reason: r.message);
    expect(user.findPlayer(p.id), isNull);
    expect(user.payroll, payroll - p.wage);
    expect(g.loanedOut.map((e) => e.$2.id), contains(p.id));
    expect(suitors.first.$1.findPlayer(p.id)?.loanFromTeamId, 'fla');
    playSeason(g);
    g.startNewSeason();
    expect(g.teamById('fla').findPlayer(p.id)?.loanFromTeamId, isNull);
  });

  test('empréstimo com opção de compra negociada e compra definitiva', () {
    final g = GameState()..startGame('fla');
    g.userTeam!.balance = 500000000;
    final seller = g.teamById('cru');
    final p = seller.squad.firstWhere((x) => !seller.startingIds.contains(x.id));
    final fee = g.loanFee(p) * 3;
    final option = (g.suggestedOptionPrice(p) * 1.3).round();
    TransferResult? r;
    for (int i = 0; i < 40 && !(r?.success ?? false); i++) {
      r = g.proposeLoan(p.id, fee: fee, withOption: true, optionPrice: option);
    }
    expect(r!.success, isTrue, reason: r.message);
    expect(g.loanOptions[p.id], option);
    expect(g.exerciseLoanOption(p.id).success, isTrue);
    expect(g.userTeam!.findPlayer(p.id)?.onLoan, isFalse);
  });

  test('mercado: busca por nome (sem acento), idade e ordenação', () {
    final g = GameState()..startGame('fla');
    final found = g.marketPlayers(region: 'ALL', query: 'mbappe');
    expect(found.map((e) => e.$2.name), contains('Kylian Mbappé'));
    final young = g.marketPlayers(region: 'BRA', maxAge: 21, sort: 'age');
    expect(young, isNotEmpty);
    expect(young.every((e) => e.$2.age <= 21), isTrue);
    expect(young.first.$2.age <= young.last.$2.age, isTrue);
  });

  test('coletiva: comenta o resultado do último jogo de verdade', () {
    final g = GameState()..startGame('fla');
    for (int i = 0; i < 40; i++) {
      final m = g.userMatchCurrent;
      if (m != null) {
        final home = m.homeId == g.userTeamId;
        playDay(g, hg: home ? 3 : 0, ag: home ? 0 : 3); // sempre vitória por 3 x 0
        final q = g.generatePressConference().first.question;
        expect(q, contains('Vitória por 3 x 0'), reason: 'dia ${g.currentDay}: $q');
      } else {
        playDay(g);
      }
    }
  });

  test('marketing: presidente aceita patrocínio, luvas e parcelas entram no caixa', () {
    final g = GameState()..startPresident('mir');
    final t = g.userTeam!;
    SponsorOffer? offer;
    for (int i = 0; i < 60 && offer == null && !g.seasonFinished; i++) {
      playDay(g);
      offer = t.sponsorOffers.firstOrNull;
    }
    expect(offer, isNotNull, reason: 'o marketing deveria trazer propostas');
    expect(t.sponsors.map((d) => d.slot), containsAll(['master', 'material']));
    final before = t.balance;
    expect(g.acceptSponsorOffer(offer!).success, isTrue);
    expect(t.balance, before + offer.signingBonus);
    expect(g.sponsorIn(t, offer.slot)?.company, offer.company);
    do {
      playDay(g);
    } while (g.currentDay % 6 != 1);
    expect(g.ledger.any((e) => e.category == 'Patrocínio' && e.description.startsWith(offer!.company)), isTrue);
  });

  test('marketing: no modo técnico a diretoria fecha os patrocínios', () {
    final g = GameState()..startGame('bah');
    final t = g.userTeam!;
    for (int i = 0; i < 40; i++) {
      playDay(g);
    }
    expect(t.sponsorOffers, isEmpty);
    expect(t.sponsors.length, greaterThan(2), reason: 'a diretoria deveria preencher espaços vagos');
  });

  test('premiações entram durante a temporada: grupos da Libertadores e 1º turno', () {
    final g = GameState()..startPresident('fla');
    while (g.currentDay <= (g.stageDays['WIN:2:start'] ?? 0)) {
      playDay(g);
    }
    expect(g.ledger.any((e) => e.description.contains('cota por jogo da fase de grupos')), isTrue);
    expect(g.ledger.any((e) => e.description.startsWith('Premiação do 1º turno')), isTrue);
    playSeason(g);
    expect(g.ledger.any((e) => e.description.startsWith('Premiação final')), isTrue);
  });

  test('presidente demite o técnico e escolhe o substituto', () {
    final g = GameState()..startPresident('bah');
    final t = g.userTeam!;
    final old = t.coach;
    expect(g.fireCoach().success, isTrue);
    expect(g.coachIsInterim(t), isTrue);
    expect(t.coach, isNot(old));
    // A crise da torcida também não escolhe ninguém sozinha
    final choice = g.availableCoaches().first;
    final before = t.balance;
    expect(g.hireCoach(choice).success, isTrue);
    expect(t.coach, choice.name);
    expect(t.balance, before, reason: 'sem multa ao substituir o interino');
    g.president!.pending.add(CrisisEvent(kind: 'demitir', title: 't', text: 't', options: const ['a', 'b']));
    g.resolveCrisis(g.president!.pending.first, 0);
    expect(g.coachIsInterim(t), isTrue);
  });

  testWidgets('tela de marketing: contratos e proposta para o presidente', (tester) async {
    final g = GameState()..startPresident('mir');
    for (int i = 0; i < 60 && g.userTeam!.sponsorOffers.isEmpty; i++) {
      playDay(g);
    }
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioService()),
        ChangeNotifierProvider<GameState>.value(value: g),
      ],
      child: const MaterialApp(home: MarketingScreen()),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Patrocínios:'), findsOneWidget);
    expect(find.text('Aceitar').evaluate().length + find.text('Aceitar e trocar').evaluate().length, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2)); // salvamento automático pendente
  });

  testWidgets('jogo ao vivo contra clube estrangeiro (Libertadores)', (tester) async {
    final g = GameState()..startGame('fla');
    while (g.userMatchCurrent?.comp != 'LIB') {
      playDay(g);
    }
    g.simulateOtherMatches();
    g.ensureUserLineup();
    Widget app(Widget home) => MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AudioService()),
            ChangeNotifierProvider<GameState>.value(value: g),
          ],
          child: MaterialApp(home: home),
        );
    await tester.pumpWidget(app(const PreMatchScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(app(const LiveMatchScreen()));
    for (int i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(tester.takeException(), isNull);
    expect(find.textContaining('INTERVALO'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('nova carreira: modo, clube e telas principais', (tester) async {
    await tester.pumpWidget(const FootballManagerApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('Espaço 1'), findsOneWidget);
    await tester.tap(find.textContaining('Espaço 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Técnico'));
    await tester.pumpAndSettle();
    expect(find.text('Escolha seu Clube'), findsOneWidget);
    await tester.tap(find.text('Flamengo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Data 1 de'), findsOneWidget); // Supercopa: Flamengo x Corinthians
    await tester.tap(find.textContaining('Data 1 de'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Preparar o jogo'), findsOneWidget);
    await tester.tap(find.textContaining('Preparar o jogo'));
    await tester.pumpAndSettle();
    expect(find.text('Pré-jogo'), findsOneWidget);
    expect(find.text('TÁTICA'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('🏆 Competições'), 200);
    await tester.tap(find.text('🏆 Competições'));
    await tester.pumpAndSettle();
    expect(find.text('Libertadores'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2)); // salvamento agendado
  });
}
