import 'dart:math';
import 'finances.dart';

enum Tactic { retranca, neutro, ofensivo, tudoOuNada }
enum FanMood { apoio, neutro, protesto }
enum PressMood { positivo, neutro, critico }

class MatchEvent {
  final int minute;
  final String type;
  final String teamId;
  final String? playerId;
  final String text;

  MatchEvent({
    required this.minute,
    required this.type,
    required this.teamId,
    this.playerId,
    required this.text,
  });
}

class Player {
  final String id;
  final String name;
  final String position;
  int age;
  int overall;
  int xp;
  int energy;
  int morale;

  // ---- Fase 8/9: Finanças e Mercado ----
  double salary; // salário em milhões (R$ mi) por temporada
  double value; // valor de mercado em milhões (R$ mi)
  int contractYears; // duração do contrato restante (temporadas)
  double releaseClause; // multa rescisória em milhões
  bool transferListed; // colocado na lista de transferências
  int loanSeasonsLeft; // >0 se está emprestado (temporadas restantes)
  String? loanParentClubId; // clube dono do passe se emprestado
  int goalsSeason; // gols na temporada atual (para propostas/estatísticas)

  Player({
    required this.id,
    required this.name,
    required this.position,
    required this.age,
    required this.overall,
    this.xp = 0,
    this.energy = 100,
    this.morale = 70,
    this.salary = 0.5,
    this.value = 2.0,
    this.contractYears = 2,
    this.releaseClause = 0,
    this.transferListed = false,
    this.loanSeasonsLeft = 0,
    this.loanParentClubId,
    this.goalsSeason = 0,
  });

  static const int xpToNext = 60;

  /// Estimativa de valor de mercado (R$ milhões).
  static double estimateValue(int overall, int age) {
    double base;
    if (overall >= 88) {
      base = 60.0;
    } else if (overall >= 84) {
      base = 35.0;
    } else if (overall >= 80) {
      base = 18.0;
    } else if (overall >= 76) {
      base = 9.0;
    } else if (overall >= 72) {
      base = 4.5;
    } else if (overall >= 68) {
      base = 2.0;
    } else {
      base = 0.8;
    }
    final ageFactor = age <= 21
        ? 1.3
        : age <= 26
            ? 1.15
            : age <= 30
                ? 1.0
                : age <= 33
                    ? 0.6
                    : 0.3;
    return double.parse((base * ageFactor).toStringAsFixed(1));
  }

  /// Salário anual estimado (R$ milhões).
  static double estimateSalary(int overall, int age) {
    final seniority = age >= 30 ? 1.2 : (age <= 22 ? 0.6 : 1.0);
    final raw = (overall - 55) / 10.0;
    final v = (raw <= 0 ? 0.1 : raw * raw * 0.9) * seniority;
    return double.parse(v.clamp(0.1, 12.0).toStringAsFixed(2));
  }

  /// Recalcula valor/salário/multa a partir de overall e idade atuais.
  void refreshMarketNumbers() {
    value = estimateValue(overall, age);
    salary = estimateSalary(overall, age);
    if (releaseClause == 0 || releaseClause < value) {
      releaseClause = double.parse((value * 3).toStringAsFixed(1));
    }
  }

  double get conditionedOverall {
    final fE = 0.85 + 0.15 * (energy / 100.0);
    final fM = 0.95 + 0.10 * (morale / 100.0);
    return overall * fE * fM;
  }

  List<String> gainXp(int amount) {
    xp += amount;
    final msgs = <String>[];
    final rng = Random();
    while (xp >= xpToNext) {
      xp -= xpToNext;
      int gain = 0;
      if (overall >= 94) {
        gain = 0;
      } else if (age <= 21) {
        gain = rng.nextDouble() < 0.8 ? 2 : 1;
      } else if (age <= 26) {
        gain = rng.nextDouble() < 0.7 ? 1 : 0;
      } else if (age <= 30) {
        gain = rng.nextDouble() < 0.35 ? 1 : 0;
      } else if (age <= 33) {
        gain = rng.nextDouble() < 0.15 ? 1 : 0;
      }
      if (gain > 0) {
        overall += gain;
        msgs.add('$name evoluiu para $overall de overall (+$gain)!');
      }
    }
    return msgs;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'position': position,
    'age': age,
    'overall': overall,
    'xp': xp,
    'energy': energy,
    'morale': morale,
    'salary': salary,
    'value': value,
    'contractYears': contractYears,
    'releaseClause': releaseClause,
    'transferListed': transferListed,
    'loanSeasonsLeft': loanSeasonsLeft,
    'loanParentClubId': loanParentClubId,
    'goalsSeason': goalsSeason,
  };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    id: json['id'],
    name: json['name'],
    position: json['position'],
    age: json['age'],
    overall: json['overall'],
    xp: json['xp'] ?? 0,
    energy: json['energy'] ?? 100,
    morale: json['morale'] ?? 70,
    salary: (json['salary'] ?? 0.5).toDouble(),
    value: (json['value'] ?? 2.0).toDouble(),
    contractYears: json['contractYears'] ?? 2,
    releaseClause: (json['releaseClause'] ?? 0.0).toDouble(),
    transferListed: json['transferListed'] ?? false,
    loanSeasonsLeft: json['loanSeasonsLeft'] ?? 0,
    loanParentClubId: json['loanParentClubId'],
    goalsSeason: json['goalsSeason'] ?? 0,
  );
}

