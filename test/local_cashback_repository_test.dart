import 'dart:convert';
import 'dart:io';

import 'package:balance_app/data/local_cashback_repository.dart';
import 'package:balance_app/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Cards and confirmed categories survive reload; edits keep stable IDs',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cashback-storage-test-',
      );
      try {
        final store = LocalCashbackRepository(directory: directory);
        await store.load();
        await store.saveCard(
          BankCard(
            id: 'card-1',
            bank: Bank.sber,
            name: 'Моя карта',
            rewardType: RewardType.sberSpasibo,
          ),
        );
        await store.saveSet(
          MonthlyCashbackSet(
            cardId: 'card-1',
            period: CashbackMonth(2026, 10),
            confirmedAt: DateTime.utc(2026, 10, 15),
            categories: [
              CashbackCategory(
                id: 'cat-1',
                originalName: 'Такси и каршеринг',
                percent: 4,
                rewardType: RewardType.sberSpasibo,
                notes: 'Только в приложении',
              ),
            ],
          ),
        );
        await store.saveCard(
          BankCard(
            id: 'card-1',
            bank: Bank.sber,
            name: 'Переименована',
            rewardType: RewardType.sberSpasibo,
          ),
        );
        final reopened = LocalCashbackRepository(directory: directory);
        await reopened.load();
        expect(reopened.cards.single.name, 'Переименована');
        expect(reopened.monthlySets.single.period, CashbackMonth(2026, 10));
        expect(
          reopened.monthlySets.single.categories.single.originalName,
          'Такси и каршеринг',
        );
        expect(
          reopened.monthlySets.single.categories.single.rewardType,
          RewardType.sberSpasibo,
        );
        expect(
          reopened.monthlySets.single.categories.single.notes,
          'Только в приложении',
        );
        expect(
          reopened.learnedCategorySuggestions,
          contains('Такси и каршеринг'),
        );
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test('Unknown schema is rejected without overwriting stored data', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cashback-storage-test-',
    );
    try {
      final file = File(
        '${directory.path}${Platform.pathSeparator}cashback-data.json',
      );
      final content = jsonEncode({'schema': 99, 'cards': [], 'sets': []});
      await file.writeAsString(content);
      final store = LocalCashbackRepository(directory: directory);
      await expectLater(store.load(), throwsFormatException);
      await expectLater(
        store.saveCard(
          BankCard(
            id: 'x',
            bank: Bank.vtb,
            name: 'Карта',
            rewardType: RewardType.rubles,
          ),
        ),
        throwsStateError,
      );
      expect(await file.readAsString(), content);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test(
    'Schema 2 remains readable and gains local category suggestions',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cashback-storage-migration-test-',
      );
      try {
        final file = File(
          '${directory.path}${Platform.pathSeparator}cashback-data.json',
        );
        await file.writeAsString(
          jsonEncode({'schema': 2, 'cards': [], 'sets': []}),
        );
        final store = LocalCashbackRepository(directory: directory);
        await store.load();
        expect(store.learnedCategorySuggestions, isEmpty);
        await store.rememberCategorySuggestions(['Аптеки']);

        final reopened = LocalCashbackRepository(directory: directory);
        await reopened.load();
        expect(reopened.learnedCategorySuggestions, ['Аптеки']);
        expect(jsonDecode(await file.readAsString())['schema'], 3);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
