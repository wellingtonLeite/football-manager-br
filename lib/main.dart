import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const FootballManagerApp());
}

class FootballManagerApp extends StatelessWidget {
  const FootballManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Football Manager BR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20), // Verde futebol
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.robotoTextTheme(),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '⚽ Football Manager BR',
          style: GoogleFonts.oswald(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 4,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B5E20), Color(0xFF000000)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sports_soccer, size: 80, color: Colors.white70),
                const SizedBox(height: 24),
                Text(
                  'Bem-vindo, Técnico!',
                  style: GoogleFonts.oswald(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gerencie seu clube rumo à glória nas 4 divisões do futebol brasileiro.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 40),
                _buildMenuButton(context, '🏆 Iniciar Campeonato', Colors.green),
                const SizedBox(height: 16),
                _buildMenuButton(context, '👥 Elenco', Colors.blue),
                const SizedBox(height: 16),
                _buildMenuButton(context, '📊 Tabela de Classificação', Colors.orange),
                const SizedBox(height: 16),
                _buildMenuButton(context, '💰 Finanças', Colors.purple),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, String text, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Funcionalidade "$text" em desenvolvimento!')),
          );
        },
        child: Text(
          text,
          style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
