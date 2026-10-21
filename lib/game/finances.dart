/// Fase 8 - Finanças e Economia do Clube
///
/// Modelo de [ClubFinances]: caixa, receitas (bilheteria, premiação,
/// patrocínio), despesas (folha salarial, investimentos) e histórico
/// mensal para gráficos. Valores em milhões de reais (R\$ mi).
library;

class FinanceEntry {
  final String label;
  final double amount; // positivo = entrada, negativo = saída
  final int round;

  FinanceEntry(this.label, this.amount, this.round);

  Map<String, dynamic> toJson() =>
      {'label': label, 'amount': amount, 'round': round};

  factory FinanceEntry.fromJson(Map<String, dynamic> j) =>
      FinanceEntry(j['label'] as String, (j['amount'] ?? 0).toDouble(),
          j['round'] ?? 0);
}

class ClubFinances {
  double balance; // caixa atual (R\$ mi)
  int trainingLevel; // 0..3 (CT) - acelera evolução de jovens
  int stadiumLevel; // 0..3 - aumenta capacidade/receita
  int medicalLevel; // 0..3 - reduz desgaste de energia
  List<FinanceEntry> history = [];

  ClubFinances({
    this.balance = 20.0,
    this.trainingLevel = 0,
    this.stadiumLevel = 0,
    this.medicalLevel = 0,
  });

  static const investmentCosts = [15.0, 30.0, 60.0]; // custo p/ nível 1,2,3
  static const maxLevel = 3;

  bool get canInvest =>
      trainingLevel < maxLevel ||
      stadiumLevel < maxLevel ||
      medicalLevel < maxLevel;

  double get nextInvestmentCost => investmentCosts[0];

  /// Receita de bilheteria por jogo em casa:
  /// lotação x preço médio x fator popularidade (estrelas + moral da torcida).
  static double ticketRevenue(
      int capacity, int stars, int fanMorale, int stadiumLevel) {
    final occupancy = 0.55 + 0.05 * stars + (fanMorale / 100.0) * 0.2;
    final avgTicketPrice = 45.0 + stars * 15.0 + stadiumLevel * 10.0; // R\$
    final attendees =
        (capacity * occupancy.clamp(0.4, 0.98)).toInt();
    return double.parse(
        ((attendees * avgTicketPrice) / 1000000.0).toStringAsFixed(2));
  }

  /// Patrocínio fixo por rodada (R\$ mi), proporcional à reputação.
  static double sponsorshipPerRound(int stars) =>
      double.parse((1.2 * stars).toStringAsFixed(2));

  /// Premiação por resultado na Série A (R\$ mi).
  static double prizeMoney(bool win, bool draw) => win ? 3.0 : (draw ? 1.5 : 0.5);

  /// Bônus de fim de temporada por posição final (R\$ mi).
  static double seasonEndBonus(int position) {
    if (position == 1) return 50.0; // campeão
    if (position <= 4) return 25.0; // Libertadores
    if (position <= 8) return 12.0; // Sul-Americana
    if (position <= 16) return 5.0;
    return 0.0; // rebaixado perde receita
  }

  void credit(String label, double amount, int round) {
    balance += amount;
    history.add(FinanceEntry(label, amount, round));
  }

  void debit(String label, double amount, int round) {
    balance -= amount;
    history.add(FinanceEntry(label, -amount, round));
  }

  /// Tenta investir em uma área; retorna mensagem de resultado ou null
  /// se não houver dinheiro/nível disponível.
  String? invest(String area, int round) {
    int level = switch (area) {
      'ct' => trainingLevel,
      'estadio' => stadiumLevel,
      'medico' => medicalLevel,
      _ => maxLevel,
    };
    if (level >= maxLevel) return null;
    final cost = investmentCosts[level];
    if (balance < cost) return null;
    balance -= cost;
    history.add(FinanceEntry('Investimento: $area', -cost, round));
    switch (area) {
      case 'ct':
        trainingLevel++;
        return 'Centro de Treinamento melhorado! Nível $trainingLevel/$maxLevel.';
      case 'estadio':
        stadiumLevel++;
        return 'Estádio ampliado! Nível $stadiumLevel/$maxLevel.';
      case 'medico':
        medicalLevel++;
        return 'Departamento Médico aprimorado! Nível $medicalLevel/$maxLevel.';
    }
    return null;
  }

  double get totalIncomeThisSeason =>
      history.where((e) => e.amount > 0).fold(0.0, (s, e) => s + e.amount);

  double get totalExpensesThisSeason =>
      -history.where((e) => e.amount < 0).fold(0.0, (s, e) => s + e.amount);

  Map<String, dynamic> toJson() => {
        'balance': balance,
        'trainingLevel': trainingLevel,
        'stadiumLevel': stadiumLevel,
        'medicalLevel': medicalLevel,
        'history': history.map((e) => e.toJson()).toList(),
      };

  factory ClubFinances.fromJson(Map<String, dynamic> j) {
    final f = ClubFinances(
      balance: (j['balance'] ?? 20.0).toDouble(),
      trainingLevel: j['trainingLevel'] ?? 0,
      stadiumLevel: j['stadiumLevel'] ?? 0,
      medicalLevel: j['medicalLevel'] ?? 0,
    );
    f.history = (j['history'] as List? ?? [])
        .map((e) => FinanceEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return f;
  }
}
