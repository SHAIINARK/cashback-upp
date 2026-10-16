import 'package:balance_app/app/app.dart';
import 'package:balance_app/data/empty_cashback_repository.dart';
import 'package:balance_app/domain/cashback_repository.dart';
import 'package:balance_app/domain/models.dart';
import 'package:balance_app/logic/cashback_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Empty user data and navigation to import', (tester) async {
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
    expect(find.text('янв.'), findsOneWidget);
    await tester.ensureVisible(find.text('Мои карты и категории'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мои карты и категории'));
    await tester.pumpAndSettle();
    expect(find.text('Карт пока нет'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Импорт'));
    await tester.pumpAndSettle();
    expect(find.text('Открыть проверку импорта'), findsNothing);
    expect(find.text('Выбрать скриншоты'), findsOneWidget);
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
    await tester.enterText(find.byType(TextFormField).first, 'Аптеки');
    await tester.enterText(find.byType(TextFormField).at(1), '5');
    await tester.tap(find.text('Сохранить').last);
    await tester.pumpAndSettle();
    expect(find.text('Аптеки'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back).last);
    await tester.pumpAndSettle();
    expect(find.text('Аптеки'), findsOneWidget);
    expect(repository.monthlySets.single.period, CashbackMonth(2026, 10));
  });

  testWidgets(
    'Home search keeps banks and bonuses distinct for selected month',
    (tester) async {
      final repository = _MemoryRepository();
      final alfa = BankCard(
        id: 'alfa',
        bank: Bank.alfa,
        name: 'Дебетовая',
        rewardType: RewardType.rubles,
      );
      final sber = BankCard(
        id: 'sber',
        bank: Bank.sber,
        name: 'Основная',
        rewardType: RewardType.sberSpasibo,
      );
      await repository.saveCard(alfa);
      await repository.saveCard(sber);
      await repository.saveSet(
        MonthlyCashbackSet(
          cardId: alfa.id,
          period: CashbackMonth(2026, 10),
          confirmedAt: DateTime.utc(2026, 10, 1),
          categories: [
            CashbackCategory(
              id: 'a1',
              originalName: 'Аптеки',
              percent: 5,
              rewardType: RewardType.rubles,
            ),
          ],
        ),
      );
      await repository.saveSet(
        MonthlyCashbackSet(
          cardId: sber.id,
          period: CashbackMonth(2026, 10),
          confirmedAt: DateTime.utc(2026, 10, 1),
          categories: [
            CashbackCategory(
              id: 's1',
              originalName: 'Аптеки',
              percent: 7,
              rewardType: RewardType.sberSpasibo,
            ),
          ],
        ),
      );
      final controller = CashbackController(
        repository,
        initialMonth: CashbackMonth(2026, 10),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(CashbackApp(controller: controller));
      await tester.enterText(
        find.widgetWithText(TextField, 'Найти категорию'),
        'аптеки',
      );
      await tester.pump();
      expect(find.text('Аптеки'), findsNWidgets(2));
      expect(find.textContaining('Альфа · Дебетовая'), findsOneWidget);
      expect(find.textContaining('Сбер · Основная'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Найти категорию'),
        'сбер',
      );
      await tester.pump();
      expect(find.text('Аптеки'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Найти категорию'),
        'нет',
      );
      await tester.pump();
      expect(find.text('По вашему запросу ничего не найдено.'), findsOneWidget);
      await tester.tap(find.byTooltip('Очистить поиск'));
      await tester.pump();
      await tester.tap(find.text('Следующий'));
      await tester.pump();
      expect(find.text('Аптеки'), findsNothing);
    },
  );
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
  Future<void> saveImportBatch({
    required List<BankCard> newCards,
    required List<MonthlyCashbackSet> sets,
  }) async {
    _cards.addAll(newCards);
    for (final set in sets) {
      await saveSet(set);
    }
  }

  @override
  Future<void> deleteSet(String cardId, CashbackMonth period) async {
    _sets.removeWhere((item) => item.cardId == cardId && item.period == period);
  }
}
