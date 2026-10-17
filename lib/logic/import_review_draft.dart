import '../domain/models.dart';
import '../domain/ocr_models.dart';
import 'import_period.dart';

/// Ephemeral user-reviewed OCR data. It is never stored as a confirmed set.
class ReviewRow {
  ReviewRow({
    required this.name,
    required this.percent,
    required this.rewardType,
    this.customRewardName = '',
    this.isUpTo = false,
    this.notes = '',
    this.selected = false,
  });

  String name;
  double percent;
  RewardType rewardType;
  String customRewardName;
  bool isUpTo;
  String notes;
  bool selected;
  String get rewardLabel =>
      customRewardName.trim().isEmpty ? rewardType.label : customRewardName;

  CashbackCategory toCategory(String id) => CashbackCategory(
    id: id,
    originalName: name.trim(),
    percent: percent,
    rewardType: rewardType,
    customRewardName: customRewardName,
    isUpTo: isUpTo,
    notes: notes.trim(),
  );
}

class ImportReviewDraft {
  ImportReviewDraft(ParsedScreenshot parsed, {Bank? bank})
    : bank = bank ?? parsed.bank,
      month = parsed.month,
      year = parsed.month == null
          ? parsed.year
          : importPeriod(parsed.month!, year: parsed.year).year,
      rows = [
        for (final item in parsed.categories)
          ReviewRow(
            name: item.originalName,
            percent: item.percent,
            rewardType: (bank ?? parsed.bank) == Bank.sber
                ? RewardType.sberSpasibo
                : RewardType.rubles,
            isUpTo: item.isUpTo,
            notes: item.notes,
            selected: !item.selectionUnknown,
          ),
      ];

  Bank? bank;
  String? cardId;
  int? month;
  int? year;
  final List<ReviewRow> rows;

  List<ReviewRow> get selectedRows =>
      rows.where((row) => row.selected).toList();

  String? validate(List<BankCard> cards) {
    if (bank == null) return 'Выберите банк из списка.';
    final matchingCards = cards.where((card) => card.bank == bank).toList();
    if (matchingCards.length > 1 && cardId == null ||
        cardId != null && !matchingCards.any((card) => card.id == cardId)) {
      return 'Выберите карту этого банка.';
    }
    if (month != null) year ??= importPeriod(month!).year;
    if (month == null ||
        month! < 1 ||
        month! > 12 ||
        year == null ||
        year! < 2000 ||
        year! > 9999) {
      return 'Укажите месяц, который действует на скриншоте.';
    }
    if (selectedRows.isEmpty) {
      return 'Отметьте хотя бы одну действительно выбранную категорию.';
    }
    if (selectedRows.any(
      (row) =>
          row.name.trim().isEmpty ||
          !row.percent.isFinite ||
          row.percent < 0 ||
          row.percent > 100,
    )) {
      return 'Проверьте название и процент отмеченных категорий.';
    }
    final names = selectedRows
        .map((row) => row.name.trim().toLowerCase())
        .toList();
    if (names.toSet().length != names.length) {
      return 'В отмеченных строках повторяется название категории.';
    }
    return null;
  }
}
