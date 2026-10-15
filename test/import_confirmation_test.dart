import 'dart:io';

import 'package:balance_app/data/local_cashback_repository.dart';
import 'package:balance_app/domain/models.dart';
import 'package:balance_app/domain/ocr_models.dart';
import 'package:balance_app/logic/cashback_controller.dart';
import 'package:balance_app/logic/import_review_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OCR rows require explicit selection, card and year', () {
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
    draft.cardId = 't1';
    draft.year = 2026;
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
          period: period,
          incoming: [category('a', 'Аптеки')],
          mode: ImportSaveMode.create,
        );
        await expectLater(
          controller.saveImportedCategories(
            cardId: 'card',
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
          period: period,
          incoming: [category('b', 'Такси')],
          mode: ImportSaveMode.append,
        );
        await expectLater(
          controller.saveImportedCategories(
            cardId: 'card',
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
