import 'dart:math';
import 'models.dart';
import 'economy.dart';

class ClubInfo {
  final String name;
  final String shortName;
  final String state;
  final String stadium;
  final String coach;
  final int stars;
  final int capacity;
  const ClubInfo(this.name, this.shortName, this.state, this.stadium,
      this.coach, this.stars, this.capacity);
}

// Série A 2026 — técnicos atualizados em 20/10/2026.
const List<ClubInfo> kClubs = [
  ClubInfo('Flamengo', 'FLA', 'RJ', 'Maracanã', 'Leonardo Jardim', 5, 78000),
  ClubInfo('Palmeiras', 'PAL', 'SP', 'Nubank Parque', 'Abel Ferreira', 5, 43000),
  ClubInfo('Cruzeiro', 'CRU', 'MG', 'Mineirão', 'Artur Jorge', 4, 62000),
  ClubInfo('Botafogo', 'BOT', 'RJ', 'Nilton Santos', 'Tite', 4, 44000),
  ClubInfo('Bahia', 'BAH', 'BA', 'Arena Fonte Nova', 'Rogério Ceni', 4, 48000),
  ClubInfo('Mirassol', 'MIR', 'SP', 'Maião', 'Rafael Guanaes', 3, 15000),
  ClubInfo('São Paulo', 'SAO', 'SP', 'MorumBIS', 'Dorival Júnior', 4, 66000),
  ClubInfo('Fluminense', 'FLU', 'RJ', 'Maracanã', 'Marcão (interino)', 4, 78000),
  ClubInfo('Corinthians', 'COR', 'SP', 'Neo Química Arena', 'Clarence Seedorf', 4, 47000),
  ClubInfo('Grêmio', 'GRE', 'RS', 'Arena do Grêmio', 'Renato Gaúcho', 4, 55000),
  ClubInfo('Atlético Mineiro', 'CAM', 'MG', 'Arena MRV', 'Eduardo Domínguez', 4, 46000),
  ClubInfo('Red Bull Bragantino', 'RBB', 'SP', 'Cícero de Souza Marques', 'Vagner Mancini', 3, 17000),
  ClubInfo('Vasco da Gama', 'VAS', 'RJ', 'São Januário', 'Pedro Emanuel', 3, 21000),
  ClubInfo('Internacional', 'INT', 'RS', 'Beira-Rio', 'Eduardo Baptista', 4, 50000),
  ClubInfo('Santos', 'SAN', 'SP', 'Vila Belmiro', 'Cuca', 4, 16000),
  ClubInfo('Vitória', 'VIT', 'BA', 'Barradão', 'Jair Ventura', 3, 30000),
  ClubInfo('Coritiba', 'CFC', 'PR', 'Couto Pereira', 'Fernando Seabra', 3, 40000),
  ClubInfo('Athletico Paranaense', 'CAP', 'PR', 'Arena da Baixada', 'Odair Hellmann', 4, 42000),
  ClubInfo('Chapecoense', 'CHA', 'SC', 'Arena Condá', 'Rafael Lacerda', 3, 20000),
  ClubInfo('Remo', 'REM', 'PA', 'Mangueirão', 'Thiago Carpini', 3, 50000),
];

/// Técnicos sem clube, usados para substituir técnicos demitidos pela IA
/// ou quando o usuário deixa um clube.
const List<String> kCoachPool = [
  'Filipe Luís', 'Fernando Diniz', 'Luís Castro', 'Paulo Pezzolano',
  'Luis Zubeldía', 'Hernán Crespo', 'Roger Machado', 'Martín Anselmi',
  'Franclim Carvalho', 'Léo Condé', 'Juan Pablo Vojvoda', 'Jorge Sampaoli',
  'Gilmar Dal Pozzo', 'Fábio Matias', 'Juan Carlos Osorio', 'Mano Menezes',
];

class Star {
  final String name;
  final String position;
  final int age;
  final int overall;
  const Star(this.name, this.position, this.age, this.overall);
}

