import 'package:balance_app/domain/models.dart';
import 'package:balance_app/domain/cashback_repository.dart';
import 'package:balance_app/logic/cashback_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements CashbackRepository {
  @override
  final List<BankCard> cards = [];
  @override
  final List<MonthlyCashbackSet> monthlySets = [
    MonthlyCashbackSet(
      cardId: 'test',
      period: CashbackMonth(2025, 1),
      categories: [],
      confirmedAt: DateTime(2025),
    ),
    MonthlyCashbackSet(
      cardId: 'test',
      period: CashbackMonth(2026, 1),
      categories: [],
      confirmedAt: DateTime(2026),
    ),
  ];
}

void main() {
  test('Periods cross the year boundary and filter by year', () {
    expect(CashbackMonth(2026, 12).shift(1), CashbackMonth(2027, 1));
    expect(CashbackMonth(2026, 1).shift(-1), CashbackMonth(2025, 12));
    final controller = CashbackController(
      _Repository(),
      initialMonth: CashbackMonth(2026, 1),
    );
    addTearDown(controller.dispose);
    expect(controller.selectedSets.single.period.year, 2026);
  });
  test('Invalid rates rejected; exact names and reward types preserved', () {
    CashbackCategory make(double rate) => CashbackCategory(
      id: 'test',
      originalName: 'Такси и каршеринг',
      percent: rate,
      rewardType: RewardType.sberSpasibo,
    );
    for (final rate in [double.nan, double.infinity, -1.0, 101.0]) {
      expect(() => make(rate), throwsArgumentError);
    }
    final category = make(4);
    expect(category.originalName, 'Такси и каршеринг');
    expect(category.rewardType, isNot(RewardType.rubles));
    expect(() => CashbackMonth(2026, 13), throwsArgumentError);
  });
}
