/// Fase 9 - Mercado de Transferências
///
/// Lógica de compra/venda de jogadores, agentes livres, empréstimos,
/// propostas com taxa de sucesso e mercado ativo entre clubes controlados
/// pela IA. Toda a operação é feita sobre o [GameState] para manter
/// consistência de calendário (nada muda: apenas elencos e finanças).
import 'dart:math';
import 'engine.dart';
import 'models.dart';

class MarketOffer {
  final String playerId;
  final String playerName;
  final String fromTeamId; // clube vendedor ('livre' = agente livre)
  final double askingPrice;
  final bool isLoan;

  MarketOffer({
    required this.playerId,
    required this.playerName,
    required this.fromTeamId,
    required this.askingPrice,
    this.isLoan = false,
  });
}

class PurchaseResult {
  final bool success;
  final String message;
  PurchaseResult(this.success, this.message);
}

class Marketplace {
  static final Random _rng = Random();

  /// Jogadores de outros clubes marcados como transferíveis + agentes livres.
  static List<MarketOffer> availableForUser(GameState game) {
    final offers = <MarketOffer>[];
    for (final t in game.teams) {
      if (t.id == game.userTeamId) continue;
      for (final p in t.squad) {
        if (p.transferListed) {
          offers.add(MarketOffer(
            playerId: p.id,
            playerName: p.name,
            fromTeamId: t.id,
            askingPrice: p.value,
          ));
        }
      }
    }
    for (final p in game.freeAgents) {
      offers.add(MarketOffer(
        playerId: p.id,
        playerName: p.name,
        fromTeamId: 'free',
        askingPrice: 0.5, // luva mínima
      ));
    }
    offers.sort((a, b) => b.askingPrice.compareTo(a.askingPrice));
    return offers;
  }

  /// Elenco do usuário disponível para vender (com opção de listar).
  static List<Player> sellableSquad(GameState game) {
    final team = game.userTeam!;
    return [...team.squad, ...game.loanedIn];
  }

  /// Taxa de sucesso ao tentar comprar [player] do clube [seller].
  static double successChance(double offer, double asking, int userStars,
      int sellerStars, double balance) {
    if (offer < asking * 0.6) return 0.05;
    double chance = 0.35;
    final ratio = offer / asking;
    chance += (ratio - 1.0) * 0.55; // oferecer mais aumenta muito a chance
    chance += (userStars - sellerStars) * 0.04; // reputação do clube comprador
    if (balance < offer) chance -= 0.5; // sem caixa suficiente quase nunca fecha
    return chance.clamp(0.02, 0.95);
  }

  /// Compra definitiva de um jogador listado em outro clube.
  static PurchaseResult buyPlayer(
      GameState game, String playerId, double offer) {
    final user = game.userTeam!;
    Team? seller;
    Player? player;
    for (final t in game.teams) {
      if (t.id == user.id) continue;
      final found = t.squad.where((p) => p.id == playerId).toList();
      if (found.isNotEmpty) {
        seller = t;
        player = found.first;
        break;
      }
    }
    if (seller == null || player == null) {
      return PurchaseResult(false, 'Jogador indisponível.');
    }
    if (offer > user.finances.balance) {
      return PurchaseResult(false, 'Caixa insuficiente para essa oferta.');
    }
    final asking = player.value;
    if (offer >= player.releaseClause) {
      // Cláusula paga: venda garantida
      _finalizePurchase(game, seller, user, player, offer);
      return PurchaseResult(true,
          'Cláusula rescisória paga! ${player.name} é do ${user.name}!');
    }
    final chance = successChance(offer, asking, user.stars, seller.stars,
        user.finances.balance);
    if (_rng.nextDouble() < chance) {
      _finalizePurchase(game, seller, user, player, offer);
      return PurchaseResult(true,
          '${seller.name} aceitou a proposta por ${player.name}!');
    }
    return PurchaseResult(false,
        '${seller.name} recusou a proposta por ${player.name}. Aumente o valor.');
  }

