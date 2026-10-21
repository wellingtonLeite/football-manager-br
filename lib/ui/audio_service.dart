import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sons do jogo (apito, gol, torcida, cartão, cliques) e vibração.
/// Os efeitos ficam em assets/sounds e foram sintetizados para o jogo.
class AudioService extends ChangeNotifier {
  /// Desligado nos testes automatizados (não há player de áudio no ambiente de teste).
  static bool enabled = true;

  bool _soundOn = true;
  bool _vibrationOn = true;

  /// Milissegundos por minuto de jogo na narração ao vivo.
  int _matchSpeedMs = 200;
  static const Map<String, int> speeds = {'Lenta': 350, 'Normal': 200, 'Rápida': 100, 'Turbo': 40};

  AudioPlayer? _crowd;
  final List<AudioPlayer> _fx = [];
  int _next = 0;

  AudioService() {
    _loadPrefs();
  }

  bool get soundOn => _soundOn;
  int get matchSpeedMs => _matchSpeedMs;

  void setMatchSpeed(int ms) {
    _matchSpeedMs = ms;
    _savePrefs();
    notifyListeners();
  }
  bool get vibrationOn => _vibrationOn;

  /// Mantido para a interface antiga: "mudo" = sem som e sem vibração.
  bool get muted => !_soundOn && !_vibrationOn;

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundOn = prefs.getBool('fmbr_sound') ?? true;
      _vibrationOn = prefs.getBool('fmbr_vibration') ?? true;
      _matchSpeedMs = prefs.getInt('fmbr_speed') ?? 200;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fmbr_sound', _soundOn);
      await prefs.setBool('fmbr_vibration', _vibrationOn);
      await prefs.setInt('fmbr_speed', _matchSpeedMs);
    } catch (_) {}
  }

  void setSound(bool on) {
    _soundOn = on;
    if (!on) stopCrowd();
    _savePrefs();
    notifyListeners();
  }

  void setVibration(bool on) {
    _vibrationOn = on;
    _savePrefs();
    notifyListeners();
  }

  void toggleMute() {
    final on = muted;
    _soundOn = on;
    _vibrationOn = on;
    if (!on) stopCrowd();
    _savePrefs();
    notifyListeners();
  }

  Future<void> _play(String file, {double volume = 1.0}) async {
    if (!_soundOn || !enabled) return;
    try {
      if (_fx.length < 4) {
        final p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
        _fx.add(p);
      }
      final player = _fx[_next % _fx.length];
      _next++;
      await player.stop();
      await player.play(AssetSource('sounds/$file'), volume: volume);
    } catch (e) {
      debugPrint('Som indisponível: $e');
    }
  }

  /// Alguns aparelhos (e o ambiente de testes) não têm vibração: ignora falhas.
  Future<void> _haptic(Future<void> Function() f) async {
    if (!_vibrationOn) return;
    try {
      await f();
    } catch (_) {}
  }

  Future<void> playGoal() async {
    _play('gol.wav');
    await _haptic(HapticFeedback.heavyImpact);
    await Future.delayed(const Duration(milliseconds: 100));
    await _haptic(HapticFeedback.heavyImpact);
  }

  Future<void> playWhistle() async {
    _play('apito.wav', volume: 0.8);
    await _haptic(HapticFeedback.mediumImpact);
  }

  Future<void> playFinalWhistle() async {
    _play('apito_final.wav', volume: 0.8);
    await _haptic(HapticFeedback.mediumImpact);
  }

  Future<void> playCard() async {
    _play('cartao.wav', volume: 0.8);
    await _haptic(HapticFeedback.lightImpact);
  }

  Future<void> playInjury() async {
    _play('lesao.wav', volume: 0.7);
    await _haptic(HapticFeedback.lightImpact);
  }

  /// Murmúrio da torcida em loop durante a partida.
  Future<void> playCrowd() async {
    if (!_soundOn || !enabled) return;
    try {
      _crowd ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      await _crowd!.play(AssetSource('sounds/torcida.wav'), volume: 0.25);
    } catch (e) {
      debugPrint('Som indisponível: $e');
    }
  }

  Future<void> stopCrowd() async {
    try {
      await _crowd?.stop();
    } catch (_) {}
  }

  Future<void> playButton() async {
    _play('clique.wav', volume: 0.35);
    await _haptic(HapticFeedback.selectionClick);
  }

  @override
  void dispose() {
    _crowd?.dispose();
    for (final p in _fx) {
      p.dispose();
    }
    super.dispose();
  }
}
