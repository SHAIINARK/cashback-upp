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

List<CashbackMonth> importMonthChoices({DateTime? now}) {
  final date = now ?? DateTime.now();
  final current = CashbackMonth(date.year, date.month);
  return [current.shift(-1), current, current.shift(1)];
}

const importMonthNames = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

String importMonthLabel(CashbackMonth period) =>
    importMonthNames[period.month - 1];
