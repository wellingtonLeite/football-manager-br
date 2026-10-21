import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'data.dart';

class GameState extends ChangeNotifier {
  List<Team> teams = [];
  List<Match> matches = [];
  int currentRound = 1;
  int seasonYear = 2026;
  String? userTeamId;
  bool started = false;
  final Random _rng = Random();

  int get totalRounds => teams.isEmpty ? 0 : (teams.length - 1) * 2;

  Team? get userTeam =>
      userTeamId == null ? null : teams.firstWhere((t) => t.id == userTeamId);

  Team get champion => standings.first;

  List<Team> get standings {
    final s = List<Team>.from(teams);
    s.sort((a, b) {
      if (b.points != a.points) return b.points.compareTo(a.points);
      if (b.wins != a.wins) return b.wins.compareTo(a.wins);
      if (b.goalDifference != a.goalDifference) {
        return b.goalDifference.compareTo(a.goalDifference);
      }
      if (b.goalsFor != a.goalsFor) return b.goalsFor.compareTo(a.goalsFor);
      return a.name.compareTo(b.name);
    });
    return s;
  }

  int get userPosition => standings.indexWhere((t) => t.id == userTeamId) + 1;

  bool get seasonFinished => currentRound > totalRounds;

  void startGame(String teamId) {
    teams = createLeague();
    for (final t in teams) {
      t.startingIds = autoLineup(t);
    }
    userTeamId = teamId;
    matches = _generateSchedule();
    currentRound = 1;
    seasonYear = 2026;
    started = true;
    notifyListeners();
  }

  List<String> autoLineup(Team t) {
    const quota = {'GOL': 1, 'ZAG': 2, 'LAT': 2, 'VOL': 2, 'MEI': 2, 'ATA': 2};
    final ids = <String>[];
    final pool = List<Player>.from(t.squad);
    quota.forEach((pos, n) {
      final cands = pool.where((p) => p.position == pos).toList()
        ..sort((a, b) => b.overall.compareTo(a.overall));
      for (int i = 0; i < n && i < cands.length; i++) {
        ids.add(cands[i].id);
        pool.remove(cands[i]);
      }
    });
    while (ids.length < 11 && pool.isNotEmpty) {
      pool.sort((a, b) => b.overall.compareTo(a.overall));
      ids.add(pool.removeAt(0).id);
    }
    return ids;
  }

  List<Match> get currentRoundMatches =>
      matches.where((m) => m.round == currentRound).toList();

  bool get currentRoundPlayed =>
      currentRoundMatches.isNotEmpty &&
      currentRoundMatches.every((m) => m.isPlayed);

  Match? get userMatchCurrent {
    if (seasonFinished) return null;
    final ms = currentRoundMatches
        .where((m) => m.homeId == userTeamId || m.awayId == userTeamId)
        .toList();
    return ms.isEmpty ? null : ms.first;
  }

  void simulateOtherMatches() {
    for (final m in currentRoundMatches) {
      if (m.isPlayed) continue;
      if (m.homeId == userTeamId || m.awayId == userTeamId) continue;
      final home = teams.firstWhere((t) => t.id == m.homeId);
      final away = teams.firstWhere((t) => t.id == m.awayId);
      final score = _simulateScore(home, away);
      m.homeGoals = score[0];
      m.awayGoals = score[1];
      _applyResult(home, away, score[0], score[1]);
      _applyEffects(home, home.startingPlayers, score[0], score[1], const []);
      _applyEffects(away, away.startingPlayers, score[1], score[0], const []);
    }
    notifyListeners();
  }

