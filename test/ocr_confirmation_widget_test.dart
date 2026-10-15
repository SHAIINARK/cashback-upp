import 'package:balance_app/domain/cashback_repository.dart';
import 'package:balance_app/domain/models.dart';
import 'package:balance_app/domain/ocr_models.dart';
import 'package:balance_app/logic/cashback_controller.dart';
import 'package:balance_app/logic/ocr_import_controller.dart';
import 'package:balance_app/presentation/ocr_confirmation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('OCR preview is saved only after marking and confirming', (
    tester,
  ) async {
    final repository = _MemoryRepository();
    repository.cards.add(
      BankCard(
        id: 'a1',
        bank: Bank.alfa,
        name: 'Основная',
        rewardType: RewardType.rubles,
      ),
    );
    final controller = CashbackController(repository);
    addTearDown(controller.dispose);
    final result = ScreenshotResult(
      path: 'private-preview',
      draft: ParsedScreenshot(
        bank: Bank.alfa,
        month: 10,
        year: null,
        categories: [const ParsedCategory(originalName: 'Аптеки', percent: 5)],
        warnings: const [],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OcrConfirmationScreen(
          result: result,
          controller: controller,
          initialBank: Bank.alfa,
        ),
      ),
    );
    expect(find.text('Категории · отмечено 0'), findsOneWidget);
    expect(repository.monthlySets, isEmpty);
    await tester.enterText(find.byType(TextField).first, '2026');
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('Проверить и сохранить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Проверить и сохранить'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(repository.monthlySets, isEmpty);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Основная').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Проверить и сохранить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Проверить и сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Сохранить категории?'), findsOneWidget);
    expect(repository.monthlySets, isEmpty);
    await tester.tap(find.text('Сохранить').last);
    await tester.pumpAndSettle();
    expect(
      repository.monthlySets.single.categories.single.originalName,
      'Аптеки',
    );
  });
}

class _MemoryRepository implements WritableCashbackRepository {
  @override
  final List<BankCard> cards = [];
  @override
  final List<MonthlyCashbackSet> monthlySets = [];
  @override
  Future<void> load() async {}
  @override
  Future<void> saveCard(BankCard card) async => cards.add(card);
  @override
  Future<void> deleteCard(String id) async =>
      cards.removeWhere((card) => card.id == id);
  @override
  Future<void> saveSet(MonthlyCashbackSet set) async {
    monthlySets.removeWhere(
      (item) => item.cardId == set.cardId && item.period == set.period,
    );
    monthlySets.add(set);
  }

  @override
  Future<void> deleteSet(String cardId, CashbackMonth period) async =>
      monthlySets.removeWhere(
        (item) => item.cardId == cardId && item.period == period,
      );
}
