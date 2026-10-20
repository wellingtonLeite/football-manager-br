import 'dart:math';
import 'models.dart';

class ClubInfo {
  final String name;
  final String shortName;
  final String state;
  final String stadium;
  final int stars;
  const ClubInfo(this.name, this.shortName, this.state, this.stadium, this.stars);
}

const List<ClubInfo> kClubs = [
  ClubInfo('Flamengo', 'FLA', 'RJ', 'Maracanã', 5),
  ClubInfo('Palmeiras', 'PAL', 'SP', 'Allianz Parque', 5),
  ClubInfo('São Paulo', 'SAO', 'SP', 'Morumbi', 4),
  ClubInfo('Corinthians', 'COR', 'SP', 'Neo Química Arena', 4),
  ClubInfo('Santos', 'SAN', 'SP', 'Vila Belmiro', 4),
  ClubInfo('Grêmio', 'GRE', 'RS', 'Arena do Grêmio', 4),
  ClubInfo('Internacional', 'INT', 'RS', 'Beira-Rio', 4),
  ClubInfo('Atlético Mineiro', 'CAM', 'MG', 'Arena MRV', 4),
  ClubInfo('Cruzeiro', 'CRU', 'MG', 'Mineirão', 4),
  ClubInfo('Fluminense', 'FLU', 'RJ', 'Maracanã', 4),
  ClubInfo('Botafogo', 'BOT', 'RJ', 'Nilton Santos', 4),
  ClubInfo('Vasco da Gama', 'VAS', 'RJ', 'São Januário', 3),
  ClubInfo('Bahia', 'BAH', 'BA', 'Arena Fonte Nova', 3),
  ClubInfo('Fortaleza', 'FOR', 'CE', 'Castelão', 3),
  ClubInfo('Athletico Paranaense', 'CAP', 'PR', 'Ligga Arena', 3),
  ClubInfo('Red Bull Bragantino', 'RBB', 'SP', 'Nabi Abi Chedid', 3),
  ClubInfo('Juventude', 'JUV', 'RS', 'Alfredo Jaconi', 3),
  ClubInfo('Cuiabá', 'CUI', 'MT', 'Arena Pantanal', 3),
  ClubInfo('Vitória', 'VIT', 'BA', 'Barradão', 3),
  ClubInfo('Goiás', 'GOI', 'GO', 'Serrinha', 3),
];

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
      return 82;
    case 4:
      return 78;
    default:
      return 74;
  }
}

List<Player> generateSquad(String teamId, int base, Random rng) {
  const List<List<Object>> structure = [
    ['GOL', 2],
    ['ZAG', 3],
    ['LAT', 2],
    ['VOL', 3],
    ['MEI', 4],
    ['ATA', 4],
  ];
  final List<Player> players = [];
  int n = 1;
  for (final entry in structure) {
    final pos = entry[0] as String;
    final count = entry[1] as int;
    for (int i = 0; i < count; i++) {
      final name =
          '${kFirstNames[rng.nextInt(kFirstNames.length)]} ${kLastNames[rng.nextInt(kLastNames.length)]}';
      final age = 18 + rng.nextInt(17);
      final delta = rng.nextInt(13) - 6;
      final starterBonus = i == 0 ? 4 : 0;
      int overall = base + delta + starterBonus;
      overall = overall.clamp(55, 92);
      players.add(Player(
        id: '${teamId}_p$n',
        name: name,
        position: pos,
        age: age,
        overall: overall,
      ));
      n++;
    }
  }
  return players;
}

List<Team> createLeague() {
  final rng = Random();
  return [
    for (final c in kClubs)
      Team(
        id: c.shortName.toLowerCase(),
        name: c.name,
        shortName: c.shortName,
        state: c.state,
        stadium: c.stadium,
        stars: c.stars,
        baseOverall: baseOverallForStars(c.stars),
        squad: generateSquad(
          c.shortName.toLowerCase(),
          baseOverallForStars(c.stars),
          rng,
        ),
      ),
  ];
}
