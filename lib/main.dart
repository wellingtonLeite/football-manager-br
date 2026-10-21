import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'game/engine.dart';
import 'ui/screens.dart';
import 'ui/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carrega o save automaticamente antes de abrir a UI
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
        // A tela inicial detecta o save: "Continuar Carreira" ou "Nova Carreira".
        home: const _SaveOnPause(child: WelcomeScreen()),
      ),
    );
  }
}

/// Salva na hora quando o app vai para segundo plano (o Android pode fechá-lo).
class _SaveOnPause extends StatefulWidget {
  final Widget child;
  const _SaveOnPause({required this.child});

  @override
  State<_SaveOnPause> createState() => _SaveOnPauseState();
}

class _SaveOnPauseState extends State<_SaveOnPause> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onPause: () => context.read<GameState>().saveToDisk(),
      onInactive: () => context.read<GameState>().saveToDisk(),
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
