import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'data.dart';
import 'economy.dart';

part 'engine_competitions.dart';
part 'engine_finance.dart';
part 'engine_market.dart';
part 'engine_career.dart';
part 'engine_president.dart';
part 'engine_player.dart';
part 'engine_stats.dart';
part 'engine_world.dart';
part 'engine_club.dart';
part 'engine_multi.dart';

class GameState extends ChangeNotifier {
  GameMode mode = GameMode.tecnico;
  List<Team> teams = [];
  List<Team> foreignTeams = [];
  List<Match> matches = [];
  int currentDay = 1;
  int totalDays = 0;
  int seasonYear = 2026;
  String? _userTeamId;

  /// Multiplayer local: técnicos humanos e o da vez (vazio no jogo solo).
  final List<HumanManager> humans = [];
  int activeHuman = 0;

  String? get userTeamId => humans.isEmpty ? _userTeamId : humans[activeHuman].teamId;

  set userTeamId(String? v) {
    if (humans.isEmpty) {
      _userTeamId = v;
    } else {
      humans[activeHuman].teamId = v;
    }
  }

  /// Algum técnico humano comanda este clube?
  bool isHumanTeam(String id) => humans.isEmpty ? id == _userTeamId : humans.any((h) => h.teamId == id);
  bool started = false;
  final Random _rng = Random();

  /// Tática escolhida na tela pré-jogo para a próxima partida.
  Tactic userTactic = Tactic.neutro;

  // Calendário e copas
  Map<String, int> stageDays = {};
  Map<String, List<String>> regionalGroups = {};
  Map<String, List<String>> cupEntrants = {};
  Map<String, int> pendingDivisions = {};
  final Set<String> _crowned = {};

  // Fases 8, 9 e 10
  CoachCareer _career = CoachCareer(name: 'Treinador');

  CoachCareer get career => humans.isEmpty ? _career : humans[activeHuman].career;

  set career(CoachCareer c) {
    if (humans.isEmpty) {
      _career = c;
    } else {
      humans[activeHuman].career = c;
    }
  }
  PresidentState? president;
  PlayerCareer? playerCareer;
  List<Player> freeAgents = [];
  List<TransferOffer> incomingOffers = [];
  List<FinanceEntry> ledger = [];
  List<NewsItem> news = [];
  List<SeasonRecord> history = [];

  // Estatísticas e recordes
  Map<String, PlayerStatLine> stats = {};
  Map<String, ClubRecord> clubRecords = {};
  List<String> bestOfRound = [];
  final List<(String, double)> _roundRatings = [];

  // Treino, comissão, base, olheiros, ingressos e sócios (do técnico da vez)
  ClubSettings _club = ClubSettings();
  ClubSettings get club => humans.isEmpty ? _club : humans[activeHuman].club;
  String get trainingFocus => club.trainingFocus;
  set trainingFocus(String v) => club.trainingFocus = v;
  String get trainingIntensity => club.trainingIntensity;
  set trainingIntensity(String v) => club.trainingIntensity = v;
  Map<String, int> get staff => club.staff;
  set staff(Map<String, int> v) => club.staff = v;
  List<Player> get academy => club.academy;
  set academy(List<Player> v) => club.academy = v;
  Set<String> get scouted => club.scouted;
  set scouted(Set<String> v) => club.scouted = v;
  String get scoutRegion => club.scoutRegion;
  set scoutRegion(String v) => club.scoutRegion = v;
  double get ticketMultiplier => club.ticketMultiplier;
  set ticketMultiplier(double v) => club.ticketMultiplier = v;
  int get memberPrice => club.memberPrice;
  set memberPrice(int v) => club.memberPrice = v;
  int get members => club.members;
  set members(int v) => club.members = v;

  // Mercado: opção de compra em empréstimos e cláusulas de venda futura
  Map<String, int> loanOptions = {};
  Map<String, (String, int)> sellOnClauses = {};

  // Seleção Brasileira, conquistas e dificuldade (0 fácil, 1 normal, 2 difícil)
  NationalTeamState? national;
  bool nationalOffer = false;
  Set<String> achievements = {};
  int difficulty = 1;

  static const String _saveKey = 'fmbr_save_v2';
  static const int maxSquadSize = 30;
  static const int minSquadSize = 18;
  static const int leagueRounds = 38;

  // Caches (desempenho em celulares mais simples)
  final Map<String, Team> _index = {};
  final Map<int, List<Match>> _byDay = {};
  final Map<String, List<Team>> _standingsCache = {};
  Timer? _saveTimer;

  // ---------------------------------------------------------------------------
  // Consultas básicas
  // ---------------------------------------------------------------------------

  List<Team> get allTeams => [...teams, ...foreignTeams];

  void _reindex() {
    _index
      ..clear()
      ..addEntries(allTeams.map((t) => MapEntry(t.id, t)));
    _byDay.clear();
    for (final m in matches) {
      (_byDay[m.day] ??= []).add(m);
    }
    _standingsCache.clear();
  }

  void _addMatches(Iterable<Match> list) {
    for (final m in list) {
      matches.add(m);
      (_byDay[m.day] ??= []).add(m);
    }
  }

  Team teamById(String id) => _index[id] ?? allTeams.firstWhere((t) => t.id == id);

  Team? get userTeam => userTeamId == null ? null : teamById(userTeamId!);

  int get userDivision => userTeam?.division ?? 1;

  /// Total de rodadas da liga (mantido por compatibilidade).
  int get totalRounds => leagueRounds;

  List<Team> standingsOf(int division) => standingsOfKey('BRA$division');

  /// Tabela de uma liga estrangeira ('ENG', 'ESP'...).
  List<Team> standingsOfLeague(String league) => standingsOfKey(league);

  List<Team> standingsOfKey(String key) {
    final cached = _standingsCache[key];
    if (cached != null) return cached;
    final s = allTeams.where((t) => t.leagueKey == key).toList();
    s.sort((a, b) {
      if (b.points != a.points) return b.points.compareTo(a.points);
      if (b.wins != a.wins) return b.wins.compareTo(a.wins);
      if (b.goalDifference != a.goalDifference) {
        return b.goalDifference.compareTo(a.goalDifference);
      }
      if (b.goalsFor != a.goalsFor) return b.goalsFor.compareTo(a.goalsFor);
      return a.name.compareTo(b.name);
    });
    return _standingsCache[key] = s;
  }

  /// Classificação da divisão do usuário (ou da Série A).
  List<Team> get standings => standingsOf(userTeam?.division ?? 1);

  Team get champion => standingsOf(1).first;