class Team {
  final String id;
  final String name;
  final String shortName;
  final String state;
  final String stadium;
  final String coach;
  final int stars;
  final int baseOverall;
  final List<Player> squad;

  /// Capacidade do estádio (pode crescer com investimentos - Fase 8)
  int stadiumCapacity;

  ClubFinances finances = ClubFinances();

  List<String> startingIds = [];

  int points = 0;
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
  int played = 0;

  int fanMorale = 70;
  int pressMorale = 70;

  Team({
    required this.id,
    required this.name,
    required this.shortName,
    required this.state,
    required this.stadium,
    required this.coach,
    required this.stars,
    required this.baseOverall,
    required this.squad,
    this.stadiumCapacity = 30000,
  });

  int get goalDifference => goalsFor - goalsAgainst;

  /// Força salarial total do elenco (R$ mi / temporada) - Fase 8
  double get wageBill => squad.fold<double>(0, (s, p) => s + p.salary);

  /// Valor contábil do elenco (soma dos valores de mercado) - Fase 9
  double get squadMarketValue =>
      squad.fold<double>(0, (s, p) => s + p.value);

  Player playerById(String id) => squad.firstWhere((p) => p.id == id);

  List<Player> get startingPlayers =>
      startingIds.map((id) => playerById(id)).toList();

  double pitchStrength(List<Player> onPitch) {
    if (onPitch.isEmpty) return baseOverall.toDouble();
    final sum = onPitch.fold<double>(0, (s, p) => s + p.conditionedOverall);
    return sum / onPitch.length;
  }

  FanMood get fanMoodStatus {
    if (fanMorale >= 75) return FanMood.apoio;
    if (fanMorale <= 40) return FanMood.protesto;
    return FanMood.neutro;
  }

  PressMood get pressMoodStatus {
    if (pressMorale >= 75) return PressMood.positivo;
    if (pressMorale <= 40) return PressMood.critico;
    return PressMood.neutro;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'shortName': shortName,
    'state': state,
    'stadium': stadium,
    'coach': coach,
    'stars': stars,
    'baseOverall': baseOverall,
    'squad': squad.map((p) => p.toJson()).toList(),
    'startingIds': startingIds,
    'points': points,
    'wins': wins,
    'draws': draws,
    'losses': losses,
    'goalsFor': goalsFor,
    'goalsAgainst': goalsAgainst,
    'played': played,
    'fanMorale': fanMorale,
    'pressMorale': pressMorale,
    'stadiumCapacity': stadiumCapacity,
    'finances': finances.toJson(),
  };

  factory Team.fromJson(Map<String, dynamic> json) {
    final t = Team(
      id: json['id'],
      name: json['name'],
      shortName: json['shortName'],
      state: json['state'],
      stadium: json['stadium'],
      coach: json['coach'],
      stars: json['stars'],
      baseOverall: json['baseOverall'],
      squad: (json['squad'] as List).map((p) => Player.fromJson(p)).toList(),
      stadiumCapacity: json['stadiumCapacity'] ?? 30000,
    );
    t.startingIds = List<String>.from(json['startingIds'] ?? []);
    t.points = json['points'] ?? 0;
    t.wins = json['wins'] ?? 0;
    t.draws = json['draws'] ?? 0;
    t.losses = json['losses'] ?? 0;
    t.goalsFor = json['goalsFor'] ?? 0;
    t.goalsAgainst = json['goalsAgainst'] ?? 0;
    t.played = json['played'] ?? 0;
    t.fanMorale = json['fanMorale'] ?? 70;
    t.pressMorale = json['pressMorale'] ?? 70;
    if (json['finances'] != null) {
      t.finances = ClubFinances.fromJson(json['finances']);
    }
    return t;
  }
}

class Match {
  final int round;
  final String homeId;
  final String awayId;
  int? homeGoals;
  int? awayGoals;

  Match({required this.round, required this.homeId, required this.awayId});

  bool get isPlayed => homeGoals != null && awayGoals != null;

  Map<String, dynamic> toJson() => {
    'round': round,
    'homeId': homeId,
    'awayId': awayId,
    'homeGoals': homeGoals,
    'awayGoals': awayGoals,
  };

  factory Match.fromJson(Map<String, dynamic> json) => Match(
    round: json['round'],
    homeId: json['homeId'],
    awayId: json['awayId'],
  )..homeGoals = json['homeGoals']
   ..awayGoals = json['awayGoals'];
}

class PressConference {
  final String question;
  final List<String> answers;
  final int correctIndex;
  final String correctFeedback;
  final String wrongFeedback;

  PressConference({
    required this.question,
    required this.answers,
    required this.correctIndex,
    required this.correctFeedback,
    required this.wrongFeedback,
  });
}