  static void _finalizePurchase(
      GameState game, Team seller, Team buyer, Player player, double fee) {
    seller.squad.remove(player);
    seller.startingIds.remove(player.id);
    seller.finances.credit('Venda: ${player.name}', fee, game.currentRound);
    buyer.finances.debit('Compra: ${player.name}', fee, game.currentRound);
    player.transferListed = false;
    player.contractYears = 3;
    buyer.squad.add(player);
    // reforço anima o vestiário
    player.morale = (player.morale + 10).clamp(0, 100).toInt();
    game.refresh();
    game.saveToDisk();
  }

  /// Contrata um agente livre (custo = luvas pequenas).
  static PurchaseResult signFreeAgent(GameState game, String playerId) {
    final user = game.userTeam!;
    final idx = game.freeAgents.indexWhere((p) => p.id == playerId);
    if (idx < 0) return PurchaseResult(false, 'Jogador já foi contratado.');
    final p = game.freeAgents[idx];
    final signingFee = 0.5;
    if (user.finances.balance < signingFee) {
      return PurchaseResult(false, 'Sem caixa para luvas de assinatura.');
    }
    game.freeAgents.removeAt(idx);
    user.finances.debit('Luvas: ${p.name}', signingFee, game.currentRound);
    p.contractYears = 2;
    p.morale = (p.morale + 10).clamp(0, 100).toInt();
    user.squad.add(p);
    game.refresh();
    game.saveToDisk();
    return PurchaseResult(true, '${p.name} assinou com o ${user.name}!');
  }

  /// Empréstimo de 1 temporada: custo menor, jogador volta ao dono depois.
  static PurchaseResult loanPlayer(
      GameState game, String playerId, double fee) {
    final user = game.userTeam!;
    Team? lender;
    Player? player;
    for (final t in game.teams) {
      if (t.id == user.id) continue;
      final found = t.squad.where((p) => p.id == playerId).toList();
      if (found.isNotEmpty) {
        lender = t;
        player = found.first;
        break;
      }
    }
    if (lender == null || player == null) {
      return PurchaseResult(false, 'Jogador indisponível.');
    }
    final minFee = double.parse((player.value * 0.2).toStringAsFixed(1));
    if (fee < minFee) {
      return PurchaseResult(false,
          'Empréstimo baixo demais. O ${lender.name} pede cerca de R\$ ${minFee}mi.');
    }
    if (fee > user.finances.balance) {
      return PurchaseResult(false, 'Caixa insuficiente para o empréstimo.');
    }
    lender.squad.remove(player);
    lender.startingIds.remove(player.id);
    lender.finances.credit('Empréstimo: ${player.name}', fee,
        game.currentRound);
    user.finances.debit('Empréstimo: ${player.name}', fee, game.currentRound);
    player.loanSeasonsLeft = 1;
    player.loanParentClubId = lender.id;
    game.loanedIn.add(player);
    game.refresh();
    game.saveToDisk();
    return PurchaseResult(true,
        '${player.name} chega por empréstimo (1 temporada).');
  }

  /// Coloca/remove jogador do usuário na lista de transferências.
  static void toggleTransferList(GameState game, String playerId) {
    final user = game.userTeam!;
    final p = user.squad.firstWhere((x) => x.id == playerId);
    p.transferListed = !p.transferListed;
    game.refresh();
    game.saveToDisk();
  }

