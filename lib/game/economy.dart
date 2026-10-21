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

int initialBudget(int stars) {
  switch (stars) {
    case 5:
      return 80000000;
    case 4:
      return 40000000;
    default:
      return 15000000;
  }
}

int baseSponsor(int stars) {
  switch (stars) {
    case 5:
      return 8000000;
    case 4:
      return 4000000;
    default:
      return 1500000;
  }
}

/// Cota mensal de direitos de TV.
int tvRights(int stars) {
  switch (stars) {
    case 5:
      return 15000000;
    case 4:
      return 10000000;
    default:
      return 6000000;
  }
}

/// Nível inicial das estruturas de clubes controlados pela IA.
int initialFacilityLevel(int stars) => stars >= 5 ? 2 : (stars == 4 ? 1 : 0);

int monthlyMaintenance(Team t) =>
    300000 * (1 + t.ctLevel + t.stadiumLevel + t.medicalLevel);

int ticketPrice(Team t) => 30 + 12 * t.stars;

/// Público pagante de um jogo em casa.
int attendance(Team t, int position) {
  double occ = 0.30 + t.fanMorale / 200.0 + 0.05 * t.stars;
  if (position > 0 && position <= 4) occ += 0.05;
  if (position >= 17) occ -= 0.05;
  occ = occ.clamp(0.15, 1.0).toDouble();
  return (t.effectiveCapacity * occ).round();
}

const int kWinBonus = 1000000;
const int kDrawBonus = 300000;
const int kLibertadoresBonus = 15000000;
const int kSulAmericanaBonus = 6000000;

/// Premiação pela posição final na Série A.
int positionPrize(int position) {
  final f = (21 - position) / 20.0;
  return (4000000 + 46000000 * f * f).round();
}

/// Salário mensal do técnico de um clube com [stars] estrelas.
int coachSalary(int stars, int reputation) {
  final base = stars >= 5 ? 1500000 : (stars == 4 ? 800000 : 400000);
  return ((base * (0.8 + reputation / 250.0)) / 10000).round() * 10000;
}

/// Reputação mínima para um clube convidar o técnico (Fase 10A).
int requiredReputation(int stars) => stars >= 5 ? 75 : (stars == 4 ? 55 : 0);

BoardGoal goalForStars(int stars) {
  if (stars >= 5) return BoardGoal.g4;
  if (stars == 4) return BoardGoal.top8;
  return BoardGoal.naoCair;
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
