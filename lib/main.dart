import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'game/engine.dart';
import 'ui/screens.dart';

void main() => runApp(const FootballManagerApp());

class FootballManagerApp extends StatelessWidget {
  const FootballManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameState(),
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
    final started = context.watch<GameState>().started;
    return started ? const HomeScreen() : const TeamSelectScreen();
  }
}
