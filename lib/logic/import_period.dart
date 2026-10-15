import '../domain/models.dart';

/// The UI asks for a month; the stored period still needs a year so January
/// and December from different years never overwrite one another.
CashbackMonth importPeriod(int month, {int? year, DateTime? now}) {
  final today = now ?? DateTime.now();
  var resolvedYear = year ?? today.year;
  if (year == null) {
    final distance = month - today.month;
    if (distance > 6) resolvedYear--;
    if (distance < -6) resolvedYear++;
  }
  return CashbackMonth(resolvedYear, month);
}
