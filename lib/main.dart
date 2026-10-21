import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'game/engine.dart';
import 'ui/screens.dart';
import 'ui/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Tenta carregar o jogo salvo antes de iniciar a UI
  final savedGame = await GameState.loadFromDisk();
  
  runApp(FootballManagerApp(initialState: savedGame));
}

class FootballManagerApp extends StatelessWidget {
  final GameState? initialState;

  const FootballManagerApp({super.key, this.initialState});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioService()),
        ChangeNotifierProvider<GameState>(
          create: (_) => initialState ?? GameState(),
        ),
      ],
      child: MaterialApp(
        title: 'Football Manager BR',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1B5E20),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const RootScreen(),
      ),
    );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    
    if (!game.started) {
      return const WelcomeScreen();
    }
    
    return const HomeScreen();
  }
}