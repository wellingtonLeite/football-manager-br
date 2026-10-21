import 'dart:math';

enum Tactic { retranca, neutro, ofensivo, tudoOuNada }
enum FanMood { apoio, neutro, protesto }
enum PressMood { positivo, neutro, critico }

/// Meta definida pela diretoria para a temporada (Fase 10A).
enum BoardGoal {
  titulo('Ser campeão brasileiro', 1, 2.1),
  g4('Terminar no G4 (Libertadores)', 4, 1.8),
  top8('Terminar entre os 8 primeiros', 8, 1.5),
  naoCair('Não ser rebaixado', 16, 1.1);

  const BoardGoal(this.label, this.maxPosition, this.expectedPpg);
  final String label;
  final int maxPosition;
  final double expectedPpg;
}

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

  // Fase 8/9: contrato e mercado
  int wage;
  int contractYears;
  int releaseClause;
  bool listed;
  int askingPrice;
  String? loanFromTeamId;

  // Departamento médico
  int injuredRounds;

  Player({
    required this.id,
    required this.name,
    required this.position,
    required this.age,
    required this.overall,
    this.xp = 0,
    this.energy = 100,
    this.morale = 70,
    int? wage,
    this.contractYears = 2,
    int? releaseClause,
    this.listed = false,
    this.askingPrice = 0,
    this.loanFromTeamId,
    this.injuredRounds = 0,
  })  : wage = wage ?? fairWage(overall, age),
        releaseClause = releaseClause ?? valueOf(overall, age) * 2;

  static const int xpToNext = 60;

  /// Salário mensal "de mercado" (R$) para um atleta com esse overall/idade.
  static int fairWage(int overall, int age) {
    double w = 80000 * exp(0.1466 * (overall - 65));
    if (age <= 20) {
      w *= 0.5;
    } else if (age <= 23) {
      w *= 0.75;
    }
    final rounded = (w / 1000).round() * 1000;
    return max(15000, rounded);
  }

  /// Valor de mercado (R$) para um atleta com esse overall/idade.
  static int valueOf(int overall, int age) {
    double v = 1500000 * exp(0.2 * (overall - 70));
    if (age <= 20) {
      v *= 1.6;
    } else if (age <= 23) {
      v *= 1.4;
    } else if (age <= 27) {
      v *= 1.15;
    } else if (age <= 30) {
      v *= 1.0;
    } else if (age <= 32) {
      v *= 0.7;
    } else if (age <= 34) {
      v *= 0.45;
    } else {
      v *= 0.25;
    }
    final rounded = (v / 50000).round() * 50000;
    return max(100000, rounded);
  }

  int get marketValue => valueOf(overall, age);

  bool get injured => injuredRounds > 0;

  bool get onLoan => loanFromTeamId != null;

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
    'wage': wage,
    'contractYears': contractYears,
    'releaseClause': releaseClause,
    'listed': listed,
    'askingPrice': askingPrice,
    'loanFromTeamId': loanFromTeamId,
    'injuredRounds': injuredRounds,
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
    wage: json['wage'],
    contractYears: json['contractYears'] ?? 2,
    releaseClause: json['releaseClause'],
    listed: json['listed'] ?? false,
    askingPrice: json['askingPrice'] ?? 0,
    loanFromTeamId: json['loanFromTeamId'],
    injuredRounds: json['injuredRounds'] ?? 0,
  );
}

class Team {
  final String id;
  final String name;
  final String shortName;
  final String state;
  final String stadium;
  String coach;
  final int stars;
  final int baseOverall;
  final List<Player> squad;

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

