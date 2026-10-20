class Player {
  final String id;
  final String name;
  final String position;
  final int age;
  final int overall;

  Player({
    required this.id,
    required this.name,
    required this.position,
    required this.age,
    required this.overall,
  });
}

class Team {
  final String id;
  final String name;
  final String shortName;
  final String state;
  final String stadium;
  final int stars;
  final int baseOverall;
  final List<Player> squad;

  int points = 0;
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
  int played = 0;

  Team({
    required this.id,
    required this.name,
    required this.shortName,
    required this.state,
    required this.stadium,
    required this.stars,
    required this.baseOverall,
    required this.squad,
  });

  int get goalDifference => goalsFor - goalsAgainst;

  int get strength {
    if (squad.isEmpty) return baseOverall;
    final sorted = List<Player>.from(squad)
      ..sort((a, b) => b.overall.compareTo(a.overall));
    final top = sorted.take(11);
    final sum = top.fold<int>(0, (s, p) => s + p.overall);
    return sum ~/ 11;
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
}