// Elencos principais atualizados em 20/10/2026 (idades na temporada 2026).
// Overall é uma estimativa do jogo; o restante do elenco é gerado.
const Map<String, List<Star>> kStars = {
  'FLA': [
    Star('Agustín Rossi', 'GOL', 31, 84),
    Star('Andrew', 'GOL', 25, 76),
    Star('Léo Ortiz', 'ZAG', 30, 84),
    Star('Léo Pereira', 'ZAG', 30, 83),
    Star('Danilo', 'ZAG', 35, 80),
    Star('Vitão', 'ZAG', 26, 79),
    Star('Guillermo Varela', 'LAT', 33, 80),
    Star('Emerson Royal', 'LAT', 27, 80),
    Star('Alex Sandro', 'LAT', 35, 79),
    Star('Ayrton Lucas', 'LAT', 29, 79),
    Star('Jorginho', 'VOL', 34, 83),
    Star('Erick Pulgar', 'VOL', 32, 82),
    Star('Saúl Ñíguez', 'VOL', 31, 81),
    Star('Arrascaeta', 'MEI', 32, 87),
    Star('Lucas Paquetá', 'MEI', 29, 86),
    Star('Jorge Carrascal', 'MEI', 28, 82),
    Star('Nicolás de la Cruz', 'MEI', 29, 81),
    Star('Pedro', 'ATA', 29, 85),
    Star('Samuel Lino', 'ATA', 26, 82),
    Star('Gonzalo Plata', 'ATA', 25, 81),
    Star('Luiz Araújo', 'ATA', 30, 80),
    Star('Bruno Henrique', 'ATA', 35, 79),
  ],
  'PAL': [
    Star('Carlos Miguel', 'GOL', 28, 82),
    Star('Marcelo Lomba', 'GOL', 39, 76),
    Star('Gustavo Gómez', 'ZAG', 33, 84),
    Star('Murilo', 'ZAG', 29, 82),
    Star('Bruno Fuchs', 'ZAG', 27, 81),
    Star('Alexander Barboza', 'ZAG', 31, 81),
    Star('Joaquín Piquerez', 'LAT', 28, 82),
    Star('Agustín Giay', 'LAT', 22, 80),
    Star('Khellven', 'LAT', 25, 79),
    Star('Jefté', 'LAT', 22, 77),
    Star('Marlon Freitas', 'VOL', 31, 82),
    Star('Emiliano Martínez', 'VOL', 27, 81),
    Star('Lucas Evangelista', 'VOL', 31, 80),
    Star('Andreas Pereira', 'MEI', 30, 83),
    Star('Felipe Anderson', 'MEI', 33, 81),
    Star('Maurício', 'MEI', 25, 80),
    Star('Vitor Roque', 'ATA', 21, 84),
    Star('Jhon Arias', 'ATA', 29, 84),
    Star('Flaco López', 'ATA', 25, 82),
    Star('Paulinho', 'ATA', 26, 82),
    Star('Ramón Sosa', 'ATA', 27, 81),
  ],
  'CRU': [
    Star('Cássio', 'GOL', 39, 81),
    Star('Léo Aragão', 'GOL', 22, 73),
    Star('Fabrício Bruno', 'ZAG', 30, 82),
    Star('Jonathan Jesus', 'ZAG', 27, 79),
    Star('Lucas Villalba', 'ZAG', 31, 79),
    Star('João Marcelo', 'ZAG', 26, 78),
    Star('William', 'LAT', 31, 79),
    Star('Matías Viña', 'LAT', 28, 79),
    Star('Fagner', 'LAT', 37, 77),
    Star('Gabriel Rojas', 'LAT', 29, 78),
    Star('Gerson', 'VOL', 29, 85),
    Star('Lucas Romero', 'VOL', 32, 80),
    Star('Matheus Henrique', 'VOL', 28, 80),
    Star('Lucas Silva', 'VOL', 33, 78),
    Star('Matheus Pereira', 'MEI', 30, 84),
    Star('Kaio Jorge', 'ATA', 24, 83),
    Star('Luis Sinisterra', 'ATA', 27, 81),
    Star('Gabriel Pec', 'ATA', 25, 79),
    Star('Wanderson', 'ATA', 32, 78),
    Star('Keny Arroyo', 'ATA', 20, 77),
  ],
  'BOT': [
    Star('Gabriel Batista', 'GOL', 28, 78),
    Star('Warleson', 'GOL', 29, 74),
    Star('Nahuel Ferraresi', 'ZAG', 28, 79),
    Star('Kaio Pantaleão', 'ZAG', 30, 78),
    Star('Arthur Chaves', 'ZAG', 25, 77),
    Star('Alex Telles', 'LAT', 33, 80),
    Star('Vitinho', 'LAT', 27, 79),
    Star('Mateo Ponte', 'LAT', 22, 76),
    Star('Danilo', 'VOL', 25, 81),
    Star('Cristian Medina', 'VOL', 24, 80),
    Star('Allan', 'VOL', 35, 77),
    Star('Edenilson', 'VOL', 36, 76),
    Star('Álvaro Montoro', 'MEI', 19, 79),
    Star('Hakim Ziyech', 'MEI', 33, 81),
    Star('Jordan Barrera', 'MEI', 22, 76),
    Star('Arthur Cabral', 'ATA', 28, 80),
    Star('Júnior Santos', 'ATA', 32, 79),
    Star('Matheus Martins', 'ATA', 23, 78),
    Star('Tiquinho Soares', 'ATA', 35, 77),
  ],
  'BAH': [
    Star('Guido Herrera', 'GOL', 34, 79),
    Star('Ronaldo', 'GOL', 30, 77),
    Star('Kanu', 'ZAG', 29, 78),
    Star('David Duarte', 'ZAG', 31, 78),
    Star('Marcos Victor', 'ZAG', 22, 75),
    Star('Luciano Juba', 'LAT', 27, 80),
    Star('Román Gómez', 'LAT', 23, 76),
    Star('Caio Alexandre', 'VOL', 27, 80),
    Star('Jean Lucas', 'VOL', 28, 80),
    Star('Nicolás Acevedo', 'VOL', 27, 79),
    Star('Erick', 'VOL', 28, 77),
    Star('Everton Ribeiro', 'MEI', 37, 80),
    Star('Rodrigo Nestor', 'MEI', 26, 79),
    Star('Michel Araújo', 'MEI', 30, 78),
    Star('Willian José', 'ATA', 34, 78),
    Star('Ademir', 'ATA', 31, 78),
    Star('Erick Pulga', 'ATA', 26, 78),
    Star('Kike Olivera', 'ATA', 24, 78),
    Star('Alejo Véliz', 'ATA', 23, 76),
  ],
  'MIR': [
    Star('Walter', 'GOL', 38, 77),
    Star('Alex Muralha', 'GOL', 37, 74),
    Star('Lucas Oliveira', 'ZAG', 30, 76),
    Star('Willian Machado', 'ZAG', 30, 76),
    Star('João Victor', 'ZAG', 27, 74),
    Star('Reinaldo', 'LAT', 37, 77),
    Star('Daniel Borges', 'LAT', 33, 75),
    Star('Victor Luis', 'LAT', 33, 74),
    Star('Neto Moura', 'VOL', 29, 77),
    Star('José Aldo', 'VOL', 30, 75),
    Star('Denilson', 'VOL', 29, 74),
    Star('Chico Kim', 'MEI', 25, 76),
    Star('Shaylon', 'MEI', 28, 76),
    Star('Negueba', 'ATA', 27, 77),
    Star('Alesson', 'ATA', 29, 76),
    Star('Edson Carioca', 'ATA', 30, 75),
    Star('André Luis', 'ATA', 28, 75),
  ],
  'SAO': [
    Star('Rafael', 'GOL', 37, 80),
    Star('Carlos Coronel', 'GOL', 29, 77),
    Star('Robert Arboleda', 'ZAG', 35, 80),
    Star('Rafael Tolói', 'ZAG', 36, 78),
    Star('Domingos Duarte', 'ZAG', 31, 78),
    Star('Sabino', 'ZAG', 29, 77),
    Star('Wendell', 'LAT', 33, 78),
    Star('Enzo Díaz', 'LAT', 30, 78),
    Star('Cédric Soares', 'LAT', 35, 77),
    Star('Marcos Antônio', 'VOL', 26, 80),
    Star('Damián Bobadilla', 'VOL', 25, 80),
    Star('Pablo Maia', 'VOL', 24, 79),
    Star('Danielzinho', 'VOL', 31, 77),
    Star('Lucas Moura', 'MEI', 34, 82),
    Star('Cauly', 'MEI', 31, 78),
    Star('Jonathan Calleri', 'ATA', 33, 80),
    Star('Luciano', 'ATA', 33, 79),
    Star('Ferreirinha', 'ATA', 28, 79),
    Star('André Silva', 'ATA', 28, 77),
  ],
  'FLU': [
    Star('Fábio', 'GOL', 46, 77),
    Star('Vitor Eudes', 'GOL', 24, 74),
    Star('Thiago Silva', 'ZAG', 42, 79),
    Star('Juan Pablo Freytes', 'ZAG', 26, 79),
    Star('Ignácio', 'ZAG', 29, 78),
    Star('Igor Rabello', 'ZAG', 31, 76),
    Star('Guilherme Arana', 'LAT', 29, 81),
    Star('Samuel Xavier', 'LAT', 36, 77),
    Star('Guga', 'LAT', 28, 77),
    Star('Matheus Martinelli', 'VOL', 25, 80),
    Star('Hércules', 'VOL', 26, 79),
    Star('Otávio', 'VOL', 32, 78),
    Star('Nonato', 'VOL', 28, 77),
    Star('Lucho Acosta', 'MEI', 32, 83),
    Star('Jefferson Savarino', 'MEI', 29, 81),
    Star('Ganso', 'MEI', 37, 79),
    Star('Hulk', 'ATA', 40, 80),
    Star('Kevin Serna', 'ATA', 28, 79),
    Star('Agustín Canobbio', 'ATA', 28, 79),
    Star('Yeferson Soteldo', 'ATA', 29, 79),
    Star('John Kennedy', 'ATA', 24, 78),
    Star('Germán Cano', 'ATA', 38, 78),
  ],
  'COR': [
    Star('Hugo Souza', 'GOL', 27, 82),
    Star('Felipe Longo', 'GOL', 21, 72),
    Star('Gabriel Paulista', 'ZAG', 35, 79),
    Star('André Ramalho', 'ZAG', 34, 79),
    Star('Gustavo Henrique', 'ZAG', 33, 78),
    Star('Matheuzinho', 'LAT', 26, 79),
    Star('Matheus Bidu', 'LAT', 27, 77),
    Star('Fabrizio Angileri', 'LAT', 32, 77),
    Star('Raniele', 'VOL', 29, 79),
    Star('Breno Bidon', 'VOL', 21, 79),
    Star('Charles', 'VOL', 30, 77),
    Star('Alex Santana', 'VOL', 31, 76),
    Star('Rodrigo Garro', 'MEI', 28, 84),
    Star('Jesse Lingard', 'MEI', 33, 81),
    Star('André Carrillo', 'MEI', 35, 78),
    Star('Memphis Depay', 'ATA', 32, 84),
    Star('Yuri Alberto', 'ATA', 25, 82),
    Star('Pedro Raul', 'ATA', 29, 78),
    Star('Kaio César', 'ATA', 22, 75),
  ],
  'GRE': [
    Star('Weverton', 'GOL', 38, 81),
    Star('Gabriel Grando', 'GOL', 25, 74),
    Star('Fabián Balbuena', 'ZAG', 35, 79),
    Star('Walter Kannemann', 'ZAG', 35, 78),
    Star('Wagner Leonardo', 'ZAG', 27, 78),
    Star('Gustavo Martins', 'ZAG', 22, 76),
    Star('Marlon', 'LAT', 29, 77),
    Star('João Pedro', 'LAT', 29, 77),
    Star('Caio Paulista', 'LAT', 28, 77),
    Star('Marcos Rocha', 'LAT', 38, 75),
    Star('Mathías Villasanti', 'VOL', 29, 80),
    Star('Juan Nardoni', 'VOL', 24, 79),
    Star('Erick Noriega', 'VOL', 25, 77),
    Star('Dodi', 'VOL', 30, 77),
    Star('Filip Krovinović', 'MEI', 31, 78),
    Star('Tetê', 'ATA', 26, 79),
    Star('Cristian Pavón', 'ATA', 30, 79),
    Star('Martin Braithwaite', 'ATA', 35, 79),
    Star('Carlos Vinícius', 'ATA', 31, 78),
    Star('José Enamorado', 'ATA', 27, 78),
    Star('Francis Amuzu', 'ATA', 27, 78),
  ],
  'CAM': [
    Star('Everson', 'GOL', 36, 80),
    Star('Gabriel Delfim', 'GOL', 23, 74),
    Star('Lyanco', 'ZAG', 29, 79),
    Star('Ruan Tressoldi', 'ZAG', 27, 78),
    Star('Vitor Hugo', 'ZAG', 35, 77),
    Star('Léo Duarte', 'ZAG', 30, 77),
    Star('Renan Lodi', 'LAT', 28, 80),
    Star('Natanael', 'LAT', 24, 77),
    Star('Ángelo Preciado', 'LAT', 28, 77),
    Star('Fred', 'VOL', 33, 81),
    Star('Alan Franco', 'VOL', 28, 79),
    Star('Kevin Castaño', 'VOL', 26, 78),
    Star('Maycon', 'VOL', 29, 78),
    Star('Gustavo Scarpa', 'MEI', 32, 81),
    Star('Bernard', 'MEI', 34, 78),
    Star('Reinier', 'MEI', 24, 77),
    Star('Dudu', 'ATA', 34, 78),
    Star('Tomás Cuello', 'ATA', 26, 78),
    Star('Mateo Cassierra', 'ATA', 29, 78),
    Star('Alan Minda', 'ATA', 23, 77),
  ],
  'RBB': [
    Star('Cleiton', 'GOL', 28, 79),
    Star('Tiago Volpi', 'GOL', 35, 78),
    Star('Guzmán Rodríguez', 'ZAG', 33, 77),
    Star('Eduardo Santos', 'ZAG', 29, 77),
    Star('Alix Vinicius', 'ZAG', 25, 76),
    Star('Juninho Capixaba', 'LAT', 29, 77),
    Star('Agustín Sant\'Anna', 'LAT', 28, 76),
    Star('Vanderlan', 'LAT', 23, 76),
    Star('Matheus Fernandes', 'VOL', 28, 77),
    Star('Eric Ramires', 'VOL', 26, 77),
    Star('Fabinho', 'VOL', 26, 76),
    Star('Rodriguinho', 'MEI', 22, 75),
    Star('Nacho Sosa', 'MEI', 26, 75),
    Star('Isidro Pitta', 'ATA', 26, 78),
    Star('Lucas Barbosa', 'ATA', 25, 77),
    Star('Eduardo Sasha', 'ATA', 34, 77),
    Star('Henry Mosquera', 'ATA', 24, 76),
    Star('Vinicinho', 'ATA', 23, 76),
  ],
  'VAS': [
    Star('Léo Jardim', 'GOL', 31, 82),
    Star('Daniel Fuzato', 'GOL', 29, 75),
    Star('Carlos Cuesta', 'ZAG', 27, 79),
    Star('Robert Renan', 'ZAG', 23, 78),
    Star('Alan Saldivia', 'ZAG', 24, 77),
    Star('Lucas Freitas', 'ZAG', 22, 75),
    Star('Puma Rodríguez', 'LAT', 26, 78),
    Star('Lucas Piton', 'LAT', 25, 78),
    Star('Cuiabano', 'LAT', 23, 76),
    Star('Tchê Tchê', 'VOL', 34, 77),
    Star('Thiago Mendes', 'VOL', 34, 77),
    Star('Jair', 'VOL', 21, 76),
    Star('Santiago Sosa', 'VOL', 27, 76),
    Star('Johan Rojas', 'MEI', 23, 76),
    Star('Alan Lescano', 'MEI', 25, 76),
    Star('Nuno Moreira', 'ATA', 27, 78),
    Star('Andrés Gómez', 'ATA', 23, 78),
    Star('Brenner', 'ATA', 26, 78),
    Star('Facundo Colidio', 'ATA', 26, 78),
    Star('David', 'ATA', 31, 77),
    Star('Marino Hinestroza', 'ATA', 24, 77),
  ],
  'INT': [
    Star('Sergio Rochet', 'GOL', 33, 81),
    Star('Anthoni', 'GOL', 24, 76),
    Star('Guillermo Maripán', 'ZAG', 32, 80),
    Star('Félix Torres', 'ZAG', 29, 78),
    Star('Gabriel Mercado', 'ZAG', 39, 76),
    Star('Victor Gabriel', 'ZAG', 20, 74),
    Star('Alexandro Bernabei', 'LAT', 26, 79),
    Star('Braian Aguirre', 'LAT', 26, 77),
    Star('Matheus Bahia', 'LAT', 26, 75),
    Star('Thiago Maia', 'VOL', 29, 79),
    Star('Rodrigo Villagra', 'VOL', 25, 79),
    Star('Bruno Henrique', 'VOL', 36, 77),
    Star('Ronaldo', 'VOL', 28, 76),
    Star('Alan Patrick', 'MEI', 35, 81),
    Star('Johan Carbonero', 'ATA', 27, 79),
    Star('Alerrandro', 'ATA', 26, 78),
    Star('Vitinho', 'ATA', 33, 77),
    Star('Kayky', 'ATA', 23, 76),
    Star('Niclas Eliasson', 'ATA', 31, 76),
  ],
  'SAN': [
    Star('Gabriel Brazão', 'GOL', 26, 80),
    Star('Diógenes', 'GOL', 25, 74),
    Star('Lucas Veríssimo', 'ZAG', 31, 79),
    Star('Luan Peres', 'ZAG', 32, 77),
    Star('Rafael Gonzaga', 'ZAG', 26, 75),
    Star('Gonzalo Escobar', 'LAT', 29, 77),
    Star('Igor Vinícius', 'LAT', 29, 77),
    Star('Gabriel Menino', 'LAT', 26, 78),
    Star('Rodinei', 'LAT', 34, 76),
    Star('Arthur', 'VOL', 30, 79),
    Star('João Schmidt', 'VOL', 33, 78),
    Star('Willian Arão', 'VOL', 34, 78),
    Star('Christian Oliva', 'VOL', 30, 76),
    Star('Neymar', 'MEI', 34, 85),
    Star('Philippe Coutinho', 'MEI', 34, 81),
    Star('Benjamín Rollheiser', 'MEI', 26, 79),
    Star('Miguel Terceros', 'MEI', 22, 76),
    Star('Gabigol', 'ATA', 30, 81),
    Star('Everton Cebolinha', 'ATA', 30, 79),
    Star('Álvaro Barreal', 'ATA', 26, 78),
    Star('Thaciano', 'ATA', 31, 77),
    Star('Rony', 'ATA', 31, 77),
  ],
  'VIT': [
    Star('Lucas Arcanjo', 'GOL', 27, 77),
    Star('Yuri Sena', 'GOL', 26, 72),
    Star('Camutanga', 'ZAG', 32, 76),
    Star('Cacá', 'ZAG', 26, 76),
    Star('Emanuel Brítez', 'ZAG', 27, 75),
    Star('Luan Cândido', 'LAT', 25, 76),
    Star('Ramon', 'LAT', 28, 75),
    Star('Nathan Mendes', 'LAT', 25, 74),
    Star('Jamerson', 'LAT', 30, 74),
    Star('Walace', 'VOL', 31, 77),
    Star('Gabriel Baralhas', 'VOL', 27, 76),
    Star('Emmanuel Martínez', 'VOL', 27, 75),
    Star('Matheuzinho', 'MEI', 28, 77),
    Star('Tomás Pochettino', 'MEI', 30, 77),
    Star('Rúben Ismael', 'MEI', 26, 75),
    Star('Renato Kayzer', 'ATA', 30, 77),
    Star('Erick', 'ATA', 29, 76),
    Star('Fabri', 'ATA', 30, 75),
    Star('Marinho', 'ATA', 36, 75),
    Star('Diego Tarzia', 'ATA', 23, 74),
  ],
  'CFC': [
    Star('Pedro Rangel', 'GOL', 25, 77),
    Star('Pedro Morisco', 'GOL', 21, 75),
    Star('Maicon', 'ZAG', 38, 76),
    Star('Tiago Cóser', 'ZAG', 30, 75),
    Star('Rodrigo Moledo', 'ZAG', 39, 74),
    Star('Fabricio Bustos', 'LAT', 30, 77),
    Star('Felipe Jonatan', 'LAT', 28, 76),
    Star('Tinga', 'LAT', 33, 75),
    Star('Bruno Melo', 'LAT', 34, 75),
    Star('Nicolás Fonseca', 'VOL', 27, 77),
    Star('Sebastián Gómez', 'VOL', 30, 76),
    Star('Vini Paulista', 'VOL', 26, 75),
    Star('Josué', 'MEI', 35, 77),
    Star('Alejandro Ararat', 'MEI', 25, 75),
    Star('Joaquín Lavega', 'ATA', 21, 76),
    Star('Brian Ocampo', 'ATA', 27, 76),
    Star('Pedro Rocha', 'ATA', 31, 76),
    Star('Breno Lopes', 'ATA', 30, 76),
    Star('Lucas Ronier', 'ATA', 21, 75),
    Star('Keno', 'ATA', 37, 74),
  ],
  'CAP': [
    Star('Mycael', 'GOL', 22, 79),
    Star('Santos', 'GOL', 36, 77),
    Star('Carlos Terán', 'ZAG', 26, 78),
    Star('Arthur Dias', 'ZAG', 23, 77),
    Star('Juan Felipe Aguirre', 'ZAG', 25, 76),
    Star('Gastón Benavídez', 'LAT', 31, 77),
    Star('Lucas Esquivel', 'LAT', 25, 77),
    Star('Léo Pelé', 'LAT', 29, 76),
    Star('Léo Derik', 'LAT', 26, 75),
    Star('Felipinho', 'VOL', 25, 77),
    Star('Juan Portilla', 'VOL', 28, 77),
    Star('Luiz Gustavo', 'VOL', 39, 76),
    Star('Jadson', 'VOL', 33, 76),
    Star('Bruno Zapelli', 'MEI', 24, 78),
    Star('Alejandro García', 'MEI', 25, 77),
    Star('João Cruz', 'MEI', 20, 75),
    Star('Kevin Viveros', 'ATA', 25, 79),
    Star('Stiven Mendoza', 'ATA', 34, 77),
    Star('Kerwin Vargas', 'ATA', 25, 77),
    Star('Leozinho', 'ATA', 28, 75),
  ],
  'CHA': [
    Star('Rafael Santos', 'GOL', 27, 75),
    Star('Anderson', 'GOL', 32, 72),
    Star('Rafael Thyere', 'ZAG', 33, 75),
    Star('Eduardo Doma', 'ZAG', 27, 73),
    Star('João Paulo', 'ZAG', 28, 73),
    Star('Mancha', 'LAT', 28, 73),
    Star('Bruno Pacheco', 'LAT', 34, 73),
    Star('Victor Caetano', 'LAT', 25, 72),
    Star('Yago Felipe', 'VOL', 31, 75),
    Star('Vinicius Balieiro', 'VOL', 27, 74),
    Star('Camilo', 'VOL', 27, 74),
    Star('Giovanni Augusto', 'MEI', 37, 74),
    Star('Max Alves', 'MEI', 25, 74),
    Star('Yannick Bolasie', 'ATA', 37, 75),
    Star('Dylan Borrero', 'ATA', 24, 75),
    Star('Marcinho', 'ATA', 31, 74),
    Star('Maurício Garcez', 'ATA', 29, 74),
    Star('Kevin Ramírez', 'ATA', 27, 73),
  ],
  'REM': [
    Star('Marcelo Rangel', 'GOL', 38, 76),
    Star('Ygor Vinhas', 'GOL', 28, 74),
    Star('Zé Ivaldo', 'ZAG', 29, 76),
    Star('Marllon', 'ZAG', 34, 75),
    Star('Duplexe Tchamba', 'ZAG', 27, 75),
    Star('Léo Andrade', 'ZAG', 25, 74),
    Star('Marlon', 'LAT', 28, 74),
    Star('Matheus Alexandre', 'LAT', 27, 74),
    Star('Cristian Tassano', 'LAT', 26, 73),
    Star('Leonel Picco', 'VOL', 27, 76),
    Star('Patrick', 'VOL', 33, 75),
    Star('Zé Welison', 'VOL', 31, 74),
    Star('Vitor Bueno', 'MEI', 32, 75),
    Star('Jáderson', 'MEI', 25, 74),
    Star('Yago Pikachu', 'ATA', 34, 76),
    Star('Gabriel Taliari', 'ATA', 28, 75),
    Star('Antonio Galeano', 'ATA', 26, 75),
    Star('Gabriel Poveda', 'ATA', 26, 74),
    Star('Jajá', 'ATA', 25, 74),
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

const List<String> kPositions = ['GOL', 'ZAG', 'LAT', 'VOL', 'MEI', 'ATA'];

/// Tamanho-alvo do elenco por posição (24 atletas).
const Map<String, int> kSquadTargets = {
  'GOL': 3,
  'ZAG': 4,
  'LAT': 4,
  'VOL': 4,
  'MEI': 4,
  'ATA': 5,
};

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

String randomName(Random rng) =>
    '${kFirstNames[rng.nextInt(kFirstNames.length)]} ${kLastNames[rng.nextInt(kLastNames.length)]}';

int _idSeq = 0;

/// Gera um id único para atletas criados durante a carreira.
String newPlayerId(Random rng) =>
    'g${DateTime.now().microsecondsSinceEpoch}_${_idSeq++}_${rng.nextInt(1000)}';

Player generatePlayer(
  Random rng, {
  required String id,
  required String position,
  required int base,
  int minAge = 18,
  int maxAge = 34,
}) {
  final int age = minAge + rng.nextInt(maxAge - minAge + 1);
  final int overall = (base + rng.nextInt(13) - 6).clamp(55, 92).toInt();
  return Player(
    id: id,
    name: randomName(rng),
    position: position,
    age: age,
    overall: overall,
    contractYears: 1 + rng.nextInt(4),
  );
}

/// Jogadores sem clube disponíveis no mercado (Fase 9).
List<Player> generateFreeAgents(Random rng, int count) {
  return [
    for (int i = 0; i < count; i++)
      generatePlayer(
        rng,
        id: newPlayerId(rng),
        position: kPositions[rng.nextInt(kPositions.length)],
        base: 66 + rng.nextInt(8),
        maxAge: 35,
      )..contractYears = 0,
  ];
}

/// Promessa da base (17-19 anos). [bonus] vem do nível do CT.
Player generateYouth(Random rng, String position, int base, int bonus) {
  final p = generatePlayer(
    rng,
    id: newPlayerId(rng),
    position: position,
    base: base - 9 + bonus,
    minAge: 17,
    maxAge: 19,
  );
  p.contractYears = 3;
  return p;
}

Team _buildTeam(ClubInfo c, Random rng) {
  final int base = baseOverallForStars(c.stars);
  final List<Star> stars = kStars[c.shortName] ?? const <Star>[];
  final String tid = c.shortName.toLowerCase();
  final List<Player> squad = [];
  int n = 1;

  for (final s in stars) {
    squad.add(Player(
      id: '${tid}_p$n',
      name: s.name,
      position: s.position,
      age: s.age,
      overall: s.overall,
      contractYears: 1 + rng.nextInt(4),
    ));
    n++;
  }

  final Map<String, int> counts = {};
  for (final s in stars) {
    counts[s.position] = (counts[s.position] ?? 0) + 1;
  }
  kSquadTargets.forEach((pos, target) {
    final int have = counts[pos] ?? 0;
    for (int i = 0; i < target - have; i++) {
      squad.add(generatePlayer(rng, id: '${tid}_p$n', position: pos, base: base - 3));
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
    capacity: c.capacity,
  );
  team.balance = initialBudget(c.stars);
  team.sponsorMonthly = baseSponsor(c.stars);
  final lvl = initialFacilityLevel(c.stars);
  team.ctLevel = lvl;
  team.stadiumLevel = 0;
  team.medicalLevel = lvl;
  return team;
}

List<Team> createLeague() {
  final rng = Random();
  return [for (final c in kClubs) _buildTeam(c, rng)];
}
