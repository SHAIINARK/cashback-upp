import 'dart:io';

import 'package:balance_app/data/local_cashback_repository.dart';
import 'package:balance_app/domain/models.dart';
import 'package:balance_app/domain/ocr_models.dart';
import 'package:balance_app/logic/cashback_controller.dart';
import 'package:balance_app/logic/import_review_draft.dart';
import 'package:balance_app/logic/import_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Month infers a nearby year without asking the user', () {
    expect(importPeriod(1, now: DateTime(2026, 12)), CashbackMonth(2027, 1));
    expect(importPeriod(12, now: DateTime(2026, 1)), CashbackMonth(2025, 12));
  });

  test(
    'One-tap import creates a bank card and preserves prior data on conflict',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cashback-quick-test-',
      );
      try {
        final repository = LocalCashbackRepository(directory: directory);
        await repository.load();
        final controller = CashbackController(repository);
        addTearDown(controller.dispose);
        final period = CashbackMonth(2026, 10);
        CashbackCategory category(String id, double rate) => CashbackCategory(
          id: id,
          originalName: 'Аптеки',
          percent: rate,
          rewardType: RewardType.rubles,
        );
        await controller.saveQuickImport([
          QuickImportItem(
            bank: Bank.ozon,
            period: period,
            categories: [category('a', 5)],
          ),
        ]);
        expect(repository.cards.single.bank, Bank.ozon);
        expect(repository.monthlySets.single.categories.single.percent, 5);
        await controller.saveQuickImport([
          QuickImportItem(
            bank: Bank.ozon,
            period: period,
            categories: [category('b', 5)],
          ),
        ]);
        expect(repository.monthlySets.single.categories.length, 1);
        await expectLater(
          controller.saveQuickImport([
            QuickImportItem(
              bank: Bank.ozon,
              period: period,
              categories: [category('c', 7)],
            ),
          ]),
          throwsStateError,
        );
        final reopened = LocalCashbackRepository(directory: directory);
        await reopened.load();
        expect(reopened.cards.length, 1);
        expect(reopened.monthlySets.single.categories.single.percent, 5);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test('Unclear bank selection requires review, but not card or year', () {
    final parsed = ParsedScreenshot(
      bank: Bank.tbank,
      month: 10,
      year: null,
      categories: [
        const ParsedCategory(
          originalName: 'Маркетплейсы',
          percent: 5,
          selectionUnknown: true,
        ),
      ],
      warnings: const [],
    );
    final draft = ImportReviewDraft(parsed);
    final cards = [
      BankCard(
        id: 't1',
        bank: Bank.tbank,
        name: 'Black',
        rewardType: RewardType.rubles,
      ),
    ];
    expect(draft.rows.single.selected, isFalse);
    expect(draft.validate(cards), isNotNull);
    expect(draft.validate(cards), contains('Отметьте'));
    draft.rows.single.selected = true;
    expect(draft.validate(cards), isNull);
  });

  test(
    'Imported rows only replace a saved period by an explicit mode',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cashback-confirm-test-',
      );
      try {
        final repository = LocalCashbackRepository(directory: directory);
        await repository.load();
        final controller = CashbackController(repository);
        addTearDown(controller.dispose);
        await controller.saveCard(
          BankCard(
            id: 'card',
            bank: Bank.alfa,
            name: 'Моя',
            rewardType: RewardType.rubles,
          ),
        );
        final period = CashbackMonth(2026, 10);
        CashbackCategory category(String id, String name) => CashbackCategory(
          id: id,
          originalName: name,
          percent: 5,
          rewardType: RewardType.rubles,
        );
        await controller.saveImportedCategories(
          cardId: 'card',
          bank: Bank.alfa,
          period: period,
          incoming: [category('a', 'Аптеки')],
          mode: ImportSaveMode.create,
        );
        await expectLater(
          controller.saveImportedCategories(
            cardId: 'card',
            bank: Bank.alfa,
            period: period,
            incoming: [category('b', 'Такси')],
            mode: ImportSaveMode.create,
          ),
          throwsStateError,
        );
        expect(
          repository.monthlySets.single.categories.single.originalName,
          'Аптеки',
        );
        await controller.saveImportedCategories(
          cardId: 'card',
          bank: Bank.alfa,
          period: period,
          incoming: [category('b', 'Такси')],
          mode: ImportSaveMode.append,
        );
        await expectLater(
          controller.saveImportedCategories(
            cardId: 'card',
            bank: Bank.alfa,
            period: period,
            incoming: [category('c', 'Такси')],
            mode: ImportSaveMode.append,
          ),
          throwsStateError,
        );
        final reopened = LocalCashbackRepository(directory: directory);
        await reopened.load();
        expect(
          reopened.monthlySets.single.categories.map(
            (item) => item.originalName,
          ),
          ['Аптеки', 'Такси'],
        );
        await controller.saveImportedCategories(
          cardId: 'card',
          bank: Bank.alfa,
          period: period,
          incoming: [category('d', 'Супермаркеты')],
          mode: ImportSaveMode.replace,
        );
        expect(
          repository.monthlySets.single.categories.single.originalName,
          'Супермаркеты',
        );
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