  /// Venda direta do elenco do usuário para a IA (aceita se o preço estiver
  /// dentro da realidade do clube comprador).
  static PurchaseResult sellPlayer(
      GameState game, String playerId, double price) {
    final user = game.userTeam!;
    final idx = user.squad.indexWhere((p) => p.id == playerId);
    if (idx < 0) return PurchaseResult(false, 'Jogador não está no elenco.');
    final player = user.squad[idx];
    if (price < player.value * 0.7) {
      return PurchaseResult(false,
          'Preço muito abaixo do mercado (${player.value.toStringAsFixed(1)} mi).');
    }
    // procura um comprador rico o suficiente entre os rivais
    final buyers = game.teams
        .where((t) =>
            t.id != user.id && t.finances.balance >= price && t.stars <= user.stars + 1)
        .toList()
      ..sort((a, b) => b.finances.balance.compareTo(a.finances.balance));
    if (buyers.isEmpty) {
      return PurchaseResult(false,
          'Nenhum clube com caixa para pagar R\$ ${price.toStringAsFixed(1)}mi agora.');
    }
    final buyer = buyers.first;
    final chance = (0.85 - (price / player.value - 1.0) * 0.6)
        .clamp(0.15, 0.9)
        .toDouble();
    if (_rng.nextDouble() > chance) {
      return PurchaseResult(false,
          '${buyer.name} desistiu da negociação. Tente outro preço.');
    }
    user.squad.removeAt(idx);
    user.startingIds.remove(player.id);
    user.finances.credit('Venda: ${player.name}', price, game.currentRound);
    buyer.finances.debit('Compra: ${player.name}', price, game.currentRound);
    player.transferListed = false;
    player.contractYears = 3;
    buyer.squad.add(player);
    game.refresh();
    game.saveToDisk();
    return PurchaseResult(true,
        '${player.name} vendido ao ${buyer.name} por R\$ ${price.toStringAsFixed(1)}mi!');
  }

  /// IA movimenta o mercado entre clubes controlados por computador:
  /// às vezes lista/retira jogadores e faz uma compra simples por rodada.
  static void aiMarketActivity(GameState game) {
    for (final t in game.teams) {
      if (t.id == game.userTeamId) continue;
      for (final p in t.squad) {
        if (!p.transferListed && _rng.nextDouble() < 0.02) {
          p.transferListed = true;
        } else if (p.transferListed && _rng.nextBool()) {
          p.transferListed = false;
        }
      }
    }
    // uma transação aleatória entre dois clubes da IA por rodada
    final aiTeams =
        game.teams.where((t) => t.id != game.userTeamId).toList();
    if (aiTeams.length < 2) return;
    final seller = aiTeams[_rng.nextInt(aiTeams.length)];
    if (seller.squad.length <= 14) return;
    final listed = seller.squad.where((p) => p.transferListed).toList();
    if (listed.isEmpty) return;
    final buyer = aiTeams[_rng.nextInt(aiTeams.length)];
    if (buyer.id == seller.id || buyer.finances.balance < 5) return;
    final pool = listed
        .where((p) => p.value <= buyer.finances.balance)
        .toList();
    if (pool.isEmpty) return;
    final player = pool[_rng.nextInt(pool.length)];
    final fee = player.value;
    seller.squad.remove(player);
    seller.startingIds.remove(player.id);
    seller.finances.credit('Venda: ${player.name}', fee, game.currentRound);
    buyer.finances.debit('Compra: ${player.name}', fee, game.currentRound);
    player.transferListed = false;
    buyer.squad.add(player);
  }

  /// Gera pool inicial de agentes livres (jogadores sem clube).
  static List<Player> generateFreeAgents(Random rng) {
    const firstNames = [
      'Diego', 'Ricardo', 'Fernando', 'Marcelo', 'Juliano', 'Alexandre',
      'Walter', 'Rafael', 'Leandro', 'Douglas'
    ];
    const lastNames = [
      'Tadeu', 'Montenegro', 'Batista', 'Fagundes', 'Alencar', 'Sampaio',
      'Vasconcelos', 'Bittar', 'Neves', 'Camargo'
    ];
    const positions = ['GOL', 'ZAG', 'LAT', 'VOL', 'MEI', 'ATA'];
    final list = <Player>[];
    for (int i = 0; i < 12; i++) {
      final age = 19 + rng.nextInt(18);
      final overall = 62 + rng.nextInt(18);
      final p = Player(
        id: 'free_$i',
        name:
            '${firstNames[rng.nextInt(firstNames.length)]} ${lastNames[rng.nextInt(lastNames.length)]}',
        position: positions[i % positions.length],
        age: age,
        overall: overall,
        morale: 60,
      );
      p.refreshMarketNumbers();
      list.add(p);
    }
    return list;
  }
}
