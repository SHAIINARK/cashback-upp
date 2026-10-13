import 'package:flutter/foundation.dart';

import '../domain/cashback_repository.dart';
import '../domain/models.dart';

class CashbackController extends ChangeNotifier {
  CashbackController(this.repository, {CashbackMonth? initialMonth})
    : _month = initialMonth ?? CashbackMonth.current();
  final CashbackRepository repository;
  CashbackMonth _month;
  CashbackMonth get month => _month;
  List<BankCard> get cards => List.unmodifiable(repository.cards);
  List<MonthlyCashbackSet> get selectedSets => List.unmodifiable(
    repository.monthlySets.where((set) => set.period == _month),
  );
  void moveMonth(int offset) {
    _month = _month.shift(offset);
    notifyListeners();
  }
}
