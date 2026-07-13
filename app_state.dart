import 'package:flutter/foundation.dart';

/// Voice command vocabulary recognised by MainShell's keyword matcher in
/// main.dart (English + Arabic phrases both map to these).
enum VoiceActionType { describeScene, identifyPerson, readText, findObject }

class VoiceCommand {
  const VoiceCommand(this.type, {this.objectName});
  final VoiceActionType type;
  final String? objectName;
}

/// A tiny event bus so a voice command recognised on Home (via the mic
/// FAB) can be delivered to whichever screen actually handles it
/// (Ask / Find / Read), even after main.dart has already switched the
/// bottom nav tab to get there.
class VoiceCommandBus {
  VoiceCommandBus._();
  static final ValueNotifier<VoiceCommand?> command =
      ValueNotifier<VoiceCommand?>(null);

  static void send(VoiceCommand cmd) => command.value = cmd;
}

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
