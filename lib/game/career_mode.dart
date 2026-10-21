/// Fase 10A - Modo Técnico (Carreira de Treinador)
///
/// Metas da diretoria, avaliação por pontos por jogo, risco de demissão,
/// reputação pessoal do técnico e convites de outros clubes.
import 'models.dart';

class BoardGoal {
  final String description;
  final int targetPosition; // posição máxima aceita ao fim da temporada
  final double bonusMi; // bônus financeiro por cumprir a meta
  bool achieved;

  BoardGoal({
    required this.description,
    required this.targetPosition,
    required this.bonusMi,
    this.achieved = false,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'targetPosition': targetPosition,
        'bonusMi': bonusMi,
        'achieved': achieved,
      };

  factory BoardGoal.fromJson(Map<String, dynamic> j) => BoardGoal(
        description: j['description'],
        targetPosition: j['targetPosition'],
        bonusMi: (j['bonusMi'] ?? 0).toDouble(),
        achieved: j['achieved'] ?? false,
      );
}

class CoachJobOffer {
  final String teamId;
  final String teamName;
  final int stars;
  final double salaryMi; // salário anual do técnico
  CoachJobOffer(this.teamId, this.teamName, this.stars, this.salaryMi);
}

class CareerManager {
  int reputation = 50; // 0..100 - fama do treinador
  int titles = 0;
  double coachSalary = 2.0;
  BoardGoal? goal;
  bool fired = false;
  bool unemployed = false;
  List<String> log = [];

  CareerManager();

  /// Meta inicial conforme o tamanho do clube.
  static BoardGoal goalForTeam(Team t, int currentReputation) {
    if (t.stars >= 5) {
      return BoardGoal(
          description: 'Conquistar o título ou chegar no G4',
          targetPosition: 4,
          bonusMi: 15.0);
    }
    if (t.stars == 4) {
      return BoardGoal(
          description: 'Terminar entre os 8 primeiros',
          targetPosition: 8,
          bonusMi: 8.0);
      }
    return BoardGoal(
        description: 'Evitar o rebaixamento (fora do Z4)',
        targetPosition: 16,
        bonusMi: 5.0);
  }

  /// Pontos por jogo médios do usuário até agora.
  static double ppg(int points, int played) =>
      played == 0 ? 0 : points / played;

  /// Risco de demissão avaliado ao fim de cada rodada.
  /// Retorna mensagem se houve demissão, null caso contrário.
  String? evaluateRisk(GameStateProxy game) {
    if (fired || unemployed) return null;
    final pos = game.userPosition;
    final ppg = game.ppg;
    final streak = game.lossStreak;
    // critérios: sequência grande de derrotas OU lanterna com PPG muito baixo
    final inDanger = (streak >= 5) || (pos >= 18 && ppg < 0.8) ||
        (goal != null && pos > goal!.targetPosition + 6 && ppg < 1.0);
    if (!inDanger) return null;
    // chance cresce com a gravidade
    double risk = 0.15;
    if (streak >= 7) risk += 0.3;
    if (pos >= 18) risk += 0.25;
    if (reputation < 40) risk += 0.1;
    if (game.rngDouble() < risk.clamp(0.05, 0.9)) {
      fired = true;
      unemployed = true;
      reputation = (reputation - 8).clamp(0, 100).toInt();
      log.add('Diretoria demitiu você após má campanha!');
      return 'Você foi DEMITIDO pelo ${game.teamName}! A diretoria anunciou mudança no comando.';
    }
    log.add('Diretoria reuniu-se em emergência, mas manteve o trabalho.');
    return '⚠️ A diretoria está reunida em emergência. Seus dias no clube estão contados...';
  }

