enum Bank {
  alfa('Альфа'),
  tbank('Т-Банк'),
  sber('Сбер'),
  vtb('ВТБ'),
  ozon('Ozon Банк');

  const Bank(this.label);
  final String label;
}

enum RewardType {
  rubles('Рубли'),
  sberSpasibo('Бонусы Спасибо'),
  otherPoints('Другие баллы');

  const RewardType(this.label);
  final String label;
}

class CashbackMonth {
  CashbackMonth(this.year, this.month) {
    if (year < 1 || year > 9999 || month < 1 || month > 12) {
      throw ArgumentError('Некорректный месяц или год');
    }
  }
  factory CashbackMonth.current() {
    final now = DateTime.now();
    return CashbackMonth(now.year, now.month);
  }
  final int year;
  final int month;
  CashbackMonth shift(int offset) {
    final date = DateTime(year, month + offset);
    return CashbackMonth(date.year, date.month);
  }

  @override
  bool operator ==(Object other) =>
      other is CashbackMonth && year == other.year && month == other.month;
  @override
  int get hashCode => Object.hash(year, month);
}

class BankCard {
  BankCard({
    required this.id,
    required this.bank,
    required this.name,
    required this.rewardType,
  }) {
    if (id.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('Карта должна иметь идентификатор и название');
    }
  }
  final String id;
  final Bank bank;
  final String name;
  final RewardType rewardType;
}

class CashbackCategory {
  CashbackCategory({
    required this.id,
    required this.originalName,
    required this.percent,
    required this.rewardType,
    this.isUpTo = false,
    this.notes = '',
  }) {
    if (id.trim().isEmpty || originalName.trim().isEmpty) {
      throw ArgumentError('Категория должна иметь идентификатор и название');
    }
    if (!percent.isFinite || percent < 0 || percent > 100) {
      throw ArgumentError('Процент должен быть от 0 до 100');
    }
  }
  final String id;
  // Preserve exact bank wording; do not automatically merge categories.
  final String originalName;
  final double percent;
  final RewardType rewardType;
  final bool isUpTo;
  final String notes;
}

class MonthlyCashbackSet {
  MonthlyCashbackSet({
    required this.cardId,
    required this.period,
    required Iterable<CashbackCategory> categories,
    required this.confirmedAt,
    this.notes = '',
  }) : categories = List.unmodifiable(categories) {
    if (cardId.trim().isEmpty) {
      throw ArgumentError('Набор должен относиться к карте');
    }
  }
  final String cardId;
  final CashbackMonth period;
  final List<CashbackCategory> categories;
  final DateTime confirmedAt;
  final String notes;
}
