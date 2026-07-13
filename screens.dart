import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'app_state.dart';
import 'api_service.dart';
import 'narrator.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

final ImagePicker _picker = ImagePicker();

ApiService get _api =>
    ApiService(baseUrl: AppState.instance.baseUrl, mock: AppState.instance.mock);

Future<String?> _capturePhoto() async {
  final XFile? shot = await _picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 70,
    maxWidth: 1600,
  );
  if (shot == null) return null;
  return base64Encode(await shot.readAsBytes());
}

/// Capture a photo, run [action], then narrate + return the result.
/// [onStatus] receives progress text; [onResult] receives the final answer.
Future<void> _runVisionAction({
  required Future<String> Function(String imageB64, String lang) action,
  required void Function(String status) onStatus,
  required void Function(String result) onResult,
}) async {
  final s = AppState.instance;
  HapticFeedback.mediumImpact();
  onStatus(s.isAr ? 'افتح الكاميرا…' : 'Opening camera…');
  await Narrator.instance.say(s.isAr ? 'التقط صورة' : 'Take a photo');

  try {
    final b64 = await _capturePhoto();
    if (b64 == null) {
      onStatus('');
      await Narrator.instance.say(s.isAr ? 'أُلغيت' : 'Cancelled');
      return;
    }
    onStatus(s.isAr ? 'جارٍ التحليل…' : 'Analysing…');
    final result = await action(b64, s.lang);
    HapticFeedback.lightImpact();
    onResult(result);
    await Narrator.instance.say(result);
  } catch (_) {
    onStatus(s.isAr ? 'حدث خطأ' : 'Something went wrong');
    await Narrator.instance.say(
      s.isAr ? 'تعذّر إكمال الطلب. تحقّق من الاتصال.' : 'That did not work. Check the connection.',
    );
  }
}

