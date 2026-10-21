import 'dart:math';

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

  Player({
    required this.id,
    required this.name,
    required this.position,
    required this.age,
    required this.overall,
    this.xp = 0,
    this.energy = 100,
    this.morale = 70,
  });

  static const int xpToNext = 60;

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
  });

  int get goalDifference => goalsFor - goalsAgainst;

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