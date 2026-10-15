import 'package:balance_app/app/app.dart';
import 'package:balance_app/data/empty_cashback_repository.dart';
import 'package:balance_app/domain/cashback_repository.dart';
import 'package:balance_app/domain/models.dart';
import 'package:balance_app/logic/cashback_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Empty user data and navigation to import review', (
    tester,
  ) async {
    final controller = CashbackController(
      EmptyCashbackRepository(),
      initialMonth: CashbackMonth(2026, 12),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(CashbackApp(controller: controller));
    expect(
      find.text('Добавьте выбранные категории, чтобы сравнить карты.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Следующий'));
    await tester.pump();
    expect(find.text('янв. 2027'), findsOneWidget);
    await tester.ensureVisible(find.text('Мои карты и категории'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мои карты и категории'));
    await tester.pumpAndSettle();
    expect(find.text('Карт пока нет'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Импорт'));
    await tester.pumpAndSettle();
    final review = find.text('Открыть проверку импорта');
    await tester.ensureVisible(review);
    await tester.pumpAndSettle();
    await tester.tap(review);
    await tester.pumpAndSettle();
    expect(find.text('Пока нечего проверять'), findsOneWidget);
    await tester.tap(find.text('Вернуться к импорту'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки').last);
    await tester.pumpAndSettle();
    expect(find.text('Без доступа к банку'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Compact display supports large text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = CashbackController(EmptyCashbackRepository());
    addTearDown(controller.dispose);
    await tester.pumpWidget(CashbackApp(controller: controller));
    await tester.ensureVisible(find.text('Мои карты и категории'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мои карты и категории'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.arrow_back).last);
    await tester.pumpAndSettle();
    for (final label in ['Импорт', 'Настройки', 'Главная']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Manual card and category appear on home after saving', (
    tester,
  ) async {
    final repository = _MemoryRepository();
    final controller = CashbackController(
      repository,
      initialMonth: CashbackMonth(2026, 10),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(CashbackApp(controller: controller));
    await tester.tap(find.text('Мои карты и категории'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить карту'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Основная');
    await tester.tap(find.text('Сохранить').last);
    await tester.pumpAndSettle();
    expect(find.text('Альфа · Основная'), findsOneWidget);
    await tester.tap(find.text('Добавить категорию'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), 'Аптеки');
    await tester.enterText(find.byType(TextFormField).at(2), '5');
    await tester.tap(find.text('Сохранить').last);
    await tester.pumpAndSettle();
    expect(find.text('Аптеки'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back).last);
    await tester.pumpAndSettle();
    expect(find.text('Аптеки'), findsOneWidget);
    expect(repository.monthlySets.single.period, CashbackMonth(2026, 10));
  });
}

class _MemoryRepository implements WritableCashbackRepository {
  final _cards = <BankCard>[];
  final _sets = <MonthlyCashbackSet>[];
  @override
  List<BankCard> get cards => _cards;
  @override
  List<MonthlyCashbackSet> get monthlySets => _sets;
  @override
  Future<void> load() async {}
  @override
  Future<void> saveCard(BankCard card) async {
    _cards.removeWhere((item) => item.id == card.id);
    _cards.add(card);
  }

  @override
  Future<void> deleteCard(String id) async {
    _cards.removeWhere((item) => item.id == id);
    _sets.removeWhere((item) => item.cardId == id);
  }

  @override
  Future<void> saveSet(MonthlyCashbackSet set) async {
    _sets.removeWhere(
      (item) => item.cardId == set.cardId && item.period == set.period,
    );
    _sets.add(set);
  }

  @override
  Future<void> deleteSet(String cardId, CashbackMonth period) async {
    _sets.removeWhere((item) => item.cardId == cardId && item.period == period);
  }
}
