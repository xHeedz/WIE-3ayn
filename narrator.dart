import 'package:flutter_tts/flutter_tts.dart';

/// The instant, on-device narration voice. Used everywhere for real-time
/// feedback so nothing waits on the network. (Backend Polly can optionally
/// voice the Ask/Find/Read answers instead — see Settings.)
class Narrator {
  Narrator._();
  static final Narrator instance = Narrator._();

  final FlutterTts _tts = FlutterTts();
  String _code = '';

  Future<void> setLang(String lang) async {
    final code = lang == 'ar' ? 'ar-SA' : 'en-US';
    if (code == _code) return;
    _code = code;
    await _tts.setLanguage(code);
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> say(String text) async {
    if (text.trim().isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
