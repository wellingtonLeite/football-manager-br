import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  bool _muted = false;
  bool _crowdPlaying = false;

  bool get muted => _muted;

  Future<void> playGoal() async {
    if (_muted) return;
    await _player.stop();
    await _player.play(AssetSource('sounds/goal.mp3'));
  }

  Future<void> playWhistle() async {
    if (_muted) return;
    await _player.stop();
    await _player.play(AssetSource('sounds/whistle.mp3'));
  }

  Future<void> playCard() async {
    if (_muted) return;
    await _player.stop();
    await _player.play(AssetSource('sounds/card.mp3'));
  }

  Future<void> playCrowd() async {
    if (_muted || _crowdPlaying) return;
    _crowdPlaying = true;
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/crowd.mp3'));
    notifyListeners();
  }

  Future<void> stopCrowd() async {
    _crowdPlaying = false;
    await _player.stop();
    notifyListeners();
  }

  Future<void> playButton() async {
    if (_muted) return;
    await _player.play(AssetSource('sounds/button.mp3'));
  }

  void toggleMute() {
    _muted = !_muted;
    if (_muted) {
      stopCrowd();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}