  int positionOf(String teamId) {
    final t = teamById(teamId);
    if (t.division == 4) return serieDRank(teamId);
    if (t.leagueKey.isEmpty) return 0;
    return standingsOfKey(t.leagueKey).indexOf(t) + 1;
  }

  int get userPosition => userTeamId == null ? 0 : positionOf(userTeamId!);

  bool get seasonFinished => currentDay > totalDays;

  List<Match> matchesOfDay(int day) => _byDay[day] ?? const [];

  List<Match> get dayMatches => matchesOfDay(currentDay);

  /// Compatibilidade com o código antigo: jogos da data atual.
  List<Match> get currentRoundMatches => dayMatches;

  bool get dayPlayed => dayMatches.every((m) => m.isPlayed);

  bool get currentRoundPlayed => dayPlayed;

  /// Rodada da liga disputada em [day], se houver.
  int? leagueRoundOfDay(int day) {
    for (final m in matchesOfDay(day)) {
      if (m.isLeague) return m.round;
    }
    return null;
  }

  int get leagueRoundsPlayed => userTeam?.played ?? standingsOf(1).first.played;

  Match? get userMatchCurrent {
    if (seasonFinished || userTeamId == null) return null;
    for (final m in dayMatches) {
      if (!m.isPlayed && m.involves(userTeamId!)) return m;
    }
    return null;
  }

  /// Próximo jogo do clube do usuário (hoje ou mais adiante).
  Match? get nextUserMatch {
    if (userTeamId == null) return null;
    for (int d = currentDay; d <= totalDays; d++) {
      for (final m in matchesOfDay(d)) {
        if (!m.isPlayed && m.involves(userTeamId!)) return m;
      }
    }
    return null;
  }

  /// O usuário escala e joga ao vivo apenas no Modo Técnico.
  bool get controlsTeam => mode == GameMode.tecnico;

  /// Técnico e presidente cuidam de finanças e mercado.
  bool get managesClub => mode != GameMode.jogador;

  // ---------------------------------------------------------------------------
  // Início de carreira
  // ---------------------------------------------------------------------------

  void _newWorld() {
    teams = createLeague();
    foreignTeams = createForeignTeams();
    seasonYear = 2026;
    currentDay = 1;
    started = true;
    freeAgents = generateFreeAgents(_rng, 40);
    incomingOffers = [];
    ledger = [];
    news = [];
    history = [];
    pendingDivisions = {};
    _crowned.clear();
    president = null;
    playerCareer = null;
    userTactic = Tactic.neutro;
    stats = {};
    clubRecords = {};
    bestOfRound = [];
    humans.clear();
    activeHuman = 0;
    _club = ClubSettings();
    loanOptions = {};
    sellOnClauses = {};
    national = null;
    nationalOffer = false;
    achievements = {};
    _reindex();
    for (final t in allTeams) {
      t.startingIds = autoLineup(t);
    }
    _buildSeason(first: true);
  }

  /// Modo Técnico.
  void startGame(String teamId, {String coachName = 'Treinador', int difficulty = 1}) {
    mode = GameMode.tecnico;
    _newWorld();
    this.difficulty = difficulty;
    userTeamId = teamId;
    final t = userTeam!;
    _applyDifficultyBudget(t);
    _refreshAcademy();
    final name = coachName.trim().isEmpty ? 'Treinador' : coachName.trim();
    final rep = startingReputation(t.stars);
    career = CoachCareer(
      name: name,
      reputation: rep,
      salary: coachSalary(t.stars, rep),
      goal: goalForTeam(t),
    );
    career.log.add('$seasonYear: assumiu o ${t.name}.');
    t.coach = name;
    _aiListPlayers();
    _addNews('👔 ${career.name} assume o ${t.name}. Meta: ${career.goal.labelFor(t.division)}.');
    _changed();
  }

  void _applyDifficultyBudget(Team t) {
    t.balance = (t.balance * const [1.5, 1.0, 0.7][difficulty.clamp(0, 2)]).round();
    members = expectedMembers(t);
  }

  // ---------------------------------------------------------------------------
  // Escalação
  // ---------------------------------------------------------------------------

  List<String> autoLineup(Team t) => _fillLineup(t, const []);

  /// Mantém os titulares de [keep] (se aptos) e completa até 11 respeitando
  /// as cotas por posição. Considera energia e ignora lesionados.
  List<String> _fillLineup(Team t, List<String> keep) {
    double score(Player p) => p.overall * (0.85 + 0.15 * p.energy / 100.0);
    final pool = t.squad.where((p) => !p.unavailable).toList()
      ..sort((a, b) => score(b).compareTo(score(a)));
    final ids = <String>[];
    final counts = <String, int>{};
    for (final id in keep) {
      final p = t.findPlayer(id);
      if (p == null || p.unavailable || ids.contains(id) || ids.length >= 11) continue;
      ids.add(id);
      pool.remove(p);
      counts[p.position] = (counts[p.position] ?? 0) + 1;
    }
    t.formation.quota.forEach((pos, n) {
      for (final p in pool.where((p) => p.position == pos).toList()) {
        if ((counts[pos] ?? 0) >= n || ids.length >= 11) break;
        ids.add(p.id);
        pool.remove(p);
        counts[pos] = (counts[pos] ?? 0) + 1;
      }
    });
    while (ids.length < 11 && pool.isNotEmpty) {
      final next = pool.firstWhere((p) => p.position != 'GOL', orElse: () => pool.first);
      ids.add(next.id);
      pool.remove(next);
    }
    return ids;
  }

  void _prepareLineups() {
    final playing = <String>{};
    for (final m in dayMatches) {
      playing
        ..add(m.homeId)
        ..add(m.awayId);
    }
    for (final id in playing) {
      final t = teamById(id);
      t.startingIds = (controlsTeam && isHumanTeam(t.id)) ? _fillLineup(t, t.startingIds) : autoLineup(t);
    }
  }

  /// Garante 11 titulares aptos para o usuário (chamado na tela pré-jogo).
  void ensureUserLineup() {
    final t = userTeam;
    if (t == null) return;
    t.startingIds = _fillLineup(t, t.startingIds);
  }

  /// Coloca/tira um jogador do time titular do usuário. Retorna uma mensagem
  /// de erro quando a troca não é possível.
  String? toggleStarter(String playerId) {
    final t = userTeam;
    if (t == null || !controlsTeam) return null;
    final p = t.findPlayer(playerId);
    if (p == null) return null;
    if (t.startingIds.contains(playerId)) {
      t.startingIds.remove(playerId);
    } else {
      if (p.injured) return '${p.name} está lesionado.';
      if (p.suspended > 0) return '${p.name} está suspenso.';
      if (t.startingIds.length >= 11) {
        final samePos = t.startingPlayers.where((s) => s.position == p.position).toList()
          ..sort((a, b) => a.overall.compareTo(b.overall));
        if (samePos.isEmpty) {
          return 'Escalação completa: tire um titular antes de colocar ${p.name}.';
        }
        final idx = t.startingIds.indexOf(samePos.first.id);
        t.startingIds[idx] = p.id;
      } else {
        t.startingIds.add(p.id);
      }
    }
    _changed();
    return null;
  }

