import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'app_state.dart';
import 'narrator.dart';
import 'screens.dart';

void main() => runApp(const ThreeAynApp());

class ThreeAynApp extends StatelessWidget {
  const ThreeAynApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '3ayn عين',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A7D6B),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF07110F),
      ),
      home: const Root(),
    );
  }
}

class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) => AppState.instance.onboarded
          ? const MainShell()
          : const OnboardingScreen(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  
  @override
  void initState() {
    super.initState();
    _initSpeech();
    final s = AppState.instance;
    Narrator.instance.setLang(s.lang).then((_) {
      Narrator.instance.say(
        s.isAr ? 'مرحباً ${s.name}. عين جاهزة.' : 'Hello ${s.name}. 3ayn is ready.',
      );
    });
  }
Future<void> _initSpeech() async {
  final available = await _speech.initialize();

  if (!mounted) return;

  setState(() {
    _speechAvailable = available;
  });
}
  void _handleVoiceCommand(String words) {
  final command = words
      .toLowerCase()
      .trim()
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا');

  int? page;

  if (command.contains('home') || command.contains('الرئيسية')) {
    page = 0;
  } else if (command.contains('ask') || command.contains('اسال')) {
    page = 1;
  } else if (command.contains('find') ||
      command.contains('دلني') ||
      command.contains('ابحث')) {
    page = 2;
  } else if (command.contains('read') || command.contains('اقرا')) {
    page = 3;
  } else if (command.contains('settings') ||
      command.contains('الاعدادات')) {
    page = 4;
  }

  if (page != null && mounted) {
    setState(() {
      _index = page!;
    });
  }
}
Future<void> _toggleListening() async {
  if (!_speechAvailable) {
    await _initSpeech();
    if (!_speechAvailable) return;
  }

  if (_isListening) {
    await _speech.stop();

    if (!mounted) return;
    setState(() {
      _isListening = false;
    });
  } else {
    await _speech.listen(
      localeId: AppState.instance.isAr ? 'ar_LB' : 'en_US',
      onResult: (result) {
        if (result.finalResult) {
          _handleVoiceCommand(result.recognizedWords);

          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
        }
      },
    );

    if (!mounted) return;
    setState(() {
      _isListening = true;
    });
  }
}
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final ar = AppState.instance.isAr;
        const pages = [
          HomeScreen(),
          AskScreen(),
          FindScreen(),
          ReadScreen(),
          SettingsScreen(),
        ];
        return Scaffold(
          body: SafeArea(child: pages[_index]),
          floatingActionButton: FloatingActionButton(
            onPressed: _toggleListening,
            tooltip: ar ? 'الأوامر الصوتية' : 'Voice commands',
            child: Icon(_isListening ? Icons.stop : Icons.mic),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: ar ? 'الرئيسية' : 'Home'),
              NavigationDestination(
                  icon: const Icon(Icons.mic_none),
                  selectedIcon: const Icon(Icons.mic),
                  label: ar ? 'اسأل' : 'Ask'),
              NavigationDestination(
                  icon: const Icon(Icons.search),
                  label: ar ? 'دلّني' : 'Find'),
              NavigationDestination(
                  icon: const Icon(Icons.menu_book_outlined),
                  selectedIcon: const Icon(Icons.menu_book),
                  label: ar ? 'اقرأ' : 'Read'),
              NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: ar ? 'الإعدادات' : 'Settings'),
            ],
          ),
        );
      },
    );
  }
}
