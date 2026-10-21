import 'dart:math';
import 'finances.dart';
import 'models.dart';

class ClubInfo {
  final String name;
  final String shortName;
  final String state;
  final String stadium;
  final String coach;
  final int stars;
  const ClubInfo(this.name, this.shortName, this.state, this.stadium,
      this.coach, this.stars);
}

const List<ClubInfo> kClubs = [
  ClubInfo('Flamengo', 'FLA', 'RJ', 'Maracanã', 'Filipe Luís', 5),
  ClubInfo('Palmeiras', 'PAL', 'SP', 'Allianz Parque', 'Abel Ferreira', 5),
  ClubInfo('Cruzeiro', 'CRU', 'MG', 'Mineirão', 'Leonardo Jardim', 4),
  ClubInfo('Botafogo', 'BOT', 'RJ', 'Nilton Santos', 'Davide Ancelotti', 4),
  ClubInfo('Bahia', 'BAH', 'BA', 'Arena Fonte Nova', 'Rogério Ceni', 4),
  ClubInfo('Mirassol', 'MIR', 'SP', 'Maião', 'Mozart', 3),
  ClubInfo('São Paulo', 'SAO', 'SP', 'MorumBIS', 'Hernán Crespo', 4),
  ClubInfo('Fluminense', 'FLU', 'RJ', 'Maracanã', 'Renato Gaúcho', 4),
  ClubInfo('Corinthians', 'COR', 'SP', 'Neo Química Arena', 'Dorival Júnior', 4),
  ClubInfo('Grêmio', 'GRE', 'RS', 'Arena do Grêmio', 'Mano Menezes', 4),
  ClubInfo('Atlético Mineiro', 'CAM', 'MG', 'Arena MRV', 'Cuca', 4),
  ClubInfo('Red Bull Bragantino', 'RBB', 'SP', 'Nabi Abi Chedid', 'Fernando Seabra', 3),
  ClubInfo('Vasco da Gama', 'VAS', 'RJ', 'São Januário', 'Fernando Diniz', 3),
  ClubInfo('Internacional', 'INT', 'RS', 'Beira-Rio', 'Roger Machado', 4),
  ClubInfo('Santos', 'SAN', 'SP', 'Vila Belmiro', 'Juan Pablo Vojvoda', 4),
  ClubInfo('Ceará', 'CEA', 'CE', 'Castelão', 'Léo Condé', 3),
  ClubInfo('Coritiba', 'CFC', 'PR', 'Couto Pereira', 'Gustavo Morínigo', 3),
  ClubInfo('Athletico Paranaense', 'CAP', 'PR', 'Ligga Arena', 'Odair Hellmann', 3),
  ClubInfo('Chapecoense', 'CHA', 'SC', 'Arena Condá', 'Umberto Louzer', 3),
  ClubInfo('Remo', 'REM', 'PA', 'Baenão', 'Rodrigo Santana', 3),
];

class Star {
  final String name;
  final String position;
  final int age;
  final int overall;
  const Star(this.name, this.position, this.age, this.overall);
}

