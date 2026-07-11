import 'package:flutter/foundation.dart';

/// A single shared settings/state object. Screens listen to it with
/// ListenableBuilder and change it via [update]. Kept deliberately simple —
/// no external state-management package needed.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  bool onboarded = false;
  String name = '';
  String lang = 'ar'; // 'ar' | 'en' — the web app is Arabic-first

  // Backend
  String baseUrl =
      'https://pxv89q4lyk.execute-api.eu-west-2.amazonaws.com/Stage';
  bool mock = false; // ON = works on the tablet with no backend

  // Voice
  bool usePolly = false; // use backend Polly voice for Ask/Find/Read answers

  // Detection tuning (used by the real Stage-2 pose detector)
  double approachSensitivity = 0.5; // 0..1
  double handExtendThreshold = 0.15; // 0..0.5
  bool showDebug = false;

  // Privacy
  bool trustedViewer = false;

  bool get isAr => lang == 'ar';

  void update(void Function() change) {
    change();
    notifyListeners();
  }
}
