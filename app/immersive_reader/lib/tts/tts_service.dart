import 'package:flutter_tts/flutter_tts.dart';

/// Wraps flutter_tts for on-demand German pronunciation of replacement words,
/// using the OS's built-in TTS voices (Windows SAPI) so it works offline
/// with no per-word audio assets or API calls.
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _initialized = false;

  Future<void> speak(String germanText) async {
    if (!_initialized) {
      await _flutterTts.setLanguage('de-DE');
      await _flutterTts.setSpeechRate(0.5);
      _initialized = true;
    }
    await stop();
    await _flutterTts.speak(germanText);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  void dispose() {
    // fire-and-forget stop
    _flutterTts.stop();
  }
}