  /// Troca direta titular ↔ reserva (tela pré-jogo).
  void swapStarter(String outId, String inId) {
    final t = userTeam;
    if (t == null) return;
    final idx = t.startingIds.indexOf(outId);
    if (idx < 0 || t.startingIds.contains(inId)) return;
    t.startingIds[idx] = inId;
    _changed();
  }

  void resetUserLineup() {
    final t = userTeam;
    if (t == null) return;
    t.startingIds = autoLineup(t);
    _changed();
  }

  void setUserTactic(Tactic t) {
    userTactic = t;
    notifyListeners();
  }

  /// Rodadas que o atleta ainda vai desfalcar (para exibição).
  int roundsOut(Player p) => max(0, p.injuredRounds - (dayPlayed ? 1 : 0));

  // ---------------------------------------------------------------------------
  // Jogos do dia
  // ---------------------------------------------------------------------------

  /// Simula todos os jogos da data, menos o do usuário no Modo Técnico
  /// (que é jogado ao vivo ou pelo botão de simulação rápida).
  void simulateOtherMatches() {
    _prepareLineups();
    for (final m in dayMatches) {
      if (m.isPlayed) continue;
      if (controlsTeam && (isHumanTeam(m.homeId) || isHumanTeam(m.awayId))) continue;
      _playSimulated(m);
    }
    _changed();
  }

  /// Joga a partida do usuário sem assistir (Modo Técnico).
  void simulateUserMatchQuick() {
    final m = userMatchCurrent;
    if (m == null) return;
    ensureUserLineup();
    _playSimulated(m, userTactic: userTactic);
    _changed();
  }

  void _playSimulated(Match m, {Tactic? userTactic}) {
    final home = teamById(m.homeId);
    final away = teamById(m.awayId);
    final ht = home.id == userTeamId && userTactic != null ? userTactic : Tactic.neutro;
    final at = away.id == userTeamId && userTactic != null ? userTactic : Tactic.neutro;
    final s = _simulateScore(home, away, neutral: _isNeutral(m), ht: ht, at: at);
    _recordResult(m, s[0], s[1], home.startingPlayers, away.startingPlayers, const [], const []);
  }

  bool _isNeutral(Match m) =>
      (m.stage == 'F' && m.leg == 0 && (m.comp == 'LIB' || m.comp == 'SUL' || m.comp == 'UCL')) ||
      m.comp == 'SUP' || m.comp == 'MUN';

  void _recordResult(
    Match m,
    int hg,
    int ag,
    List<Player> homeOn,
    List<Player> awayOn,
    List<String> homeScorers,
    List<String> awayScorers, {
    int? homePens,
    int? awayPens,
    bool live = false,
    List<String> yellowIds = const [],
    List<String> redIds = const [],
    List<String> assistIds = const [],
  }) {
    final home = teamById(m.homeId);
    final away = teamById(m.awayId);
    m.homeGoals = hg;
    m.awayGoals = ag;
    if (homePens != null && awayPens != null) {
      m.homePens = homePens;
      m.awayPens = awayPens;
    } else if (needsPenalties(m, hg, ag)) {
      final p = shootout(home, away);
      m.homePens = p.$1;
      m.awayPens = p.$2;
    }
    if (m.isLeague) _applyResult(home, away, hg, ag);
    _serveSuspensions(home, homeOn);
    _serveSuspensions(away, awayOn);
    final hs = homeScorers.isEmpty && hg > 0 ? _pickScorers(homeOn, hg) : homeScorers;
    final aws = awayScorers.isEmpty && ag > 0 ? _pickScorers(awayOn, ag) : awayScorers;
    final cards = live ? (yellowIds, redIds) : _randomCards(homeOn, awayOn);
    _applyCards(m, cards.$1, cards.$2);
    _recordStats(m, home, away, homeOn, awayOn, hg, ag, hs, aws, assistIds, cards.$1, cards.$2);
    final msgs = <String>[];
    msgs.addAll(_applyEffects(home, homeOn, hg, ag, hs));
    msgs.addAll(_applyEffects(away, awayOn, ag, hg, aws));
    _matchFinances(m, home, away, hg, ag);
    if (!live) {
      _randomInjury(home);
      _randomInjury(away);
    }
    if (mode == GameMode.jogador && playerCareer != null) _playerMatchReport(m, hg, ag);
    for (final id in [m.homeId, m.awayId]) {
      if (!isHumanTeam(id)) continue;
      final i = humans.isEmpty ? null : _humanIndexOf(id);
      void after() {
        final userHome = m.homeId == userTeamId;
        _afterUserMatch(m, userHome ? hg : ag, userHome ? ag : hg);
      }
      if (i == null) {
        after();
      } else {
        _withHuman(i, after);
      }
      if (controlsTeam && id == userTeamId) lastGrowthMsgs = msgs.where((s) => s.isNotEmpty).toList();
    }
  }

  /// Mensagens de evolução da última partida do usuário (pós-jogo).
  List<String> lastGrowthMsgs = [];

  List<String> finishUserMatch(
    int hg,
    int ag,
    List<Player> userOnPitch,
    List<String> userScorerIds,
    List<Player> aiOnPitch,
    List<String> aiScorerIds, {
    int? homePens,
    int? awayPens,
    List<String> yellowIds = const [],
    List<String> redIds = const [],
    List<String> assistIds = const [],
  }) {
    final m = userMatchCurrent;
    if (m == null) return const [];
    final userIsHome = m.homeId == userTeamId;
    lastGrowthMsgs = [];
    _recordResult(
      m,
      hg,
      ag,
      userIsHome ? userOnPitch : aiOnPitch,
      userIsHome ? aiOnPitch : userOnPitch,
      userIsHome ? userScorerIds : aiScorerIds,
      userIsHome ? aiScorerIds : userScorerIds,
      homePens: homePens,
      awayPens: awayPens,
      live: true,
      yellowIds: yellowIds,
      redIds: redIds,
      assistIds: assistIds,
    );
    _changed();
    return lastGrowthMsgs.where((s) => userTeam!.squad.any((p) => s.startsWith(p.name))).toList();
  }

