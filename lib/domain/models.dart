class Bank {
  const Bank._(this.name, this.label);

  static const alfa = Bank._('alfa', 'Альфа');
  static const tbank = Bank._('tbank', 'Т-Банк');
  static const sber = Bank._('sber', 'Сбер');
  static const vtb = Bank._('vtb', 'ВТБ');
  static const ozon = Bank._('ozon', 'Ozon Банк');
  static const values = [alfa, tbank, sber, vtb, ozon];

  /// Known banks retain their old IDs. Other names keep the user's wording.
  factory Bank.named(String input) {
    final label = input.trim();
    if (label.isEmpty ||
        label.length > 60 ||
        label.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw ArgumentError('Введите название банка до 60 символов.');
    }
    for (final bank in values) {
      if (bank.label.toLowerCase() == label.toLowerCase()) return bank;
    }
    return Bank._('custom:${Uri.encodeComponent(label)}', label);
  }

  factory Bank.fromStoredName(String name) {
    for (final bank in values) {
      if (bank.name == name) return bank;
    }
    if (name.startsWith('custom:')) {
      return Bank.named(Uri.decodeComponent(name.substring(7)));
    }
    throw FormatException('Неизвестный банк в сохранённых данных.');
  }

  static List<Bank> withSaved(Iterable<Bank> saved) {
    final result = <Bank>[...values];
    for (final bank in saved) {
      if (!result.contains(bank)) result.add(bank);
    }
    return result;
  }

  final String name;
  final String label;
  bool get isCustom => name.startsWith('custom:');

  @override
  bool operator ==(Object other) =>
      other is Bank &&
      (isCustom && other.isCustom
          ? label.toLowerCase() == other.label.toLowerCase()
          : name == other.name);

  @override
  int get hashCode => isCustom ? label.toLowerCase().hashCode : name.hashCode;
}

enum RewardType {
  rubles('Рубли'),
  sberSpasibo('Сбер Спасибо'),
  otherPoints('Бонусы'),
  custom('Своё название');

  const RewardType(this.label);
  final String label;
}

String formatCashbackPercent(double value) {
  if (value == value.truncateToDouble()) return value.toInt().toString();
  return value.toString().replaceAll('.', ',');
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
    this.customRewardName = '',
  }) {
    if (id.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('Карта должна иметь идентификатор и название');
    }
  }
  final String id;
  final Bank bank;
  final String name;
  final RewardType rewardType;
  final String customRewardName;
  String get rewardLabel =>
      customRewardName.trim().isEmpty ? rewardType.label : customRewardName;
  bool get hasAutomaticName => RegExp(r'^Карта \d+$').hasMatch(name);
}

class CashbackCategory {
  CashbackCategory({
    required this.id,
    required this.originalName,
    required this.percent,
    required this.rewardType,
    this.customRewardName = '',
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
  final String customRewardName;
  String get rewardLabel =>
      customRewardName.trim().isEmpty ? rewardType.label : customRewardName;
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