const Map<String, List<Star>> kStars = {
  'FLA': [
    Star('Agustín Rossi', 'GOL', 31, 84),
    Star('Léo Ortiz', 'ZAG', 30, 84),
    Star('Alex Sandro', 'LAT', 35, 80),
    Star('Gerson', 'VOL', 29, 86),
    Star('Arrascaeta', 'MEI', 32, 87),
    Star('Pedro', 'ATA', 29, 86),
  ],
  'PAL': [
    Star('Weverton', 'GOL', 38, 84),
    Star('Gustavo Gómez', 'ZAG', 33, 85),
    Star('Piquerez', 'LAT', 27, 83),
    Star('Aníbal Moreno', 'VOL', 27, 84),
    Star('Raphael Veiga', 'MEI', 31, 84),
    Star('Vitor Roque', 'ATA', 21, 84),
  ],
  'CRU': [
    Star('Cássio', 'GOL', 39, 82),
    Star('Fabrício Bruno', 'ZAG', 30, 82),
    Star('Lucas Romero', 'VOL', 32, 80),
    Star('Matheus Pereira', 'MEI', 30, 84),
    Star('Kaio Jorge', 'ATA', 24, 83),
    Star('Gabigol', 'ATA', 30, 82),
  ],
  'BOT': [
    Star('John', 'GOL', 30, 82),
    Star('Alexander Barboza', 'ZAG', 31, 81),
    Star('Alex Telles', 'LAT', 34, 80),
    Star('Marlon Freitas', 'VOL', 32, 81),
    Star('Savarino', 'MEI', 29, 82),
    Star('Artur', 'ATA', 28, 81),
  ],
  'BAH': [
    Star('Marcos Felipe', 'GOL', 30, 80),
    Star('Gabriel Xavier', 'ZAG', 31, 80),
    Star('Luciano Juba', 'LAT', 27, 80),
    Star('Caio Alexandre', 'VOL', 27, 80),
    Star('Everton Ribeiro', 'MEI', 37, 82),
    Star('Willian José', 'ATA', 34, 80),
  ],
  'MIR': [
    Star('Alex Muralha', 'GOL', 36, 78),
    Star('Reinaldo', 'LAT', 36, 78),
    Star('Danielzinho', 'MEI', 30, 79),
    Star('Iury Castilho', 'ATA', 30, 78),
  ],
  'SAO': [
    Star('Rafael', 'GOL', 36, 82),
    Star('Arboleda', 'ZAG', 34, 81),
    Star('Bobadilla', 'VOL', 29, 81),
    Star('Lucas Moura', 'MEI', 33, 84),
    Star('Calleri', 'ATA', 32, 81),
    Star('Ferreirinha', 'ATA', 28, 80),
  ],
  'FLU': [
    Star('Fábio', 'GOL', 45, 79),
    Star('Thiago Silva', 'ZAG', 41, 80),
    Star('Ganso', 'MEI', 36, 80),
    Star('Germán Cano', 'ATA', 38, 79),
  ],
  'COR': [
    Star('Hugo Souza', 'GOL', 27, 82),
    Star('Gustavo Henrique', 'ZAG', 33, 79),
    Star('Raniele', 'VOL', 29, 80),
    Star('Rodrigo Garro', 'MEI', 27, 84),
    Star('Memphis Depay', 'ATA', 31, 84),
    Star('Yuri Alberto', 'ATA', 25, 82),
  ],
  'GRE': [
    Star('Tiago Volpi', 'GOL', 35, 80),
    Star('Kannemann', 'ZAG', 35, 80),
    Star('Marlon', 'LAT', 29, 79),
    Star('Villasanti', 'VOL', 28, 81),
    Star('Cristaldo', 'MEI', 29, 80),
    Star('Braithwaite', 'ATA', 35, 80),
  ],
  'CAM': [
    Star('Everson', 'GOL', 35, 81),
    Star('Júnior Alonso', 'ZAG', 33, 81),
    Star('Alan Franco', 'VOL', 29, 80),
    Star('Gustavo Scarpa', 'MEI', 32, 82),
    Star('Hulk', 'ATA', 39, 81),
    Star('Rony', 'ATA', 31, 80),
  ],
  'RBB': [
    Star('Cleiton', 'GOL', 28, 80),
    Star('Lucas Evangelista', 'MEI', 31, 80),
    Star('Eduardo Sasha', 'ATA', 34, 79),
    Star('Isidro Pitta', 'ATA', 26, 80),
  ],
  'VAS': [
    Star('Léo Jardim', 'GOL', 30, 82),
    Star('João Victor', 'ZAG', 27, 79),
    Star('Philippe Coutinho', 'MEI', 33, 83),
    Star('Payet', 'MEI', 41, 78),
    Star('Vegetti', 'ATA', 37, 81),
  ],
  'INT': [
    Star('Anthoni', 'GOL', 24, 79),
    Star('Vitão', 'ZAG', 26, 80),
    Star('Bernabei', 'LAT', 25, 79),
    Star('Alan Patrick', 'MEI', 34, 82),
    Star('Borré', 'ATA', 30, 81),
  ],
  'SAN': [
    Star('Gabriel Brazão', 'GOL', 25, 80),
    Star('Zé Ivaldo', 'ZAG', 28, 78),
    Star('João Schmidt', 'VOL', 33, 78),
    Star('Guilherme', 'ATA', 30, 79),
    Star('Tiquinho Soares', 'ATA', 35, 79),
    Star('Neymar', 'ATA', 34, 84),
  ],
  'CEA': [
    Star('Bruno Ferreira', 'GOL', 29, 78),
    Star('Marllon', 'ZAG', 33, 77),
    Star('Matheus Araújo', 'MEI', 24, 77),
    Star('Pedro Raul', 'ATA', 29, 79),
  ],
  'CFC': [
    Star('Pedro Rangel', 'GOL', 25, 77),
    Star('Bruno Melo', 'ZAG', 33, 77),
    Star('Josué', 'MEI', 24, 77),
    Star('Gustavo Coutinho', 'ATA', 27, 78),
  ],
  'CAP': [
    Star('Mycael', 'GOL', 21, 78),
    Star('Thiago Heleno', 'ZAG', 37, 78),
    Star('Fernandinho', 'VOL', 40, 78),
    Star('Julimar', 'ATA', 24, 78),
  ],
  'CHA': [
    Star('Mailson', 'GOL', 29, 77),
    Star('Bruno Leonardo', 'ZAG', 28, 77),
    Star('Marcinho', 'MEI', 30, 77),
    Star('Mário Sérgio', 'ATA', 28, 77),
  ],
  'REM': [
    Star('Marcelo Rangel', 'GOL', 34, 78),
    Star('Reynaldo', 'ZAG', 28, 78),
    Star('Pedro Castro', 'VOL', 33, 77),
    Star('Ytalo', 'ATA', 38, 77),
  ],
};

