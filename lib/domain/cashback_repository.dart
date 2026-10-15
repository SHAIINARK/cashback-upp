import 'models.dart';

abstract interface class CashbackRepository {
  List<BankCard> get cards;
  List<MonthlyCashbackSet> get monthlySets;
}

abstract interface class WritableCashbackRepository
    implements CashbackRepository {
  Future<void> load();
  Future<void> saveCard(BankCard card);
  Future<void> deleteCard(String id);
  Future<void> saveSet(MonthlyCashbackSet set);
  Future<void> saveImportBatch({
    required List<BankCard> newCards,
    required List<MonthlyCashbackSet> sets,
  });
  Future<void> deleteSet(String cardId, CashbackMonth period);
}
