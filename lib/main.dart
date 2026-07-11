import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    final s = AppState.instance;
    Narrator.instance.setLang(s.lang).then((_) {
      Narrator.instance.say(
        s.isAr ? 'مرحباً ${s.name}. عين جاهزة.' : 'Hello ${s.name}. 3ayn is ready.',
      );
    });
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
