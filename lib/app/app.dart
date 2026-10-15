import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../logic/cashback_controller.dart';
import '../presentation/screens.dart';
import 'theme.dart';

class CashbackApp extends StatelessWidget {
  const CashbackApp({super.key, required this.controller});
  final CashbackController controller;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Кэшбэк рядом',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: AppShell(controller: controller),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final CashbackController controller;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  void _showImport() => setState(() => _index = 1);
  void _showManual() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ManualEntriesScreen(controller: widget.controller),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, child) => Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            HomeScreen(
              controller: widget.controller,
              onImport: _showImport,
              onManual: _showManual,
            ),
            ImportScreen(cashbackController: widget.controller),
            const SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_photo_alternate_outlined),
            selectedIcon: Icon(Icons.add_photo_alternate),
            label: 'Импорт',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Настройки',
          ),
        ],
      ),
    ),
  );
}
