part of 'engine.dart';

/// Configurações do clube de um técnico humano: treino, comissão, base,
/// olheiros, ingressos e sócios.
class ClubSettings {
  String trainingFocus = 'equilibrado';
  String trainingIntensity = 'normal';
  Map<String, int> staff = {'auxiliar': 0, 'preparador': 0, 'olheiro': 0};
  List<Player> academy = [];
  Set<String> scouted = {};
  String scoutRegion = 'BRA';
  double ticketMultiplier = 1.0;
  int memberPrice = 40;
  int members = 0;

  Map<String, dynamic> toJson() => {
    'tf': trainingFocus,
    'ti': trainingIntensity,
    'st': staff,
    'ac': academy.map((p) => p.toJson()).toList(),
    'sc': scouted.toList(),
    'sr': scoutRegion,
    'tm': ticketMultiplier,
    'mp': memberPrice,
    'mb': members,
  };

  factory ClubSettings.fromJson(Map<String, dynamic> j) => ClubSettings()
    ..trainingFocus = j['tf'] ?? 'equilibrado'
    ..trainingIntensity = j['ti'] ?? 'normal'
    ..staff = Map<String, int>.from(j['st'] ?? {'auxiliar': 0, 'preparador': 0, 'olheiro': 0})
    ..academy = (j['ac'] as List? ?? []).map((p) => Player.fromJson(p as Map<String, dynamic>)).toList()
    ..scouted = Set<String>.from(j['sc'] ?? [])
    ..scoutRegion = j['sr'] ?? 'BRA'
    ..ticketMultiplier = (j['tm'] ?? 1.0).toDouble()
    ..memberPrice = j['mp'] ?? 40
    ..members = j['mb'] ?? 0;

  ClubSettings();
}

/// Técnico humano no multiplayer local (vários jogadores no mesmo celular).
class HumanManager {
  String? teamId;
  CoachCareer career;
  ClubSettings club;

  HumanManager({required this.teamId, required this.career, ClubSettings? club}) : club = club ?? ClubSettings();

  Map<String, dynamic> toJson() => {'team': teamId, 'career': career.toJson(), 'club': club.toJson()};

  factory HumanManager.fromJson(Map<String, dynamic> j) => HumanManager(
    teamId: j['team'],
    career: CoachCareer.fromJson(j['career'] as Map<String, dynamic>),
    club: ClubSettings.fromJson(j['club'] as Map<String, dynamic>? ?? {}),
  );
}

extension GameMulti on GameState {
  bool get isMultiplayer => humans.length > 1;

  /// Multiplayer local: 2 a 4 técnicos, cada um com seu clube (Modo Técnico).
  void startMultiplayer(List<(String, String)> players, {int difficulty = 1}) {
    mode = GameMode.tecnico;
    _newWorld();
    this.difficulty = difficulty;
    humans.clear();
    for (final (name, teamId) in players) {
      final t = teamById(teamId);
      final n = name.trim().isEmpty ? 'Técnico ${humans.length + 1}' : name.trim();
      final rep = startingReputation(t.stars);
      final c = CoachCareer(name: n, reputation: rep, salary: coachSalary(t.stars, rep), goal: goalForTeam(t));
      c.log.add('$seasonYear: assumiu o ${t.name}.');
      humans.add(HumanManager(teamId: teamId, career: c));
    }
    for (int i = 0; i < humans.length; i++) {
      activeHuman = i;
      final t = userTeam!;
      t.coach = career.name;
      _applyDifficultyBudget(t);
      _refreshAcademy();
      _addNews('👔 ${career.name} assume o ${t.name}.');
    }
    activeHuman = 0;
    _aiListPlayers();
    _changed();
  }

  /// Executa [f] como se o técnico [i] fosse o ativo (rotinas diárias e de temporada).
  void _withHuman(int i, void Function() f) {
    final prev = activeHuman;
    activeHuman = i;
    try {
      f();
    } finally {
      activeHuman = prev;
    }
  }

  /// Executa [f] para cada técnico humano (ou uma vez, no jogo solo).
  void _forEachHuman(void Function() f) {
    if (humans.isEmpty) {
      f();
      return;
    }
    for (int i = 0; i < humans.length; i++) {
      _withHuman(i, f);
    }
  }

  int? _humanIndexOf(String teamId) {
    for (int i = 0; i < humans.length; i++) {
      if (humans[i].teamId == teamId) return i;
    }
    return null;
  }

  /// Configurações do clube do técnico humano que comanda [t] (null = clube da IA).
  ClubSettings? _settingsFor(Team t) {
    if (humans.isEmpty) return managesClub && t.id == userTeamId ? _club : null;
    final i = _humanIndexOf(t.id);
    return i == null ? null : humans[i].club;
  }

  void setActiveHuman(int i) {
    if (i < 0 || i >= humans.length) return;
    activeHuman = i;
    _notify();
  }

  /// Técnicos com jogo pendente na data atual (para a vez de cada um).
  List<int> humansWithMatchToday() => [
    for (int i = 0; i < humans.length; i++)
      if (humans[i].teamId != null &&
          dayMatches.any((m) => !m.isPlayed && m.involves(humans[i].teamId!)))
        i,
  ];
}
