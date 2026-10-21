import 'dart:math';

enum Tactic { retranca, neutro, ofensivo, tudoOuNada }

/// Esquema tático: quantos jogadores por posição e o efeito em ataque/defesa.
enum Formation {
  f442('4-4-2', {'GOL': 1, 'ZAG': 2, 'LAT': 2, 'VOL': 2, 'MEI': 2, 'ATA': 2}, 0.0, 0.0),
  f433('4-3-3', {'GOL': 1, 'ZAG': 2, 'LAT': 2, 'VOL': 1, 'MEI': 2, 'ATA': 3}, 0.12, 0.08),
  f451('4-5-1', {'GOL': 1, 'ZAG': 2, 'LAT': 2, 'VOL': 3, 'MEI': 2, 'ATA': 1}, -0.10, -0.10),
  f352('3-5-2', {'GOL': 1, 'ZAG': 3, 'LAT': 2, 'VOL': 1, 'MEI': 3, 'ATA': 2}, 0.06, 0.0),
  f343('3-4-3', {'GOL': 1, 'ZAG': 3, 'LAT': 2, 'VOL': 1, 'MEI': 1, 'ATA': 3}, 0.18, 0.15),
  f532('5-3-2', {'GOL': 1, 'ZAG': 3, 'LAT': 2, 'VOL': 2, 'MEI': 1, 'ATA': 2}, -0.12, -0.15);

  const Formation(this.label, this.quota, this.attack, this.concede);
  final String label;
  final Map<String, int> quota;

  /// Gols a mais que o time tende a fazer / a sofrer (somado ao λ de Poisson).
  final double attack;
  final double concede;
}
enum FanMood { apoio, neutro, protesto }
enum PressMood { positivo, neutro, critico }

/// Modo de carreira escolhido no início (Fase 10).
enum GameMode {
  tecnico('👔', 'Técnico', 'Escale, defina a tática e jogue as partidas ao vivo.'),
  presidente('🏛️', 'Presidente', 'Cuide do dinheiro, contrate técnicos e vença a eleição.'),
  jogador('⚽', 'Jogador', 'Crie um atleta e leve-o dos 17 aos 40 anos.');

  const GameMode(this.emoji, this.label, this.description);
  final String emoji;
  final String label;
  final String description;
}

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

  /// Texto da meta conforme a divisão (na Série B, G4 significa acesso).
  String labelFor(int division) {
    if (division <= 1) return label;
    final serie = 'Série ${'ABCD'[division - 1]}';
    switch (this) {
      case BoardGoal.titulo:
        return 'Ser campeão da $serie';
      case BoardGoal.g4:
        return 'Conquistar o acesso (G4 da $serie)';
      case BoardGoal.top8:
        return 'Terminar entre os 8 primeiros da $serie';
      case BoardGoal.naoCair:
        return division == 4 ? 'Terminar fora do Z4 da Série D' : 'Não ser rebaixado da $serie';
    }
  }
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
  String name;
  String position;
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

  // Disciplina e origem
  String nat;
  int yellowCards;
  int suspended;

  /// Teto de evolução (só o olheiro revela). 0 = não definido.
  int potential;

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
    this.nat = 'BRA',
    this.yellowCards = 0,
    this.suspended = 0,
    this.potential = 0,
  })  : wage = wage ?? fairWage(overall, age),
        releaseClause = releaseClause ?? valueOf(overall, age) * 2;

  static const int xpToNext = 60;

  /// Salário mensal "de mercado" (R$) para um atleta com esse overall/idade.
  static int fairWage(int overall, int age) {
    double w = 60000 * exp(0.18 * (overall - 65));
    if (age <= 20) {
      w *= 0.5;
    } else if (age <= 23) {
      w *= 0.75;
    }
    final rounded = (w / 1000).round() * 1000;
    return max(5000, rounded);
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

  /// Lesionado ou suspenso: não pode ser escalado.
  bool get unavailable => injuredRounds > 0 || suspended > 0;

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
      if (overall >= 94 || (potential > 0 && overall >= potential)) {
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

  /// Formato compacto (chaves curtas, valores padrão omitidos): o save fica bem menor.
  Map<String, dynamic> toJson() => {
    'i': id,
    'n': name,
    'p': position,
    'a': age,
    'o': overall,
    if (xp != 0) 'x': xp,
    if (energy != 100) 'e': energy,
    if (morale != 70) 'm': morale,
    'w': wage,
    'c': contractYears,
    'rc': releaseClause,
    if (listed) 'ls': true,
    if (askingPrice != 0) 'ap': askingPrice,
    if (loanFromTeamId != null) 'lo': loanFromTeamId,
    if (injuredRounds != 0) 'ij': injuredRounds,
    if (nat != 'BRA') 'nat': nat,
    if (yellowCards > 0) 'yc': yellowCards,
    if (suspended > 0) 'susp': suspended,
    if (potential > 0) 'pot': potential,
  };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    id: json['i'] ?? json['id'],
    name: json['n'] ?? json['name'],
    position: json['p'] ?? json['position'],
    age: json['a'] ?? json['age'],
    overall: json['o'] ?? json['overall'],
    xp: json['x'] ?? json['xp'] ?? 0,
    energy: json['e'] ?? json['energy'] ?? 100,
    morale: json['m'] ?? json['morale'] ?? 70,
    wage: json['w'] ?? json['wage'],
    contractYears: json['c'] ?? json['contractYears'] ?? 2,
    releaseClause: json['rc'] ?? json['releaseClause'],
    listed: json['ls'] ?? json['listed'] ?? false,
    askingPrice: json['ap'] ?? json['askingPrice'] ?? 0,
    loanFromTeamId: json['lo'] ?? json['loanFromTeamId'],
    injuredRounds: json['ij'] ?? json['injuredRounds'] ?? 0,
    nat: json['nat'] ?? 'BRA',
    yellowCards: json['yc'] ?? 0,
    suspended: json['susp'] ?? 0,
    potential: json['pot'] ?? 0,
  );
}

