import 'package:balance_app/domain/cashback_repository.dart';
import 'package:balance_app/domain/models.dart';
import 'package:balance_app/domain/ocr_models.dart';
import 'package:balance_app/logic/cashback_controller.dart';
import 'package:balance_app/logic/bank_screenshot_parser.dart';
import 'package:balance_app/logic/import_period.dart';
import 'package:balance_app/logic/ocr_import_controller.dart';
import 'package:balance_app/presentation/ocr_confirmation_screen.dart';
import 'package:balance_app/presentation/ocr_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Clear OCR rows are preselected, saved after confirmation', (
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
    expect(find.text('Категории · отмечено 1'), findsOneWidget);
    final monthPicker = tester.widget<DropdownButton<CashbackMonth>>(
      find.byType(DropdownButton<CashbackMonth>),
    );
    expect(monthPicker.items, hasLength(3));
    expect(repository.monthlySets, isEmpty);
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

  testWidgets('Guessed bank is prefilled but confirmed before batch save', (
    tester,
  ) async {
    final repository = _MemoryRepository();
    final controller = CashbackController(repository);
    addTearDown(controller.dispose);
    final document = OcrDocument(
      lines: [
        OcrLine(
          text:
              'Категории на ${importMonthLabel(CashbackMonth.current()).toLowerCase()}',
          left: .1,
          top: .2,
          right: .8,
          bottom: .22,
        ),
        const OcrLine(
          text: '5% Аптеки',
          left: .1,
          top: .4,
          right: .8,
          bottom: .42,
        ),
      ],
      width: 1080,
      height: 2400,
      engine: 'test',
      elapsedMs: 1,
    );
    final draft = BankScreenshotParser().parse(document);
    expect(draft.bankIsGuess, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: ImportReviewScreen(
          results: [
            ScreenshotResult(
              path: 'private-preview',
              document: document,
              draft: draft,
            ),
          ],
          controller: controller,
        ),
      ),
    );
    expect(find.text('Ozon Банк'), findsOneWidget);
    await tester.ensureVisible(find.text('Завершить проверку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Завершить проверку'));
    await tester.pumpAndSettle();
    expect(find.text('Проверьте банк'), findsOneWidget);
    expect(repository.monthlySets, isEmpty);
    await tester.tap(find.text('Банк верный, сохранить'));
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
  Future<void> saveImportBatch({
    required List<BankCard> newCards,
    required List<MonthlyCashbackSet> sets,
  }) async {
    cards.addAll(newCards);
    for (final set in sets) {
      await saveSet(set);
    }
  }

  @override
  Future<void> deleteSet(String cardId, CashbackMonth period) async =>
      monthlySets.removeWhere(
        (item) => item.cardId == cardId && item.period == period,
      );
}
