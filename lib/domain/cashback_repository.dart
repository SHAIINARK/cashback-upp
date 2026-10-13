import 'models.dart';

/// Read boundary; persistence and write operations belong to the next stage.
abstract interface class CashbackRepository {
  List<BankCard> get cards;
  List<MonthlyCashbackSet> get monthlySets;
}