class Team {
  final String id;
  String name;
  final String shortName;
  final String state;
  String stadium;
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

  // Divisões, copas e técnicos
  /// 1 a 4 = Séries A a D; 0 = clube estrangeiro (só copas continentais).
  int division;
  final String country;
  int coachRating;
  int coachWage = 0;
  final List<String> trophies;

  /// Liga estrangeira ('ENG', 'ESP'...); vazio para brasileiros e clubes só de copa.
  String league;
  Formation formation = Formation.f442;

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
    this.division = 1,
    this.country = 'BRA',
    this.coachRating = 3,
    List<String>? trophies,
    this.league = '',
  }) : trophies = trophies ?? [];

  bool get isForeign => division == 0;

  /// Chave da liga para tabelas: 'BRA1'..'BRA4' ou o código da liga estrangeira.
  String get leagueKey => division > 0 ? 'BRA$division' : league;

  void resetLeagueStats() {
    points = 0;
    wins = 0;
    draws = 0;
    losses = 0;
    goalsFor = 0;
    goalsAgainst = 0;
    played = 0;
  }

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
    'division': division,
    'country': country,
    'coachRating': coachRating,
    'coachWage': coachWage,
    'trophies': trophies,
    if (league.isNotEmpty) 'league': league,
    'formation': formation.name,
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
      division: json['division'] ?? 1,
      country: json['country'] ?? 'BRA',
      coachRating: json['coachRating'] ?? 3,
      trophies: List<String>.from(json['trophies'] ?? []),
      league: json['league'] ?? '',
    );
    t.formation = Formation.values.byName(json['formation'] ?? 'f442');
    t.coachWage = json['coachWage'] ?? 0;
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
  /// Rodada da liga, jogo da fase de grupos ou posição no chaveamento (mata-mata).
  final int round;
  final String homeId;
  final String awayId;

  /// 'A'..'D' (Séries), 'CDB', 'LIB', 'SUL' ou `EST:<chave>` (estaduais/regionais).
  final String comp;

  /// Data do calendário da temporada em que o jogo acontece.
  final int day;

  /// 'L' liga, 'G' grupos, 'R32', 'R16', 'QF', 'SF', 'F'.
  final String stage;
  final String group;

  /// 0 jogo único, 1 ida, 2 volta.
  final int leg;

  int? homeGoals;
  int? awayGoals;
  int? homePens;
  int? awayPens;

  Match({
    required this.round,
    required this.homeId,
    required this.awayId,
    this.comp = 'A',
    this.day = 0,
    this.stage = 'L',
    this.group = '',
    this.leg = 0,
  });

  bool get isPlayed => homeGoals != null && awayGoals != null;

  bool get isLeague => stage == 'L';

  bool get isKnockout => stage != 'L' && stage != 'G';

  bool involves(String teamId) => homeId == teamId || awayId == teamId;

  Map<String, dynamic> toJson() => {
    'r': round,
    'h': homeId,
    'a': awayId,
    'c': comp,
    'd': day,
    if (stage != 'L') 's': stage,
    if (group.isNotEmpty) 'g': group,
    if (leg != 0) 'l': leg,
    if (homeGoals != null) 'hg': homeGoals,
    if (awayGoals != null) 'ag': awayGoals,
    if (homePens != null) 'hp': homePens,
    if (awayPens != null) 'apn': awayPens,
  };

  factory Match.fromJson(Map<String, dynamic> json) => Match(
    round: json['r'] ?? json['round'],
    homeId: json['h'] ?? json['homeId'],
    awayId: json['a'] ?? json['awayId'],
    comp: json['c'] ?? json['comp'] ?? 'A',
    day: json['d'] ?? json['day'] ?? json['round'],
    stage: json['s'] ?? json['stage'] ?? 'L',
    group: json['g'] ?? json['group'] ?? '',
    leg: json['l'] ?? json['leg'] ?? 0,
  )..homeGoals = json['hg'] ?? json['homeGoals']
   ..awayGoals = json['ag'] ?? json['awayGoals']
   ..homePens = json['hp'] ?? json['homePens']
   ..awayPens = json['apn'] ?? json['awayPens'];
}