const List<String> kFirstNames = [
  'Gabriel', 'Lucas', 'Matheus', 'Rafael', 'Thiago', 'Bruno', 'Diego',
  'Carlos', 'Eduardo', 'Felipe', 'Gustavo', 'João', 'Pedro', 'Vinícius',
  'Everton', 'Wesley', 'Kaio', 'Renan', 'Igor', 'Caio', 'Luan', 'Marcos',
  'Paulo', 'André', 'Rodrigo', 'Vitor', 'Danilo', 'Alex', 'Yuri', 'Emerson',
];

const List<String> kLastNames = [
  'Silva', 'Santos', 'Oliveira', 'Souza', 'Pereira', 'Costa', 'Rodrigues',
  'Almeida', 'Nascimento', 'Lima', 'Araújo', 'Fernandes', 'Carvalho',
  'Gomes', 'Martins', 'Rocha', 'Ribeiro', 'Alves', 'Monteiro', 'Cardoso',
  'Teixeira', 'Barbosa', 'Correia', 'Dias', 'Freitas', 'Moura', 'Cavalcante',
];

int baseOverallForStars(int stars) {
  switch (stars) {
    case 5:
      return 83;
    case 4:
      return 79;
    default:
      return 75;
  }
}

/// Capacidade padrão dos estádios (Fase 8 - bilheteria).
const Map<String, int> kStadiumCapacity = {
  'FLA': 78000, 'PAL': 41000, 'CRU': 62000, 'BOT': 47000, 'BAH': 52000,
  'MIR': 30000, 'SAO': 67000, 'FLU': 78000, 'COR': 49000, 'GRE': 60000,
  'CAM': 58000, 'RBB': 17000, 'VAS': 24500, 'INT': 50000, 'SAN': 16000,
  'CEA': 63000, 'CFC': 40000, 'CAP': 42000, 'CHA': 20000, 'REM': 48000,
};

/// Orçamento inicial baseado nas estrelas do clube (Fase 8).
double initialBudgetForStars(int stars) {
  switch (stars) {
    case 5:
      return 90.0;
    case 4:
      return 55.0;
    default:
      return 30.0;
  }
}

Team _buildTeam(ClubInfo c, Random rng) {
  final int base = baseOverallForStars(c.stars);
  final List<Star> stars = kStars[c.shortName] ?? const <Star>[];
  final String tid = c.shortName.toLowerCase();
  final List<Player> squad = [];
  int n = 1;

  for (final s in stars) {
    final p = Player(
      id: '${tid}_p$n',
      name: s.name,
      position: s.position,
      age: s.age,
      overall: s.overall,
    );
    p.refreshMarketNumbers();
    squad.add(p);
    n++;
  }

  const Map<String, int> targets = {
    'GOL': 2,
    'ZAG': 3,
    'LAT': 2,
    'VOL': 3,
    'MEI': 4,
    'ATA': 4,
  };
  final Map<String, int> counts = {};
  for (final s in stars) {
    counts[s.position] = (counts[s.position] ?? 0) + 1;
  }
  targets.forEach((pos, target) {
    final int have = counts[pos] ?? 0;
    for (int i = 0; i < target - have; i++) {
      final String name =
          '${kFirstNames[rng.nextInt(kFirstNames.length)]} ${kLastNames[rng.nextInt(kLastNames.length)]}';
      final int age = 18 + rng.nextInt(17);
      final int overall = (base + rng.nextInt(13) - 6).clamp(55, 92).toInt();
      final p = Player(
        id: '${tid}_p$n',
        name: name,
        position: pos,
        age: age,
        overall: overall,
      );
      p.refreshMarketNumbers();
      squad.add(p);
      n++;
    }
  });

  final team = Team(
    id: tid,
    name: c.name,
    shortName: c.shortName,
    state: c.state,
    stadium: c.stadium,
    coach: c.coach,
    stars: c.stars,
    baseOverall: base,
    squad: squad,
    stadiumCapacity: kStadiumCapacity[c.shortName] ?? 30000,
  );
  team.finances = ClubFinances(balance: initialBudgetForStars(c.stars));
  return team;
}

List<Team> createLeague() {
  final rng = Random();
  return [for (final c in kClubs) _buildTeam(c, rng)];
}