  List<String> finishUserMatch(
    int hg,
    int ag,
    List<Player> userOnPitch,
    List<String> userScorerIds,
    List<Player> aiOnPitch,
    List<String> aiScorerIds,
  ) {
    final m = userMatchCurrent;
    if (m == null) return const [];
    final userIsHome = m.homeId == userTeamId;
    final uTeam = userTeam!;
    final aTeam =
        teams.firstWhere((t) => t.id == (userIsHome ? m.awayId : m.homeId));
    final uGf = userIsHome ? hg : ag;
    final uGa = userIsHome ? ag : hg;
    final aGf = userIsHome ? ag : hg;
    final aGa = userIsHome ? hg : ag;
    final msgs = _applyEffects(uTeam, userOnPitch, uGf, uGa, userScorerIds);
    _applyEffects(aTeam, aiOnPitch, aGf, aGa, aiScorerIds);
    _updateFanMorale(uTeam, uGf, uGa);
    _updatePressMorale(uTeam, uGf, uGa);
    final homeTeam = teams.firstWhere((t) => t.id == m.homeId);
    final awayTeam = teams.firstWhere((t) => t.id == m.awayId);
    m.homeGoals = hg;
    m.awayGoals = ag;
    _applyResult(homeTeam, awayTeam, hg, ag);
    notifyListeners();
    return msgs;
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
      msgs.addAll(p.gainXp(xp));
    }
    return msgs;
  }

  void advanceRound() {
    if (!currentRoundPlayed || seasonFinished) return;
    currentRound++;
    for (final t in teams) {
      for (final p in t.squad) {
        p.energy = (p.energy + 15).clamp(0, 100).toInt();
      }
    }
    notifyListeners();
  }

  void startNewSeason() {
    seasonYear++;
    for (final t in teams) {
      t.points = 0;
      t.wins = 0;
      t.draws = 0;
      t.losses = 0;
      t.goalsFor = 0;
      t.goalsAgainst = 0;
      t.played = 0;
      t.fanMorale = 70;
      t.pressMorale = 70;
      for (final p in t.squad) {
        p.age++;
        if (p.age >= 34) {
          p.overall = (p.overall - 2).clamp(55, 94).toInt();
        } else if (p.age >= 32) {
          p.overall = (p.overall - 1).clamp(55, 94).toInt();
        }
        p.energy = 100;
        p.morale = 70;
      }
      t.startingIds = autoLineup(t);
    }
    matches = _generateSchedule();
    currentRound = 1;
    notifyListeners();
  }

  // ---------- TÁTICAS E FORÇA ----------

  List<double> _tacticMods(Tactic t) {
    switch (t) {
      case Tactic.retranca:
        return [-0.45, -0.35];
      case Tactic.neutro:
        return [0.0, 0.0];
      case Tactic.ofensivo:
        return [0.35, 0.15];
      case Tactic.tudoOuNada:
        return [0.70, 0.45];
    }
  }

  List<double> lambdasFrom(double hs, double as, Tactic ht, Tactic at) {
    final diff = hs - as;
    final mh = _tacticMods(ht);
    final ma = _tacticMods(at);
    final lh = (1.45 + diff / 18.0 + mh[0] + ma[1]).clamp(0.25, 4.5).toDouble();
    final la = (1.15 - diff / 18.0 + ma[0] + mh[1]).clamp(0.25, 4.5).toDouble();
    return [lh, la];
  }

  List<int> _simulateScore(Team home, Team away) {
    final hs = home.pitchStrength(home.startingPlayers) + 4.0;
    final as = away.pitchStrength(away.startingPlayers);
    final l = lambdasFrom(hs, as, Tactic.neutro, Tactic.neutro);
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

  // ---------- PARTIDA AO VIVO ----------

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
    final l =
        lambdasFrom(homeStrength, awayStrength, homeTactic, awayTactic);
    final home = teams.firstWhere((t) => t.id == match.homeId);
    final away = teams.firstWhere((t) => t.id == match.awayId);
    final events = <MatchEvent>[];
    for (int min = minFrom; min < minTo; min++) {
      if (_rng.nextDouble() < l[0] / 90.0) {
        final s = _pickScorer(homeOnPitch);
        events.add(MatchEvent(
          minute: min,
          type: 'GOAL',
          teamId: home.id,
          playerId: s.id,
          text: "⚽ GOL do ${home.name}! ${s.name} marca aos $min'!",
        ));
      }
      if (_rng.nextDouble() < l[1] / 90.0) {
        final s = _pickScorer(awayOnPitch);
        events.add(MatchEvent(
          minute: min,
          type: 'GOAL',
          teamId: away.id,
          playerId: s.id,
          text: "⚽ GOL do ${away.name}! ${s.name} marca aos $min'!",
        ));
      }
      if (_rng.nextDouble() < 0.05) {
        final bool h = _rng.nextBool();
        final t = h ? home : away;
        final p = _pickScorer(h ? homeOnPitch : awayOnPitch);
        events.add(MatchEvent(
          minute: min,
          type: 'CHANCE',
          teamId: t.id,
          playerId: p.id,
          text: "🔥 Chance do ${t.name}: ${p.name} finaliza e o goleiro salva!",
        ));
      }
      if (_rng.nextDouble() < 0.012) {
        final bool h = _rng.nextBool();
        final t = h ? home : away;
        final list = h ? homeOnPitch : awayOnPitch;
        final p = list[_rng.nextInt(list.length)];
        events.add(MatchEvent(
          minute: min,
          type: 'CARD',
          teamId: t.id,
          playerId: p.id,
          text: "🟨 Cartão amarelo para ${p.name} (${t.name}).",
        ));
      }
    }
    return events;
  }

  Player _pickScorer(List<Player> onPitch) {
    final att =
        onPitch.where((p) => p.position == 'ATA' || p.position == 'MEI').toList();
    final pool = att.isEmpty ? onPitch : att;
    pool.sort((a, b) => b.overall.compareTo(a.overall));
    final n = pool.length < 5 ? pool.length : 5;
    return pool[_rng.nextInt(n)];
  }

  // ---------- IMPRENSA ----------

  List<PressConference> generatePressConference() {
    final t = userTeam!;
    final pos = userPosition;
    final lastMatch = matches.lastWhere((m) =>
        m.isPlayed && (m.homeId == t.id || m.awayId == t.id));
    final userIsHome = lastMatch.homeId == t.id;
    final gf = userIsHome ? lastMatch.homeGoals! : lastMatch.awayGoals!;
    final ga = userIsHome ? lastMatch.awayGoals! : lastMatch.homeGoals!;
    final won = gf > ga;
    final drew = gf == ga;

    final questions = <PressConference>[];

    // Pergunta sobre desempenho
    if (won) {
      questions.add(PressConference(
        question: 'Vitória importante! Como avalia a atuação da equipe?',
        answers: [
          'Fomos superiores do início ao fim, merecemos os 3 pontos.',
          'Foi uma partida difícil, mas o time mostrou caráter.',
          'Precisamos melhorar, não jogamos bem.',
        ],
        correctIndex: 0,
        correctFeedback: 'Imprensa satisfeita com sua confiança! (+5 moral)',
        wrongFeedback: 'Imprensa estranha sua modéstia. (-3 moral)',
      ));
    } else if (drew) {
      questions.add(PressConference(
        question: 'Empate em casa. O que faltou para vencer?',
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

    // Pergunta sobre posição na tabela
    if (pos <= 4) {
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

    // Pergunta sobre torcida
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
    final t = userTeam!;
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
    notifyListeners();
  }

  // ---------- CALENDÁRIO ----------

  List<Match> _generateSchedule() {
    final ids = teams.map((t) => t.id).toList();
    final n = ids.length;
    final List<Match> result = [];
    List<String> rotating = ids.sublist(1);
    for (int round = 0; round < (n - 1) * 2; round++) {
      final roundIds = [ids[0], ...rotating];
      final firstHalf = round < n - 1;
      for (int i = 0; i < n ~/ 2; i++) {
        String a = roundIds[i];
        String b = roundIds[n - 1 - i];
        String home = firstHalf ? a : b;
        String away = firstHalf ? b : a;
        if (i.isOdd) {
          final tmp = home;
          home = away;
          away = tmp;
        }
        result.add(Match(round: round + 1, homeId: home, awayId: away));
      }
      rotating = [rotating.last, ...rotating.sublist(0, rotating.length - 1)];
    }
    return result;
  }

  void _applyResult(Team home, Team away, int hg, int ag) {
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