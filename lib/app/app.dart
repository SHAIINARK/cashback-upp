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
  void _showImport() => setState(() => _index = 2);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, child) => Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            HomeScreen(controller: widget.controller, onImport: _showImport),
            CardsScreen(onImport: _showImport),
            const ImportScreen(),
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
            icon: Icon(Icons.credit_card_outlined),
            selectedIcon: Icon(Icons.credit_card),
            label: 'Мои карты',
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
