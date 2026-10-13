import '../domain/cashback_repository.dart';
import '../domain/models.dart';

/// No sample financial records are presented as user data.
class EmptyCashbackRepository implements CashbackRepository {
  @override
  List<BankCard> get cards => const [];
  @override
  List<MonthlyCashbackSet> get monthlySets => const [];
}
