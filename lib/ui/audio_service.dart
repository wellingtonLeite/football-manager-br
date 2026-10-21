import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioService extends ChangeNotifier {
  bool _muted = false;

  bool get muted => _muted;

  Future<void> playGoal() async {
    if (_muted) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  Future<void> playWhistle() async {
    if (_muted) return;
    await HapticFeedback.mediumImpact();
  }

  Future<void> playCard() async {
    if (_muted) return;
    await HapticFeedback.lightImpact();
  }

  Future<void> playCrowd() async {
    // Vibração contínua simulando torcida (não implementado para não incomodar)
    if (_muted) return;
    // Poderia adicionar vibração periódica aqui se desejar
  }

  Future<void> stopCrowd() async {
    // Não há nada para parar
  }

  Future<void> playButton() async {
    if (_muted) return;
    await HapticFeedback.selectionClick();
  }

  void toggleMute() {
    _muted = !_muted;
    notifyListeners();
  }
}