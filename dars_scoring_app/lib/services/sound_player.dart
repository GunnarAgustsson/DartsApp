import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

/// Service to manage dart throw sound and haptic feedback.
class SoundPlayer {
  final AudioPlayer _audio = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  /// Plays the dart throw sound and triggers haptic feedback.
  Future<void> playDartSound() async {
    HapticFeedback.mediumImpact();
    try {
      await _audio.stop();
      await _audio.play(
        AssetSource('sound/dart_throw.mp3'),
        volume: 0.5,
      );
    } catch (e) {
      // ignore errors
    }
  }

  /// Dispose audio resources.
  void dispose() {
    _audio.dispose();
  }
}