  void _afterUserMatch(Match m, int gf, int ga) {
    final t = userTeam!;
    _updateFanMorale(t, gf, ga);
    _updatePressMorale(t, gf, ga);
    if (mode == GameMode.tecnico) _updateBoardConfidence(gf, ga);
    if (mode == GameMode.presidente) _presidentAfterMatch(gf, ga);
  }

  void _updateFanMorale(Team t, int gf, int ga) {
    final won = gf > ga;
    final drew = gf == ga;
    int change = 0;
    if (won) change = 10;
    if (drew) change = 2;
    if (!won && !drew) change = -8;
    if (gf >= 3) change += 5;
    if (ga >= 3) change -= 5;
    t.fanMorale = (t.fanMorale + change).clamp(0, 100).toInt();
  }

  void _updatePressMorale(Team t, int gf, int ga) {
    final won = gf > ga;
    final drew = gf == ga;
    int change = 0;
    if (won) change = 8;
    if (drew) change = 1;
    if (!won && !drew) change = -10;
    if (userPosition <= 4) change += 3;
    if (userPosition >= 17) change -= 5;
    t.pressMorale = (t.pressMorale + change).clamp(0, 100).toInt();
  }

  List<String> _applyEffects(
    Team t,
    List<Player> onPitch,
    int gf,
    int ga,
    List<String> scorerIds,
  ) {
    final won = gf > ga;
    final drew = gf == ga;
    final msgs = <String>[];
    for (final p in onPitch) {
      p.energy = (p.energy - 25).clamp(20, 100).toInt();
      p.morale = (p.morale + (won ? 6 : drew ? 1 : -6)).clamp(0, 100).toInt();
      int xp = 8 + (won ? 4 : 0);
      xp += 6 * scorerIds.where((id) => id == p.id).length;
      // CT: jovens evoluem mais rápido
      if (p.age <= 23) xp = (xp * (1 + 0.25 * t.ctLevel)).round();
      msgs.addAll(p.gainXp(xp));
    }
    return msgs;
  }

  // ---------------------------------------------------------------------------
  // Avanço de data e temporada
  // ---------------------------------------------------------------------------

  void advanceDay() {
    if (!dayPlayed || seasonFinished) return;
    final finished = currentDay;
    _crownChampions(finished);
    currentDay++;
    for (final t in allTeams) {
      final isUser = t.id == userTeamId;
      for (final p in t.squad) {
        p.energy = (p.energy + 15 + 5 * t.medicalLevel).clamp(0, 100).toInt();
        if (p.injuredRounds > 0) p.injuredRounds--;
        // Treino no CT para jovens que não foram titulares
        if (!t.isForeign && p.age <= 23 && !t.startingIds.contains(p.id)) {
          final msgs = p.gainXp(1 + t.ctLevel);
          if (isUser && managesClub) {
            for (final m in msgs) {
              _addNews('📈 Treino no CT: $m');
            }
          }
        }
      }
    }
    _computeBestOfRound(finished);
    if (finished % 6 == 0) _monthlyFinances(finished ~/ 6);
    _expireOffers();
    if (managesClub) _forEachHuman(_aiTransferActivity);
    _aiTransfers();
    _forEachHuman(_clubDaily);
    _nationalDaily(finished);
    switch (mode) {
      case GameMode.tecnico:
        _forEachHuman(() => _careerDaily(finished));
      case GameMode.presidente:
        _presidentDaily(finished);
      case GameMode.jogador:
        _playerDaily(finished);
    }
    if (seasonFinished) {
      _closeSeason();
    } else {
      _progressCompetitions(currentDay);
    }
    _checkAchievements();
    _changed();
  }

  /// Compatibilidade com o nome antigo.
  void advanceRound() => advanceDay();

  void startNewSeason() {
    seasonYear++;
    // Acesso e rebaixamento definidos no fim da temporada anterior
    pendingDivisions.forEach((id, div) {
      final t = _index[id];
      if (t != null) t.division = div;
    });
    pendingDivisions = {};
    for (final t in allTeams) {
      t.resetLeagueStats();
      t.fanMorale = 70;
      t.pressMorale = 70;
      for (final p in t.squad) {
        p.age++;
        if (p.age >= 34) {
          p.overall = (p.overall - 2).clamp(50, 94).toInt();
        } else if (p.age >= 32) {
          p.overall = (p.overall - 1).clamp(50, 94).toInt();
        }
        p.energy = 100;
        p.morale = 70;
        p.injuredRounds = 0;
        if (!t.isForeign) p.contractYears--;
      }
    }

    // Empréstimos voltam ao clube de origem
    for (final t in teams) {
      for (final p in t.squad.where((p) => p.onLoan).toList()) {
        final owner = _index[p.loanFromTeamId];
        if (owner == null) continue;
        t.squad.remove(p);
        p.loanFromTeamId = null;
        owner.squad.add(p);
        if (t.id == userTeamId) {
          _addNews('↩️ ${p.name} voltou ao ${owner.name} ao fim do empréstimo.');
        }
      }
    }

    final userPlayerId = playerCareer?.playerId;
    for (final t in allTeams) {
      final isUser = t.id == userTeamId && managesClub;
      final avg = t.averageOverall;
      for (final p in t.squad.toList()) {
        if (p.id == userPlayerId) {
          if (p.contractYears <= 0) p.contractYears = 2;
          continue;
        }
        if (p.age >= 38 || (p.age >= 35 && p.overall < 66)) {
          t.squad.remove(p);
          if (isUser) _addNews('👋 ${p.name} se aposentou aos ${p.age} anos.');
          continue;
        }
        if (t.isForeign || p.contractYears > 0) continue;
        if (!isUser && p.age < 33 && p.overall >= avg - 4) {
          p.contractYears = 1 + _rng.nextInt(3);
          p.wage = max(p.wage, Player.fairWage(p.overall, p.age));
          continue;
        }
        t.squad.remove(p);
        p.listed = false;
        p.askingPrice = 0;
        freeAgents.add(p);
        if (isUser) _addNews('📄 O contrato de ${p.name} terminou e ele deixou o clube.');
      }
      final targets = t.isForeign ? kForeignSquadTargets : kSquadTargets;
      final youth = t.isForeign ? 1 : 2;
      for (int i = 0; i < youth; i++) {
        final y = generateYouth(_rng, _neediestPosition(t, targets), t.baseOverall, 2 * t.ctLevel);
        t.squad.add(y);
        if (isUser) {
          _addNews('🌱 Promessa da base: ${y.name} (${y.position}, ${y.age} anos, overall ${y.overall}).');
        }
      }
      final minSize = t.isForeign ? 18 : minSquadSize;
      int promoted = 0;
      while (t.squad.length < minSize) {
        t.squad.add(generateYouth(_rng, _neediestPosition(t, targets), t.baseOverall, 2 * t.ctLevel));
        promoted++;
      }
      if (isUser && promoted > 0) {
        _addNews('🌱 A diretoria subiu $promoted jovem(ns) da base para completar o elenco.');
      }
      if (!isUser && !t.isForeign) {
        while (t.squad.length < 22 && freeAgents.isNotEmpty) {
          _aiSignFreeAgent(t);
        }
        for (final p in t.squad) {
          p.listed = false;
        }
      }
    }

    // Agentes livres envelhecem; a fila é renovada
    freeAgents.removeWhere((p) => p.age >= 36);
    for (final p in freeAgents) {
      p.age++;
    }
    if (freeAgents.length < 40) {
      freeAgents.addAll(generateFreeAgents(_rng, 40 - freeAgents.length));
    }
    if (freeAgents.length > 80) freeAgents = freeAgents.sublist(freeAgents.length - 80);

    _standingsCache.clear();
    stats = {};
    bestOfRound = [];
    _refreshAcademy();
    for (final t in foreignTeams) {
      if (t.league.isNotEmpty) t.balance = max(t.balance, foreignBudget(t.baseOverall, t.league));
    }
    for (final t in teams) {
      final pos = _lastPositions[t.id] ?? 10;
      t.sponsorMonthly = roundTo(baseSponsor(t.stars) * (1.0 + (10 - pos) * 0.02), 10000);
    }
    if (career.employed) career.offers.clear();
    incomingOffers.clear();
    ledger.removeWhere((e) => e.season < seasonYear - 1);
    _aiListPlayers();
    currentDay = 1;
    _buildSeason(first: false);
    for (final t in allTeams) {
      t.startingIds = (controlsTeam && isHumanTeam(t.id)) ? _fillLineup(t, t.startingIds) : autoLineup(t);
    }
    switch (mode) {
      case GameMode.tecnico:
        final u = userTeam;
        if (u != null) {
          _addNews('📅 Começa a temporada $seasonYear! Meta: ${career.goal.labelFor(u.division)}.');
        }
      case GameMode.presidente:
        _presidentSeasonStart();
      case GameMode.jogador:
        _playerSeasonStart();
    }
    _changed();
  }