  /// Ao fim da temporada: checa meta, ajusta reputação, devolve/renova.
  String endSeason(int finalPosition, Team userTeam) {
    final msgs = <String>[];
    if (finalPosition == 1) {
      titles++;
      reputation = (reputation + 15).clamp(0, 100).toInt();
      msgs.add('🏆 Campeão! Reputação disparou (+15).');
    } else if (finalPosition <= 4) {
      reputation = (reputation + 8).clamp(0, 100).toInt();
      msgs.add('Vaga na Libertadores garantida! (+8 reputação)');
    } else if (finalPosition >= 17) {
      reputation = (reputation - 12).clamp(0, 100).toInt();
      msgs.add('Rebaixamento destruiu sua reputação (-12).');
    }
    final g = goal;
    if (g != null) {
      g.achieved = finalPosition <= g.targetPosition;
      if (g.achieved) {
        userTeam.finances.credit('Bônus meta da diretoria', g.bonusMi, 38);
        reputation = (reputation + 5).clamp(0, 100).toInt();
        msgs.add('✅ Meta cumprida (${g.description})! Bônus de R\$ ${g.bonusMi.toStringAsFixed(0)}mi e renovação automática.');
      } else {
        reputation = (reputation - 6).clamp(0, 100).toInt();
        msgs.add('❌ Meta não atingida (${g.description}). Diretoria insatisfeita (-6 reputação).');
      }
    }
    // Nova meta para a próxima temporada (compatível com Dart >=3.0)
    final String newDesc;
    final int newTarget;
    if (finalPosition == 1) {
      newDesc = 'Defender o título';
      newTarget = 1;
    } else if (finalPosition <= 4) {
      newDesc = 'Manter o clube no G4';
      newTarget = 4;
    } else if (finalPosition <= 10) {
      newDesc = 'Brigar por vaga em copa continental (top 8)';
      newTarget = 8;
    } else if (finalPosition <= 16) {
      newDesc = 'Ficar longe do Z4';
      newTarget = 16;
    } else {
      newDesc = 'Não cair de novo';
      newTarget = 16;
    }
    goal = BoardGoal(
      description: newDesc,
      targetPosition: newTarget,
      bonusMi: 5.0 + userTeam.stars * 2.5,
    );
    log.addAll(msgs);
    return msgs.join('\n');
  }

  /// Convites de trabalho quando o técnico está desempregado.
  List<CoachJobOffer> jobOffers(List<Team> teams, String? currentTeamId) {
    if (!unemployed) return const [];
    final offers = <CoachJobOffer>[];
    for (final t in teams) {
      if (t.id == currentTeamId) continue;
      // clubes grandes só contratam técnicos renomados
      final minRep = (t.stars - 2) * 22;
      if (reputation < minRep) continue;
      if (offers.length >= 4) break;
      final salary = 1.0 + t.stars * 1.4 + reputation / 40.0;
      offers.add(CoachJobOffer(t.id, t.name, t.stars,
          double.parse(salary.toStringAsFixed(1))));
    }
    return offers;
  }

  /// Aceita um convite: assume novo clube (mantém calendário da temporada).
  void acceptOffer(CoachJobOffer offer, Team newTeam) {
    unemployed = false;
    fired = false;
    coachSalary = offer.salaryMi;
    goal = goalForTeam(newTeam, reputation);
    reputation = (reputation + 2).clamp(0, 100).toInt();
    log.add('Acertou com o ${offer.teamName} por R\$ ${offer.salaryMi}mi/temporada.');
  }

  Map<String, dynamic> toJson() => {
        'reputation': reputation,
        'titles': titles,
        'coachSalary': coachSalary,
        'goal': goal?.toJson(),
        'fired': fired,
        'unemployed': unemployed,
        'log': log,
      };

  factory CareerManager.fromJson(Map<String, dynamic> j) => CareerManager()
    ..reputation = j['reputation'] ?? 50
    ..titles = j['titles'] ?? 0
    ..coachSalary = (j['coachSalary'] ?? 2.0).toDouble()
    ..goal = j['goal'] == null ? null : BoardGoal.fromJson(j['goal'])
    ..fired = j['fired'] ?? false
    ..unemployed = j['unemployed'] ?? false
    ..log = List<String>.from(j['log'] ?? []);
}

/// Interface mínima para o CareerManager avaliar risco sem acoplar ao engine
/// (facilita testes unitários).
abstract class GameStateProxy {
  int get userPosition;
  double get ppg;
  int get lossStreak;
  String get teamName;
  double rngDouble();
}