/// Linha de uma tabela de grupo (estaduais e copas continentais).
class StandingRow {
  final Team team;
  int played = 0, wins = 0, draws = 0, losses = 0, goalsFor = 0, goalsAgainst = 0;

  StandingRow(this.team);

  int get points => wins * 3 + draws;
  int get goalDifference => goalsFor - goalsAgainst;
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
  final String teamId;
  final int season;
  final int round;
  final String category;
  final String description;
  final int amount;

  FinanceEntry({
    this.teamId = '',
    required this.season,
    required this.round,
    required this.category,
    required this.description,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
    if (teamId.isNotEmpty) 'teamId': teamId,
    'season': season,
    'round': round,
    'category': category,
    'description': description,
    'amount': amount,
  };

  factory FinanceEntry.fromJson(Map<String, dynamic> json) => FinanceEntry(
    teamId: json['teamId'] ?? '',
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

  /// Campeões de cada competição da temporada (nome da competição → clube).
  final Map<String, String> titles;

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
    Map<String, String>? titles,
  }) : titles = titles ?? {};

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
    'titles': titles,
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
    titles: Map<String, String>.from(json['titles'] ?? {}),
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
  final List<String> trophies = [];

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
    'trophies': trophies,
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
  )..trophies.addAll(List<String>.from(json['trophies'] ?? []));
}

/// Números do atleta do Modo Jogador em uma temporada (Fase 10C).
class PlayerSeasonStats {
  final int season;
  String team;
  int games = 0;
  int goals = 0;
  int assists = 0;
  double ratingSum = 0;

  PlayerSeasonStats({required this.season, required this.team});

  double get avgRating => games == 0 ? 0 : ratingSum / games;

  Map<String, dynamic> toJson() => {
    'season': season,
    'team': team,
    'games': games,
    'goals': goals,
    'assists': assists,
    'ratingSum': ratingSum,
  };

  factory PlayerSeasonStats.fromJson(Map<String, dynamic> json) =>
      PlayerSeasonStats(season: json['season'], team: json['team'])
        ..games = json['games'] ?? 0
        ..goals = json['goals'] ?? 0
        ..assists = json['assists'] ?? 0
        ..ratingSum = (json['ratingSum'] ?? 0).toDouble();
}