/// A big, high-contrast, screen-reader-labelled action button.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.height = 96,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                const SizedBox(width: 20),
                Icon(icon, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small section header, matching the web app's eyebrow labels.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onboarding
// ---------------------------------------------------------------------------

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  String _lang = 'ar';

  @override
  Widget build(BuildContext context) {
    final ar = _lang == 'ar';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Text('👁', style: TextStyle(fontSize: 72), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(
                ar ? 'أهلاً بك في عين' : 'Welcome to 3ayn',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                ar
                    ? 'قل لنا اسمك حتى يرحّب بك الصوت.'
                    : 'Tell us your name so narration can greet you.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 28),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  ChoiceChip(
                    label: const Text('العربية'),
                    selected: _lang == 'ar',
                    onSelected: (_) => setState(() => _lang = 'ar'),
                  ),
                  ChoiceChip(
                    label: const Text('English'),
                    selected: _lang == 'en',
                    onSelected: (_) => setState(() => _lang = 'en'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameCtrl,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: ar ? 'اسمك' : 'Your name',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  AppState.instance.update(() {
                    AppState.instance.name = _nameCtrl.text.trim();
                    AppState.instance.lang = _lang;
                    AppState.instance.onboarded = true;
                  });
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: Text(
                  ar ? 'ابدأ' : 'Get started',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home — live view + always-listening social narration
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _listening = false;
  int _people = 0;
  String _lastNarration = '';
  final List<String> _log = [];
  Timer? _timer;
  final _rng = Random();

  // Sample social events used in mock mode. In Stage 2 these come from the
  // real on-device pose detector instead of a timer.
  List<String> get _samples => AppState.instance.isAr
      ? [
          'شخص يقترب من يمينك.',
          'شخص يلوّح لك.',
          'شخص يمدّ يده للمصافحة.',
          'شخص يقف أمامك.',
        ]
      : [
          'Someone is approaching from your right.',
          'A person is waving at you.',
          'Someone is extending a hand to shake.',
          'A person is standing in front of you.',
        ];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleListening(bool on) {
    setState(() => _listening = on);
    final s = AppState.instance;
    if (on) {
      Narrator.instance.say(s.isAr ? 'المراقبة تعمل.' : 'Now watching.');
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => _emitEvent());
    } else {
      _timer?.cancel();
      setState(() => _people = 0);
      Narrator.instance.say(s.isAr ? 'توقّفت المراقبة.' : 'Stopped watching.');
    }
  }

  void _emitEvent() {
    final event = _samples[_rng.nextInt(_samples.length)];
    setState(() {
      _people = 1 + _rng.nextInt(3);
      _lastNarration = event;
      _log.insert(0, event);
      if (_log.length > 8) _log.removeLast();
    });
    Narrator.instance.say(event); // instant on-device voice
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final ar = s.isAr;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Text('👁', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ar ? 'مراقبة دائمة' : 'Always listening',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(
                    _listening
                        ? (ar ? 'الذكاء يعمل' : 'AI active')
                        : (ar ? 'متوقّف' : 'AI idle'),
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
            Switch(value: _listening, onChanged: _toggleListening),
          ],
        ),
        const SizedBox(height: 16),
        const SectionLabel('Last narration'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _lastNarration.isEmpty
                ? (ar ? 'لا شيء بعد' : 'Nothing narrated yet')
                : _lastNarration,
            style: const TextStyle(fontSize: 18),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
                child: BigButton(
                    label: ar ? 'اسأل' : 'Ask',
                    icon: Icons.mic,
                    height: 72,
                    onTap: () => _quick('ask'))),
            const SizedBox(width: 12),
            Expanded(
                child: BigButton(
                    label: ar ? 'دلّني' : 'Find',
                    icon: Icons.search,
                    height: 72,
                    onTap: () => _quick('find'))),
          ],
        ),
        const SizedBox(height: 12),
        BigButton(
            label: ar ? 'اقرأ' : 'Read', icon: Icons.menu_book, height: 72, onTap: () => _quick('read')),
        const SizedBox(height: 20),
        const SectionLabel('Live view'),
        Container(
          height: 150,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            _listening
                ? (ar ? '● مراقبة… (محاكاة)' : '● Watching… (simulated)')
                : (ar ? 'شغّل المراقبة للبدء' : 'Turn on Always listening to start'),
            style: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${ar ? 'أشخاص' : 'People'}: $_people'
          '${s.showDebug ? '  ·  ratio ${s.approachSensitivity.toStringAsFixed(2)}  ·  Δz ${s.handExtendThreshold.toStringAsFixed(2)}' : ''}',
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Event log'),
        if (_log.isEmpty)
          Text(ar ? 'لا أحداث بعد' : 'No events yet',
              style: TextStyle(color: Theme.of(context).hintColor))
        else
          ..._log.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('• $e'),
              )),
      ],
    );
  }

  Future<void> _quick(String mode) async {
    await _runVisionAction(
      action: (b64, lang) {
        switch (mode) {
          case 'find':
            return _api.find(b64, lang, 'object');
          case 'read':
            return _api.readText(b64, lang);
          case 'ask':
          default:
            return _api.describeScene(b64, lang);
        }
      },
      onStatus: (status) => setState(() => _lastNarration = status.isEmpty ? _lastNarration : status),
      onResult: (result) => setState(() {
        _lastNarration = result;
        _log.insert(0, result);
        if (_log.length > 8) _log.removeLast();
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Ask
// ---------------------------------------------------------------------------

class AskScreen extends StatefulWidget {
  const AskScreen({super.key});
  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  String _status = '';

  @override
  void initState() {
    super.initState();
    VoiceCommandBus.command.addListener(_handleVoiceCommand);
  }

  @override
  void dispose() {
    VoiceCommandBus.command.removeListener(_handleVoiceCommand);
    super.dispose();
  }

  void _handleVoiceCommand() {
    final command = VoiceCommandBus.command.value;
    if (command == null) return;

    if (command.type == VoiceActionType.describeScene) {
      VoiceCommandBus.command.value = null;
      _go(_api.describeScene);
    } else if (command.type == VoiceActionType.identifyPerson) {
      VoiceCommandBus.command.value = null;
      _go(_api.whoIsThis);
    }
  }

  @override
  Widget build(BuildContext context) {

  @override
  Widget build(BuildContext context) {
    final ar = AppState.instance.isAr;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(ar ? 'اسأل' : 'Ask',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        BigButton(
          label: ar ? 'صف ما حولي' : 'Describe my surroundings',
          icon: Icons.mic,
          onTap: () => _go(_api.describeScene),
        ),
        const SizedBox(height: 16),
        BigButton(
          label: ar ? 'من أمامي؟' : 'Who is in front of me?',
          icon: Icons.face,
          onTap: () => _go(_api.whoIsThis),
        ),
        const SizedBox(height: 24),
        _ResultBox(_status),
        const SizedBox(height: 12),
        Text(
          ar
              ? 'يستخدم Bedrock للوصف و Rekognition للتعرّف على الوجوه.'
              : 'Uses Bedrock for the scene and Rekognition for faces.',
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
        ),
      ],
    );
  }

  void _go(Future<String> Function(String, String) action) {
    _runVisionAction(
      action: action,
      onStatus: (s) => setState(() => _status = s),
      onResult: (r) => setState(() => _status = r),
    );
  }
}

// ---------------------------------------------------------------------------
// Find
// ---------------------------------------------------------------------------

class FindScreen extends StatefulWidget {
  const FindScreen({super.key});
  @override
  State<FindScreen> createState() => _FindScreenState();
}

class _FindScreenState extends State<FindScreen> {
  String _status = '';
  int _selected = 0;

  // (English label, Arabic label)
  static const _targets = [
    ['Bottle', 'قنينة'],
    ['Phone', 'هاتف'],
    ['Cup', 'كوب'],
    ['Chair', 'كرسي'],
    ['Door', 'باب'],
    ['Bag', 'حقيبة'],
  ];

  @override
void initState() {
  super.initState();
  VoiceCommandBus.command.addListener(_handleVoiceCommand);
}

@override
void dispose() {
  VoiceCommandBus.command.removeListener(_handleVoiceCommand);
  super.dispose();
}

void _handleVoiceCommand() {
  final command = VoiceCommandBus.command.value;

  if (command == null ||
      command.type != VoiceActionType.findObject ||
      command.objectName == null) {
    return;
  }

  final targetIndex = _targets.indexWhere(
    (target) =>
        target[0].toLowerCase() == command.objectName!.toLowerCase(),
  );

  if (targetIndex == -1) return;

  VoiceCommandBus.command.value = null;

  setState(() {
    _selected = targetIndex;
  });

  _findTarget(_targets[targetIndex][0]);
}

void _findTarget(String target) {
  _runVisionAction(
    action: (b64, lang) => _api.find(b64, lang, target),
    onStatus: (s) => setState(() => _status = s),
    onResult: (r) => setState(() => _status = r),
  );
}
  
  @override
  Widget build(BuildContext context) {
    final ar = AppState.instance.isAr;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(ar ? 'دلّني' : 'Find',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < _targets.length; i++)
              ChoiceChip(
                label: Text(ar ? _targets[i][1] : _targets[i][0],
                    style: const TextStyle(fontSize: 16)),
                selected: _selected == i,
                onSelected: (_) => setState(() => _selected = i),
              ),
          ],
        ),
        const SizedBox(height: 24),
        BigButton(
          label: ar ? 'دلّني عليه' : 'Find it',
          icon: Icons.search,
          onTap: () => _findTarget(_targets[_selected][0]),
          ),
        ),
        const SizedBox(height: 24),
        _ResultBox(_status),
        const SizedBox(height: 12),
        Text(
          ar
              ? 'Rekognition DetectLabels مع اتجاه (يسار/يمين/أمام).'
              : 'Rekognition DetectLabels with direction (left / right / ahead).',
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Read
// ---------------------------------------------------------------------------

class ReadScreen extends StatefulWidget {
  const ReadScreen({super.key});
  @override
  State<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends State<ReadScreen> {
  String _status = '';
    @override
  void initState() {
    super.initState();
    VoiceCommandBus.command.addListener(_handleVoiceCommand);
  }

  @override
  void dispose() {
    VoiceCommandBus.command.removeListener(_handleVoiceCommand);
    super.dispose();
  }

  void _handleVoiceCommand() {
    final command = VoiceCommandBus.command.value;

    if (command == null || command.type != VoiceActionType.readText) {
      return;
    }

    VoiceCommandBus.command.value = null;
    _readText();
  }

  void _readText() {
    _runVisionAction(
      action: _api.readText,
      onStatus: (s) => setState(() => _status = s),
      onResult: (r) => setState(() => _status = r),
    );
  }
  

  @override
  Widget build(BuildContext context) {
    final ar = AppState.instance.isAr;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(ar ? 'اقرأ' : 'Read',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        BigButton(
          label: ar ? 'اقرأ لي النص أمامي' : 'Read the text in front of me',
          icon: Icons.menu_book,
          onTap: _readText,
          ),
        ),
        const SizedBox(height: 24),
        _ResultBox(_status),
        const SizedBox(height: 12),
        Text(
          ar
              ? 'Amazon Textract — لافتات، قوائم، وثائق. ثبّت النص أمام الكاميرا.'
              : 'Amazon Textract — signs, menus, documents. Hold the text steady.',
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
        ),
      ],
    );
  }
}

class _ResultBox extends StatelessWidget {
  const _ResultBox(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final ar = AppState.instance.isAr;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text.isEmpty ? (ar ? 'اضغط زراً لتبدأ' : 'Tap a button to start') : text,
        style: const TextStyle(fontSize: 18, height: 1.4),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlCtrl =
      TextEditingController(text: AppState.instance.baseUrl);
  final _enrollNameCtrl = TextEditingController();
  String? _enrollFace; // base64 of captured face

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final ar = s.isAr;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(ar ? 'الإعدادات' : 'Settings',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),

        const SizedBox(height: 8),
        const SectionLabel('Voice & language'),
        Wrap(
          spacing: 12,
          children: [
            ChoiceChip(
              label: const Text('العربية'),
              selected: s.lang == 'ar',
              onSelected: (_) {
                s.update(() => s.lang = 'ar');
                Narrator.instance.setLang('ar');
              },
            ),
            ChoiceChip(
              label: const Text('English'),
              selected: s.lang == 'en',
              onSelected: (_) {
                s.update(() => s.lang = 'en');
                Narrator.instance.setLang('en');
              },
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(ar ? 'استخدم صوت Polly (من الخادم)' : 'Use Polly voice (backend)'),
          value: s.usePolly,
          onChanged: (v) => s.update(() => s.usePolly = v),
        ),
        Text(
          ar
              ? 'الأحداث الاجتماعية اللحظية تستخدم الصوت الفوري على الجهاز دائماً؛ Polly للإجابات فقط.'
              : 'Live social events always use the instant on-device voice — Polly voices Ask/Find/Read answers only.',
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
        ),

        const SizedBox(height: 20),
        const SectionLabel('Detection tuning'),
        Text(ar ? 'حساسية الاقتراب' : 'Approach sensitivity',
            style: const TextStyle(fontSize: 14)),
        Slider(
          value: s.approachSensitivity,
          onChanged: (v) => s.update(() => s.approachSensitivity = v),
        ),
        Text(ar ? 'عتبة مدّ اليد (Δz)' : 'Hand-extend threshold (Δz)',
            style: const TextStyle(fontSize: 14)),
        Slider(
          value: s.handExtendThreshold,
          max: 0.5,
          onChanged: (v) => s.update(() => s.handExtendThreshold = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(ar ? 'إظهار قيم التصحيح' : 'Show debug values'),
          value: s.showDebug,
          onChanged: (v) => s.update(() => s.showDebug = v),
        ),

        const SizedBox(height: 20),
        const SectionLabel('Backend'),
        TextField(
          controller: _urlCtrl,
          decoration: InputDecoration(
            labelText: ar ? 'رابط الخادم' : 'Backend URL',
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => s.update(() => s.baseUrl = v.trim()),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(ar ? 'وضع المحاكاة (بدون خادم)' : 'Mock mode (no backend)'),
          value: s.mock,
          onChanged: (v) => s.update(() => s.mock = v),
        ),

        const SizedBox(height: 20),
        const SectionLabel('Trusted viewer'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(ar ? 'السماح لشخص موثوق بالمشاهدة' : 'Allow a trusted person to watch'),
          value: s.trustedViewer,
          onChanged: (v) => s.update(() => s.trustedViewer = v),
        ),
        Text(
          ar
              ? 'مطفأ افتراضياً. عند التشغيل تُشارَك صورة ثابتة من الكاميرا تُحدَّث كل بضع ثوانٍ — ليست فيديو. أطفئه لإلغاء الوصول فوراً.'
              : 'Off by default. When on, it shares a still frame refreshed every few seconds — not full video. Turn off any time to revoke instantly.',
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
        ),

        const SizedBox(height: 20),
        const SectionLabel('Caregiver — enroll a known person'),
        BigButton(
          label: _enrollFace == null
              ? (ar ? 'التقط وجهاً من الكاميرا' : 'Capture face from camera')
              : (ar ? 'تم التقاط الصورة ✓' : 'Face captured ✓'),
          icon: Icons.camera_alt,
          height: 72,
          onTap: () async {
            final b64 = await _capturePhoto();
            if (b64 != null) setState(() => _enrollFace = b64);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _enrollNameCtrl,
          decoration: InputDecoration(
            labelText: ar ? 'اسم الشخص' : "Person's name",
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            if (_enrollFace == null || _enrollNameCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ar ? 'التقط وجهاً وأدخل اسماً أولاً.' : 'Capture a face and enter a name first.'),
              ));
              return;
            }
            final msg = await _api.enroll(_enrollFace!, s.lang, _enrollNameCtrl.text.trim());
            Narrator.instance.say(msg);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              setState(() {
                _enrollFace = null;
                _enrollNameCtrl.clear();
              });
            }
          },
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(ar ? 'سجّل الشخص' : 'Enroll'),
        ),
        Text(
          ar
              ? 'فقط الأشخاص المسجّلون عمداً تتم مطابقتهم. الغرباء لا يُخزَّنون أبداً.'
              : 'Only deliberately enrolled people are ever matched. Strangers are never stored.',
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
