import 'dart:math';
import 'models.dart';

// Regras financeiras (Fase 8). Valores em reais.

const int kMaxFacilityLevel = 3;

enum Facility {
  ct('🏋️', 'Centro de Treinamento', 'Acelera a evolução dos jovens e melhora a base'),
  estadio('🏟️', 'Estádio', '+15% de capacidade (bilheteria) por nível'),
  medico('🏥', 'Departamento Médico', 'Menos lesões e recuperação de energia mais rápida');

  const Facility(this.emoji, this.label, this.effect);
  final String emoji;
  final String label;
  final String effect;

  int levelOf(Team t) {
    switch (this) {
      case Facility.ct:
        return t.ctLevel;
      case Facility.estadio:
        return t.stadiumLevel;
      case Facility.medico:
        return t.medicalLevel;
    }
  }

  void setLevel(Team t, int level) {
    switch (this) {
      case Facility.ct:
        t.ctLevel = level;
      case Facility.estadio:
        t.stadiumLevel = level;
      case Facility.medico:
        t.medicalLevel = level;
    }
  }
}

/// Custo para levar uma estrutura (CT, estádio, médico) ao [level] informado.
int facilityCost(int level) {
  switch (level) {
    case 1:
      return 15000000;
    case 2:
      return 30000000;
    default:
      return 60000000;
  }
}

int initialBudget(int stars) => const [1500000, 3000000, 6000000, 15000000, 40000000, 80000000][stars.clamp(0, 5)];

int baseSponsor(int stars) => const [300000, 500000, 1000000, 1500000, 4000000, 8000000][stars.clamp(0, 5)];

/// Cota mensal de direitos de TV (depende da divisão e, na Série A, do tamanho do clube).
int tvRights(Team t) {
  switch (t.division) {
    case 1:
      return t.stars >= 5 ? 15000000 : (t.stars == 4 ? 10000000 : 6000000);
    case 2:
      return 3000000;
    case 3:
      return 1000000;
    default:
      return 500000;
  }
}

/// Nível inicial das estruturas de clubes controlados pela IA.
int initialFacilityLevel(int stars) => stars >= 5 ? 2 : (stars == 4 ? 1 : 0);

int monthlyMaintenance(Team t) =>
    (t.division <= 1 ? 300000 : 60000) * (1 + t.ctLevel + t.stadiumLevel + t.medicalLevel);

int ticketPrice(Team t) => 30 + 12 * t.stars;

/// Público pagante de um jogo em casa.
int attendance(Team t, int position, {bool bigGame = false}) {
  double occ = 0.30 + t.fanMorale / 200.0 + 0.05 * t.stars;
  if (position > 0 && position <= 4) occ += 0.05;
  if (position >= 17) occ -= 0.05;
  if (bigGame) occ += 0.2;
  occ = occ.clamp(0.15, 1.0).toDouble();
  return (t.effectiveCapacity * occ).round();
}

/// Bicho por vitória/empate na liga, conforme a divisão.
int winBonus(int division) => const [0, 1000000, 300000, 100000, 50000][division.clamp(0, 4)];
int drawBonus(int division) => winBonus(division) ~/ 3;

const int kLibertadoresBonus = 15000000;
const int kSulAmericanaBonus = 6000000;

/// Bônus de acesso para os 4 primeiros das Séries B, C e D.
int promotionBonus(int division) => const [0, 0, 10000000, 3000000, 1000000][division.clamp(0, 4)];

/// Premiação pela posição final na liga.
int positionPrize(int position, {int division = 1}) {
  final f = (21 - position) / 20.0;
  final a = (4000000 + 46000000 * f * f).round();
  return a ~/ const [1, 1, 6, 20, 50][division.clamp(0, 4)];
}

/// Premiação por avançar de fase / conquistar uma copa.
int cupPrize(String comp, String stage, {bool champion = false}) {
  const cdb = {'R32': 1500000, 'R16': 2500000, 'QF': 4000000, 'SF': 8000000, 'F': 12000000};
  const lib = {'G': 6000000, 'R16': 4000000, 'QF': 5000000, 'SF': 7000000, 'F': 35000000};
  const sul = {'G': 2000000, 'R16': 1500000, 'QF': 2000000, 'SF': 3000000, 'F': 10000000};
  if (comp == 'CDB') return champion ? 30000000 : cdb[stage] ?? 0;
  if (comp == 'LIB') return champion ? 100000000 : lib[stage] ?? 0;
  if (comp == 'SUL') return champion ? 30000000 : sul[stage] ?? 0;
  return champion ? 2000000 : 0;
}

/// Salário mensal do técnico de um clube com [stars] estrelas.
int coachSalary(int stars, int reputation) {
  final base = const [40000, 80000, 180000, 400000, 800000, 1500000][stars.clamp(0, 5)];
  return ((base * (0.8 + reputation / 250.0)) / 10000).round() * 10000;
}

/// Reputação mínima para um clube convidar o técnico (Fase 10A).
int requiredReputation(int stars) => const [0, 0, 15, 30, 55, 75][stars.clamp(0, 5)];

/// Reputação inicial ao assumir um clube no começo da carreira.
int startingReputation(int stars) => 30 + stars * 6;

BoardGoal goalForStars(int stars) {
  if (stars >= 5) return BoardGoal.g4;
  if (stars == 4) return BoardGoal.top8;
  return BoardGoal.naoCair;
}

/// Meta da diretoria conforme o tamanho do clube e a divisão.
BoardGoal goalForTeam(Team t) {
  if (t.division <= 1) return goalForStars(t.stars);
  final big = t.stars >= 5 - t.division; // B: 3★, C: 2★, D: 1★
  return big ? BoardGoal.g4 : BoardGoal.top8;
}

String formatMoney(int value) {
  final neg = value < 0;
  final v = value.abs();
  String s;
  if (v >= 1000000) {
    final mi = v / 1000000.0;
    s = mi >= 100 ? '${mi.round()} mi' : '${mi.toStringAsFixed(1).replaceAll('.', ',')} mi';
  } else if (v >= 1000) {
    s = '${(v / 1000).round()} mil';
  } else {
    s = '$v';
  }
  return '${neg ? '-' : ''}R\$ $s';
}

/// Arredonda para um múltiplo de [step] (usado nos valores de negociação).
int roundTo(num value, int step) => max(step, (value / step).round() * step);