  /// Posição final de cada clube na temporada que acabou (para patrocínios).
  Map<String, int> _lastPositions = {};

  // ---------------------------------------------------------------------------
  // Notícias e persistência
  // ---------------------------------------------------------------------------

  void _addNews(String text) {
    news.insert(0, NewsItem(season: seasonYear, round: min(currentDay, max(1, totalDays)), text: text));
    if (news.length > 80) news.removeRange(80, news.length);
  }

  void _notify() => notifyListeners();

  /// Notifica a interface e agenda o salvamento (agrupado para não travar).
  void _changed() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 1500), saveToDisk);
  }

  Map<String, dynamic> toJson() => {
    'version': 2,
    'mode': mode.name,
    'teams': teams.map((t) => t.toJson()).toList(),
    'foreignTeams': foreignTeams.map((t) => t.toJson()).toList(),
    'matches': matches.map((m) => m.toJson()).toList(),
    'currentDay': currentDay,
    'totalDays': totalDays,
    'seasonYear': seasonYear,
    'userTeamId': userTeamId,
    'started': started,
    'userTactic': userTactic.name,
    'stageDays': stageDays,
    'regionalGroups': regionalGroups,
    'cupEntrants': cupEntrants,
    'pendingDivisions': pendingDivisions,
    'crowned': _crowned.toList(),
    'lastPositions': _lastPositions,
    'career': career.toJson(),
    'president': president?.toJson(),
    'playerCareer': playerCareer?.toJson(),
    'freeAgents': freeAgents.map((p) => p.toJson()).toList(),
    'incomingOffers': incomingOffers.map((o) => o.toJson()).toList(),
    'ledger': ledger.map((e) => e.toJson()).toList(),
    'news': news.map((n) => n.toJson()).toList(),
    'history': history.map((h) => h.toJson()).toList(),
    'stats': stats.map((k, v) => MapEntry(k, v.toJson())),
    'clubRecords': clubRecords.map((k, v) => MapEntry(k, v.toJson())),
    'bestOfRound': bestOfRound,
    'club': _club.toJson(),
    'humans': humans.map((h) => h.toJson()).toList(),
    'activeHuman': activeHuman,
    'loanOptions': loanOptions,
    'sellOnClauses': sellOnClauses.map((k, v) => MapEntry(k, [v.$1, v.$2])),
    'national': national?.toJson(),
    'nationalOffer': nationalOffer,
    'achievements': achievements.toList(),
    'difficulty': difficulty,
  };

  static GameState fromJson(Map<String, dynamic> map) {
    final gs = GameState();
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        (map[key] as List? ?? []).map((e) => f(e as Map<String, dynamic>)).toList();
    Map<String, List<String>> listMap(String key) => (map[key] as Map? ?? {})
        .map((k, v) => MapEntry(k as String, List<String>.from(v as List)));

    gs.mode = GameMode.values.byName(map['mode'] ?? 'tecnico');
    gs.teams = list('teams', Team.fromJson);
    gs.foreignTeams = list('foreignTeams', Team.fromJson);
    gs.matches = list('matches', Match.fromJson);
    gs.currentDay = map['currentDay'] ?? 1;
    gs.totalDays = map['totalDays'] ?? 0;
    gs.seasonYear = map['seasonYear'] ?? 2026;
    gs.userTeamId = map['userTeamId'];
    gs.started = map['started'] ?? false;
    gs.userTactic = Tactic.values.byName(map['userTactic'] ?? 'neutro');
    gs.stageDays = Map<String, int>.from(map['stageDays'] ?? {});
    gs.regionalGroups = listMap('regionalGroups');
    gs.cupEntrants = listMap('cupEntrants');
    gs.pendingDivisions = Map<String, int>.from(map['pendingDivisions'] ?? {});
    gs._crowned.addAll(List<String>.from(map['crowned'] ?? []));
    gs._lastPositions = Map<String, int>.from(map['lastPositions'] ?? {});
    gs.career = CoachCareer.fromJson(map['career'] as Map<String, dynamic>? ?? {});
    if (map['president'] != null) {
      gs.president = PresidentState.fromJson(map['president'] as Map<String, dynamic>);
    }
    if (map['playerCareer'] != null) {
      gs.playerCareer = PlayerCareer.fromJson(map['playerCareer'] as Map<String, dynamic>);
    }
    gs.freeAgents = list('freeAgents', Player.fromJson);
    gs.incomingOffers = list('incomingOffers', TransferOffer.fromJson);
    gs.ledger = list('ledger', FinanceEntry.fromJson);
    gs.news = list('news', NewsItem.fromJson);
    gs.history = list('history', SeasonRecord.fromJson);
    gs.stats = (map['stats'] as Map? ?? {})
        .map((k, v) => MapEntry(k as String, PlayerStatLine.fromJson(v as Map<String, dynamic>)));
    gs.clubRecords = (map['clubRecords'] as Map? ?? {})
        .map((k, v) => MapEntry(k as String, ClubRecord.fromJson(v as Map<String, dynamic>)));
    gs.bestOfRound = List<String>.from(map['bestOfRound'] ?? []);
    if (map['club'] != null) gs._club = ClubSettings.fromJson(map['club'] as Map<String, dynamic>);
    gs.humans.addAll(list('humans', HumanManager.fromJson));
    gs.activeHuman = (map['activeHuman'] ?? 0).clamp(0, gs.humans.isEmpty ? 0 : gs.humans.length - 1);
    gs.loanOptions = Map<String, int>.from(map['loanOptions'] ?? {});
    gs.sellOnClauses = (map['sellOnClauses'] as Map? ?? {})
        .map((k, v) => MapEntry(k as String, ((v as List)[0] as String, v[1] as int)));
    if (map['national'] != null) gs.national = NationalTeamState.fromJson(map['national'] as Map<String, dynamic>);
    gs.nationalOffer = map['nationalOffer'] ?? false;
    gs.achievements = Set<String>.from(map['achievements'] ?? []);
    gs.difficulty = map['difficulty'] ?? 1;
    gs._reindex();
    return gs;
  }

  /// Espaço de save em uso (1 a 3).
  int slot = 1;

  static String _slotKey(int slot) => 'fmbr_save_v2_slot$slot';
  static String _metaKey(int slot) => 'fmbr_meta_slot$slot';
  static const String _lastSlotKey = 'fmbr_last_slot';
  static const int slotCount = 3;

  /// Resumo curto do save (mostrado na tela inicial sem carregar tudo).
  Map<String, dynamic> _meta() => {
    'mode': mode.name,
    'name': career.name,
    'club': userTeam?.name ?? 'sem clube',
    'season': seasonYear,
    'day': currentDay,
  };

  Future<void> saveToDisk() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!started) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      // A codificação (a parte mais pesada) roda fora da thread da interface
      final raw = await compute(jsonEncode, toJson());
      await prefs.setString(_slotKey(slot), raw);
      await prefs.setString(_metaKey(slot), jsonEncode(_meta()));
      await prefs.setInt(_lastSlotKey, slot);
    } catch (e) {
      debugPrint('Erro ao salvar: $e');
    }
  }

  /// Carrega o save do [slot] (ou o último usado).
  static Future<GameState?> loadFromDisk([int? slot]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Save antigo (antes dos espaços) vira o espaço 1
      final legacy = prefs.getString(_saveKey);
      if (legacy != null && prefs.getString(_slotKey(1)) == null) {
        await prefs.setString(_slotKey(1), legacy);
        await prefs.remove(_saveKey);
      }
      final s = slot ?? prefs.getInt(_lastSlotKey) ?? 1;
      final raw = prefs.getString(_slotKey(s));
      if (raw == null) return null;
      final gs = fromJson(jsonDecode(raw) as Map<String, dynamic>)..slot = s;
      if (prefs.getString(_metaKey(s)) == null) await prefs.setString(_metaKey(s), jsonEncode(gs._meta()));
      return gs;
    } catch (e) {
      debugPrint('Erro ao carregar: $e');
      return null;
    }
  }

  /// Resumo dos 3 espaços de save (null = vazio).
  static Future<List<Map<String, dynamic>?>> slotSummaries() async {
    final prefs = await SharedPreferences.getInstance();
    return [
      for (int s = 1; s <= slotCount; s++)
        if (prefs.getString(_metaKey(s)) case final m?) jsonDecode(m) as Map<String, dynamic> else null,
    ];
  }

  /// Troca este jogo pelo conteúdo do espaço [s] (vazio = jogo novo ainda não iniciado).
  Future<void> switchSlot(int s) async {
    await saveToDisk();
    final loaded = await loadFromDisk(s);
    _replaceWith(loaded ?? GameState());
    slot = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSlotKey, s);
    notifyListeners();
  }

  void _replaceWith(GameState o) {
    mode = o.mode;
    teams = o.teams;
    foreignTeams = o.foreignTeams;
    matches = o.matches;
    currentDay = o.currentDay;
    totalDays = o.totalDays;
    seasonYear = o.seasonYear;
    _userTeamId = o._userTeamId;
    started = o.started;
    userTactic = o.userTactic;
    stageDays = o.stageDays;
    regionalGroups = o.regionalGroups;
    cupEntrants = o.cupEntrants;
    pendingDivisions = o.pendingDivisions;
    _crowned
      ..clear()
      ..addAll(o._crowned);
    _lastPositions = o._lastPositions;
    _career = o._career;
    president = o.president;
    playerCareer = o.playerCareer;
    freeAgents = o.freeAgents;
    incomingOffers = o.incomingOffers;
    ledger = o.ledger;
    news = o.news;
    history = o.history;
    _replaceExtra(o);
    _reindex();
  }

  /// Copia campos acrescentados em versões novas (estatísticas, ligas etc.).
  void _replaceExtra(GameState o) {
    stats = o.stats;
    clubRecords = o.clubRecords;
    bestOfRound = o.bestOfRound;
    _club = o._club;
    humans
      ..clear()
      ..addAll(o.humans);
    activeHuman = o.activeHuman;
    loanOptions = o.loanOptions;
    sellOnClauses = o.sellOnClauses;
    national = o.national;
    nationalOffer = o.nationalOffer;
    achievements = o.achievements;
    difficulty = o.difficulty;
  }

  /// Texto do save para backup (arquivo compartilhado pelo usuário).
  String exportSave() => jsonEncode(toJson());

  /// Importa um backup para o espaço atual. Retorna false se o arquivo não for válido.
  Future<bool> importSave(String raw) async {
    try {
      final o = fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (!o.started || o.teams.isEmpty) return false;
      _replaceWith(o);
      await saveToDisk();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Backup inválido: $e');
      return false;
    }
  }

  Future<void> deleteSave() async {
    _saveTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_slotKey(slot));
    await prefs.remove(_metaKey(slot));
    await prefs.remove('fmbr_save_v1');
    final s = slot;
    _replaceWith(GameState());
    slot = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Coletiva de imprensa
  // ---------------------------------------------------------------------------

  List<PressConference> generatePressConference() {
    final t = userTeam;
    if (t == null || !controlsTeam) return const [];
    final pos = userPosition;
    final lastMatch = matches.where((m) => m.isPlayed && m.involves(t.id)).lastOrNull;
    if (lastMatch == null) return const [];
    final userIsHome = lastMatch.homeId == t.id;
    final gf = userIsHome ? lastMatch.homeGoals! : lastMatch.awayGoals!;
    final ga = userIsHome ? lastMatch.awayGoals! : lastMatch.homeGoals!;
    final won = gf > ga;
    final drew = gf == ga;

    final questions = <PressConference>[];

    if (won) {
      questions.add(PressConference(
        question: 'Vitória importante! Como avalia a atuação da equipe?',
        answers: [
          'Fomos superiores do início ao fim, merecemos a vitória.',
          'Foi uma partida difícil, mas o time mostrou caráter.',
          'Precisamos melhorar, não jogamos bem.',
        ],
        correctIndex: 0,
        correctFeedback: 'Imprensa satisfeita com sua confiança! (+5 moral)',
        wrongFeedback: 'Imprensa estranha sua modéstia. (-3 moral)',
      ));
    } else if (drew) {
      questions.add(PressConference(
        question: userIsHome
            ? 'Empate em casa. O que faltou para vencer?'
            : 'Empate fora de casa. O resultado foi bom?',
        answers: [
          'Faltou eficiência no ataque, criamos chances mas não convertemos.',
          'O adversário jogou muito bem, parabéns a eles.',
          'Foi um resultado justo, aceitável.',
        ],
        correctIndex: 0,
        correctFeedback: 'Análise técnica respeitada. (+3 moral)',
        wrongFeedback: 'Imprensa critica falta de autocrítica. (-4 moral)',
      ));
    } else {
      questions.add(PressConference(
        question: 'Derrota preocupante. Qual sua explicação?',
        answers: [
          'Assumo a responsabilidade. Precisamos trabalhar mais.',
          'A arbitragem prejudicou o time.',
          'Os jogadores não se empenharam.',
        ],
        correctIndex: 0,
        correctFeedback: 'Postura profissional elogiada. (+2 moral)',
        wrongFeedback: 'Desculpas não colam. Imprensa detona. (-8 moral)',
      ));
    }

    if (pos > 0 && pos <= 4) {
      questions.add(PressConference(
        question: 'Time no G4. Acha que briga pelo título?',
        answers: [
          'Estamos focados jogo a jogo, mas temos qualidade para isso.',
          'Sim, somos favoritos ao título.',
          'Não, nosso objetivo é só não cair.',
        ],
        correctIndex: 0,
        correctFeedback: 'Humildade e ambição: imprensa aprova. (+4 moral)',
        wrongFeedback: 'Arrogância ou falta de visão. (-5 moral)',
      ));
    } else if (pos >= 17) {
      questions.add(PressConference(
        question: 'Time na zona de rebaixamento. Há risco de queda?',
        answers: [
          'Sabemos da situação, mas confiamos na virada.',
          'Não, vamos escapar facilmente.',
          'Sim, o risco é real e grande.',
        ],
        correctIndex: 0,
        correctFeedback: 'Realismo e esperança. (+3 moral)',
        wrongFeedback: 'Negação ou pessimismo. Imprensa pressiona. (-6 moral)',
      ));
    }

    if (t.fanMorale <= 40) {
      questions.add(PressConference(
        question: 'Torcida protestando. Como lida com a pressão?',
        answers: [
          'Entendo a frustração. Precisamos dar alegrias a eles.',
          'A torcida tem que apoiar sempre, não só quando vence.',
          'Não me importo com protestos.',
        ],
        correctIndex: 0,
        correctFeedback: 'Empatia com torcida. (+5 moral da torcida)',
        wrongFeedback: 'Desrespeito com torcida. (-10 moral da torcida)',
      ));
    }

    return questions;
  }

  void applyPressAnswer(int questionIndex, int answerIndex) {
    final t = userTeam;
    if (t == null) return;
    final questions = generatePressConference();
    if (questionIndex >= questions.length) return;
    final q = questions[questionIndex];
    if (answerIndex == q.correctIndex) {
      t.pressMorale = (t.pressMorale + 5).clamp(0, 100).toInt();
      if (q.correctFeedback.contains('torcida')) {
        t.fanMorale = (t.fanMorale + 5).clamp(0, 100).toInt();
      }
    } else {
      final penalty = q.wrongFeedback.contains('10') ? 10 :
                      q.wrongFeedback.contains('8') ? 8 :
                      q.wrongFeedback.contains('6') ? 6 :
                      q.wrongFeedback.contains('5') ? 5 :
                      q.wrongFeedback.contains('4') ? 4 : 3;
      if (q.wrongFeedback.contains('torcida')) {
        t.fanMorale = (t.fanMorale - penalty).clamp(0, 100).toInt();
      } else {
        t.pressMorale = (t.pressMorale - penalty).clamp(0, 100).toInt();
      }
    }
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Simulação
  // ---------------------------------------------------------------------------

  List<double> _tacticMods(Tactic t) {
    switch (t) {
      case Tactic.retranca: return [-0.45, -0.35];
      case Tactic.neutro: return [0.0, 0.0];
      case Tactic.ofensivo: return [0.35, 0.15];
      case Tactic.tudoOuNada: return [0.70, 0.45];
    }
  }

  List<double> lambdasFrom(double hs, double aws, Tactic ht, Tactic at,
      {Formation hf = Formation.f442, Formation af = Formation.f442, double homeTrain = 0, double awayTrain = 0}) {
    final diff = hs - aws;
    final mh = _tacticMods(ht);
    final ma = _tacticMods(at);
    final lh = (1.45 + diff / 18.0 + mh[0] + ma[1] + hf.attack + af.concede + homeTrain).clamp(0.25, 4.5).toDouble();
    final la = (1.15 - diff / 18.0 + ma[0] + mh[1] + af.attack + hf.concede + awayTrain).clamp(0.25, 4.5).toDouble();
    return [lh, la];
  }

  /// Bônus do mando de campo: torcida empolgada empurra mais (Fase 6).
  double homeAdvantage(Team t) => 2.0 + 4.0 * t.fanMorale / 100.0;

  /// Influência do técnico na força do time.
  double coachBonus(Team t) {
    if (mode == GameMode.tecnico && t.id == userTeamId) return (career.reputation - 50) / 25.0;
    return (t.coachRating - 3) * 0.8;
  }

  /// Força em campo já com o técnico (usada na simulação e no jogo ao vivo).
  double teamStrength(Team t, List<Player> onPitch) =>
      t.pitchStrength(onPitch) + coachBonus(t) + staffBonus(t) - (11 - onPitch.length).clamp(0, 11) * 3.0;

  List<int> _simulateScore(Team home, Team away,
      {bool neutral = false, Tactic ht = Tactic.neutro, Tactic at = Tactic.neutro}) {
    final hs = teamStrength(home, home.startingPlayers) + (neutral ? 0 : homeAdvantage(home));
    final aws = teamStrength(away, away.startingPlayers);
    final l = lambdasFrom(hs, aws, ht, at,
        hf: home.formation, af: away.formation, homeTrain: trainingAttack(home) - trainingDefense(away), awayTrain: trainingAttack(away) - trainingDefense(home));
    return [_poisson(l[0]), _poisson(l[1])];
  }

  int _poisson(double lambda) {
    final double limit = exp(-lambda);
    int k = 0;
    double p = 1.0;
    do {
      k++;
      p *= _rng.nextDouble();
    } while (p > limit);
    return k - 1;
  }

  /// Disputa de pênaltis (cobranças alternadas até 5, depois morte súbita).
  (int, int) shootout(Team home, Team away) {
    final ph = (0.72 + (teamStrength(home, home.startingPlayers) - 70) / 200).clamp(0.6, 0.85);
    final pa = (0.72 + (teamStrength(away, away.startingPlayers) - 70) / 200).clamp(0.6, 0.85);
    int h = 0, a = 0;
    for (int i = 0; i < 5; i++) {
      if (_rng.nextDouble() < ph) h++;
      if (_rng.nextDouble() < pa) a++;
    }
    while (h == a) {
      final sh = _rng.nextDouble() < ph;
      final sa = _rng.nextDouble() < pa;
      if (sh) h++;
      if (sa) a++;
    }
    return (h, a);
  }

  /// Duração (em datas, +1 da data atual) de uma lesão. O DM encurta.
  int rollInjury(Team t) => max(1, 1 + _rng.nextInt(4) - t.medicalLevel) + 1;

  void _randomInjury(Team t) {
    final starters = t.startingPlayers;
    if (starters.isEmpty) return;
    if (_rng.nextDouble() >= 0.12 * (1 - 0.2 * t.medicalLevel)) return;
    final p = starters[_rng.nextInt(starters.length)];
    p.injuredRounds = rollInjury(t);
    if (t.id == userTeamId) {
      _addNews('🚑 ${p.name} se lesionou e desfalca o time por ${p.injuredRounds - 1} jogo(s).');
    }
  }

  List<MatchEvent> generateChunk({
    required Match match,
    required int minFrom,
    required int minTo,
    required Tactic homeTactic,
    required Tactic awayTactic,
    required double homeStrength,
    required double awayStrength,
    required List<Player> homeOnPitch,
    required List<Player> awayOnPitch,
  }) {
    final home = teamById(match.homeId);
    final away = teamById(match.awayId);
    final l = lambdasFrom(homeStrength, awayStrength, homeTactic, awayTactic,
        hf: home.formation, af: away.formation, homeTrain: trainingAttack(home) - trainingDefense(away), awayTrain: trainingAttack(away) - trainingDefense(home));
    final events = <MatchEvent>[];
    if (homeOnPitch.isEmpty || awayOnPitch.isEmpty) return events;
    for (int min = minFrom; min < minTo; min++) {
      if (_rng.nextDouble() < l[0] / 90.0) {
        final s = pickScorer(homeOnPitch);
        events.add(MatchEvent(minute: min, type: 'GOAL', teamId: home.id, playerId: s.id, text: "⚽ GOL do ${home.name}! ${s.name} marca aos $min'!"));
      }
      if (_rng.nextDouble() < l[1] / 90.0) {
        final s = pickScorer(awayOnPitch);
        events.add(MatchEvent(minute: min, type: 'GOAL', teamId: away.id, playerId: s.id, text: "⚽ GOL do ${away.name}! ${s.name} marca aos $min'!"));
      }
      if (_rng.nextDouble() < 0.05) {
        final bool h = _rng.nextBool();
        final t = h ? home : away;
        final p = pickScorer(h ? homeOnPitch : awayOnPitch);
        events.add(MatchEvent(minute: min, type: 'CHANCE', teamId: t.id, playerId: p.id, text: "🔥 Chance do ${t.name}: ${p.name} finaliza e o goleiro salva!"));
      }
      if (_rng.nextDouble() < 0.012) {
        final bool h = _rng.nextBool();
        final t = h ? home : away;
        final list = h ? homeOnPitch : awayOnPitch;
        final p = list[_rng.nextInt(list.length)];
        events.add(MatchEvent(minute: min, type: 'CARD', teamId: t.id, playerId: p.id, text: "🟨 Cartão amarelo para ${p.name} (${t.name})."));
      }
      if (_rng.nextDouble() < 0.0012) {
        final bool h = _rng.nextBool();
        final t = h ? home : away;
        final list = h ? homeOnPitch : awayOnPitch;
        final p = list[_rng.nextInt(list.length)];
        events.add(MatchEvent(minute: min, type: 'RED', teamId: t.id, playerId: p.id, text: "🟥 EXPULSO! ${p.name} (${t.name}) recebe o vermelho direto."));
      }
      final bool hInj = _rng.nextBool();
      final injTeam = hInj ? home : away;
      if (_rng.nextDouble() < 0.0035 * (1 - 0.2 * injTeam.medicalLevel)) {
        final list = hInj ? homeOnPitch : awayOnPitch;
        final p = list[_rng.nextInt(list.length)];
        events.add(MatchEvent(minute: min, type: 'INJURY', teamId: injTeam.id, playerId: p.id, text: "🚑 ${p.name} (${injTeam.name}) sente lesão e não tem condições de seguir."));
      }
    }
    return events;
  }

  Player pickScorer(List<Player> onPitch) {
    final att = onPitch.where((p) => p.position == 'ATA' || p.position == 'MEI').toList();
    final pool = att.isEmpty ? List<Player>.from(onPitch) : att;
    pool.sort((a, b) => b.overall.compareTo(a.overall));
    final n = pool.length < 5 ? pool.length : 5;
    return pool[_rng.nextInt(n)];
  }

  void _applyResult(Team home, Team away, int hg, int ag) {
    _standingsCache.remove(home.leagueKey);
    _standingsCache.remove(away.leagueKey);
    home.played++;
    away.played++;
    home.goalsFor += hg;
    home.goalsAgainst += ag;
    away.goalsFor += ag;
    away.goalsAgainst += hg;
    if (hg > ag) {
      home.wins++;
      home.points += 3;
      away.losses++;
    } else if (hg < ag) {
      away.wins++;
      away.points += 3;
      home.losses++;
    } else {
      home.draws++;
      away.draws++;
      home.points++;
      away.points++;
    }
  }
}