  // Fase 8: finanças e estrutura
  int capacity;
  int balance = 0;
  int sponsorMonthly = 0;
  int sponsorRenegotiatedSeason = 0;
  int ctLevel = 0;
  int stadiumLevel = 0;
  int medicalLevel = 0;

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
    this.capacity = 30000,
  });

  int get goalDifference => goalsFor - goalsAgainst;

  Player playerById(String id) => squad.firstWhere((p) => p.id == id);

  Player? findPlayer(String id) {
    for (final p in squad) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Player> get startingPlayers => [
    for (final id in startingIds) ?findPlayer(id),
  ];

  int get payroll => squad.fold<int>(0, (s, p) => s + p.wage);

  double get averageOverall => squad.isEmpty
      ? baseOverall.toDouble()
      : squad.fold<int>(0, (s, p) => s + p.overall) / squad.length;

  int get effectiveCapacity => (capacity * (1 + 0.15 * stadiumLevel)).round();

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
    'capacity': capacity,
    'balance': balance,
    'sponsorMonthly': sponsorMonthly,
    'sponsorRenegotiatedSeason': sponsorRenegotiatedSeason,
    'ctLevel': ctLevel,
    'stadiumLevel': stadiumLevel,
    'medicalLevel': medicalLevel,
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
      squad: (json['squad'] as List).map((p) => Player.fromJson(p as Map<String, dynamic>)).toList(),
      capacity: json['capacity'] ?? 30000,
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
    t.balance = json['balance'] ?? 0;
    t.sponsorMonthly = json['sponsorMonthly'] ?? 0;
    t.sponsorRenegotiatedSeason = json['sponsorRenegotiatedSeason'] ?? 0;
    t.ctLevel = json['ctLevel'] ?? 0;
    t.stadiumLevel = json['stadiumLevel'] ?? 0;
    t.medicalLevel = json['medicalLevel'] ?? 0;
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

/// Lançamento no extrato financeiro do clube do usuário (Fase 8).
class FinanceEntry {
  final int season;
  final int round;
  final String category;
  final String description;
  final int amount;

  FinanceEntry({
    required this.season,
    required this.round,
    required this.category,
    required this.description,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
    'season': season,
    'round': round,
    'category': category,
    'description': description,
    'amount': amount,
  };

  factory FinanceEntry.fromJson(Map<String, dynamic> json) => FinanceEntry(
    season: json['season'],
    round: json['round'],
    category: json['category'],
    description: json['description'],
    amount: json['amount'],
  );
}

/// Proposta de um clube da IA por um jogador do usuário (Fase 9).
class TransferOffer {
  final String playerId;
  final String buyerId;
  final int amount;
  final int expiresRound;

  TransferOffer({
    required this.playerId,
    required this.buyerId,
    required this.amount,
    required this.expiresRound,
  });

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'buyerId': buyerId,
    'amount': amount,
    'expiresRound': expiresRound,
  };

  factory TransferOffer.fromJson(Map<String, dynamic> json) => TransferOffer(
    playerId: json['playerId'],
    buyerId: json['buyerId'],
    amount: json['amount'],
    expiresRound: json['expiresRound'],
  );
}

/// Resultado de uma negociação (compra, empréstimo, renovação...).
class TransferResult {
  final bool success;
  final String message;
  const TransferResult(this.success, this.message);
}

/// Convite de emprego para o técnico (Fase 10A).
class JobOffer {
  final String teamId;
  final int salary;
  final BoardGoal goal;

  JobOffer({required this.teamId, required this.salary, required this.goal});

  Map<String, dynamic> toJson() => {
    'teamId': teamId,
    'salary': salary,
    'goal': goal.name,
  };

  factory JobOffer.fromJson(Map<String, dynamic> json) => JobOffer(
    teamId: json['teamId'],
    salary: json['salary'],
    goal: BoardGoal.values.byName(json['goal']),
  );
}

/// Resumo de uma temporada encerrada (Palmarès / histórico).
class SeasonRecord {
  final int season;
  final String champion;
  final String runnerUp;
  final List<String> relegated;
  final String? userTeam;
  final int? userPosition;
  final int? userPoints;
  final String? goal;
  final bool? goalMet;

  SeasonRecord({
    required this.season,
    required this.champion,
    required this.runnerUp,
    required this.relegated,
    this.userTeam,
    this.userPosition,
    this.userPoints,
    this.goal,
    this.goalMet,
  });

  Map<String, dynamic> toJson() => {
    'season': season,
    'champion': champion,
    'runnerUp': runnerUp,
    'relegated': relegated,
    'userTeam': userTeam,
    'userPosition': userPosition,
    'userPoints': userPoints,
    'goal': goal,
    'goalMet': goalMet,
  };

  factory SeasonRecord.fromJson(Map<String, dynamic> json) => SeasonRecord(
    season: json['season'],
    champion: json['champion'],
    runnerUp: json['runnerUp'],
    relegated: List<String>.from(json['relegated'] ?? []),
    userTeam: json['userTeam'],
    userPosition: json['userPosition'],
    userPoints: json['userPoints'],
    goal: json['goal'],
    goalMet: json['goalMet'],
  );
}

class NewsItem {
  final int season;
  final int round;
  final String text;

  NewsItem({required this.season, required this.round, required this.text});

  Map<String, dynamic> toJson() => {'season': season, 'round': round, 'text': text};

  factory NewsItem.fromJson(Map<String, dynamic> json) =>
      NewsItem(season: json['season'], round: json['round'], text: json['text']);
}

/// Carreira do técnico controlado pelo usuário (Fase 10A).
class CoachCareer {
  String name;
  int reputation;
  int titles;
  int salary;
  int earnings;
  BoardGoal goal;
  int boardConfidence;
  bool employed;
  final List<JobOffer> offers;
  final List<String> log;

  CoachCareer({
    required this.name,
    this.reputation = 50,
    this.titles = 0,
    this.salary = 0,
    this.earnings = 0,
    this.goal = BoardGoal.naoCair,
    this.boardConfidence = 60,
    this.employed = true,
    List<JobOffer>? offers,
    List<String>? log,
  })  : offers = offers ?? [],
        log = log ?? [];

  Map<String, dynamic> toJson() => {
    'name': name,
    'reputation': reputation,
    'titles': titles,
    'salary': salary,
    'earnings': earnings,
    'goal': goal.name,
    'boardConfidence': boardConfidence,
    'employed': employed,
    'offers': offers.map((o) => o.toJson()).toList(),
    'log': log,
  };

  factory CoachCareer.fromJson(Map<String, dynamic> json) => CoachCareer(
    name: json['name'] ?? 'Treinador',
    reputation: json['reputation'] ?? 50,
    titles: json['titles'] ?? 0,
    salary: json['salary'] ?? 0,
    earnings: json['earnings'] ?? 0,
    goal: BoardGoal.values.byName(json['goal'] ?? 'naoCair'),
    boardConfidence: json['boardConfidence'] ?? 60,
    employed: json['employed'] ?? true,
    offers: (json['offers'] as List? ?? [])
        .map((o) => JobOffer.fromJson(o as Map<String, dynamic>))
        .toList(),
    log: List<String>.from(json['log'] ?? []),
  );
}
