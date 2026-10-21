import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioService extends ChangeNotifier {
  bool _muted = false;

  bool get muted => _muted;

  /// Alguns aparelhos (e o ambiente de testes) não têm vibração: ignora falhas.
  Future<void> _haptic(Future<void> Function() f) async {
    if (_muted) return;
    try {
      await f();
    } catch (_) {}
  }

  Future<void> playGoal() async {
    await _haptic(HapticFeedback.heavyImpact);
    await Future.delayed(const Duration(milliseconds: 100));
    await _haptic(HapticFeedback.heavyImpact);
  }

  Future<void> playWhistle() => _haptic(HapticFeedback.mediumImpact);

  Future<void> playCard() => _haptic(HapticFeedback.lightImpact);

  Future<void> playCrowd() async {
    if (_muted) return;
    // Vibração contínua simulando torcida (não implementado para não incomodar)
  }

  Future<void> stopCrowd() async {
    // Não há nada para parar
  }

  Future<void> playButton() => _haptic(HapticFeedback.selectionClick);

  void toggleMute() {
    _muted = !_muted;
    notifyListeners();
  }
}