/// Carreira do atleta criado pelo usuário (Fase 10C).
class PlayerCareer {
  final String playerId;
  final String nationality;
  int caps;
  bool retired;
  int raiseSeason;
  bool transferRequested;
  double lastRating;
  final List<PlayerSeasonStats> seasons;

  PlayerCareer({
    required this.playerId,
    required this.nationality,
    this.caps = 0,
    this.retired = false,
    this.raiseSeason = 0,
    this.transferRequested = false,
    this.lastRating = 0,
    List<PlayerSeasonStats>? seasons,
  }) : seasons = seasons ?? [];

  int get totalGames => seasons.fold(0, (s, x) => s + x.games);
  int get totalGoals => seasons.fold(0, (s, x) => s + x.goals);
  int get totalAssists => seasons.fold(0, (s, x) => s + x.assists);

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'nationality': nationality,
    'caps': caps,
    'retired': retired,
    'raiseSeason': raiseSeason,
    'transferRequested': transferRequested,
    'lastRating': lastRating,
    'seasons': seasons.map((s) => s.toJson()).toList(),
  };

  factory PlayerCareer.fromJson(Map<String, dynamic> json) => PlayerCareer(
    playerId: json['playerId'],
    nationality: json['nationality'] ?? 'Brasil',
    caps: json['caps'] ?? 0,
    retired: json['retired'] ?? false,
    raiseSeason: json['raiseSeason'] ?? 0,
    transferRequested: json['transferRequested'] ?? false,
    lastRating: (json['lastRating'] ?? 0).toDouble(),
    seasons: (json['seasons'] as List? ?? [])
        .map((s) => PlayerSeasonStats.fromJson(s as Map<String, dynamic>))
        .toList(),
  );
}

/// Crise ou decisão estratégica que o presidente precisa responder (Fase 10B).
class CrisisEvent {
  final String kind;
  final String title;
  final String text;
  final List<String> options;

  CrisisEvent({required this.kind, required this.title, required this.text, required this.options});

  Map<String, dynamic> toJson() => {'kind': kind, 'title': title, 'text': text, 'options': options};

  factory CrisisEvent.fromJson(Map<String, dynamic> json) => CrisisEvent(
    kind: json['kind'],
    title: json['title'],
    text: json['text'],
    options: List<String>.from(json['options']),
  );
}

/// Mandato do presidente (Fase 10B).
class PresidentState {
  int popularity;
  int mandateStart;
  int mandateLength;
  final List<int> patrimonyHistory;
  final List<CrisisEvent> pending;
  int elections;

  /// Empréstimo a pagar no fim da temporada e temporada da promessa de reforço.
  int debt = 0;
  int promiseSeason = 0;

  PresidentState({
    this.popularity = 60,
    required this.mandateStart,
    this.mandateLength = 3,
    this.elections = 0,
    List<int>? patrimonyHistory,
    List<CrisisEvent>? pending,
  })  : patrimonyHistory = patrimonyHistory ?? [],
        pending = pending ?? [];

  int get mandateEnd => mandateStart + mandateLength - 1;

  Map<String, dynamic> toJson() => {
    'popularity': popularity,
    'mandateStart': mandateStart,
    'mandateLength': mandateLength,
    'elections': elections,
    'patrimonyHistory': patrimonyHistory,
    'pending': pending.map((e) => e.toJson()).toList(),
    'debt': debt,
    'promiseSeason': promiseSeason,
  };

  factory PresidentState.fromJson(Map<String, dynamic> json) => PresidentState(
    popularity: json['popularity'] ?? 60,
    mandateStart: json['mandateStart'],
    mandateLength: json['mandateLength'] ?? 3,
    elections: json['elections'] ?? 0,
    patrimonyHistory: List<int>.from(json['patrimonyHistory'] ?? []),
    pending: (json['pending'] as List? ?? [])
        .map((e) => CrisisEvent.fromJson(e as Map<String, dynamic>))
        .toList(),
  )
    ..debt = json['debt'] ?? 0
    ..promiseSeason = json['promiseSeason'] ?? 0;
}
