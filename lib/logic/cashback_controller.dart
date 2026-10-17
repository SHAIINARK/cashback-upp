import 'package:flutter/foundation.dart';

import 'dart:math';

import '../domain/cashback_repository.dart';
import '../domain/models.dart';

class CashbackController extends ChangeNotifier {
  CashbackController(this.repository, {CashbackMonth? initialMonth})
    : _anchorMonth = initialMonth ?? CashbackMonth.current(),
      _month = initialMonth ?? CashbackMonth.current();
  final CashbackRepository repository;
  final CashbackMonth _anchorMonth;
  CashbackMonth get anchorMonth => _anchorMonth;
  CashbackMonth _month;
  CashbackMonth get month => _month;
  List<BankCard> get cards => List.unmodifiable(repository.cards);
  List<MonthlyCashbackSet> get allSets =>
      List.unmodifiable(repository.monthlySets);
  List<String> get learnedCategorySuggestions =>
      repository is CategorySuggestionStore
      ? (repository as CategorySuggestionStore).learnedCategorySuggestions
      : const [];
  List<MonthlyCashbackSet> get selectedSets => List.unmodifiable(
    repository.monthlySets.where((set) => set.period == _month),
  );
  List<BankCard> get selectedCards {
    final ids = selectedSets.map((set) => set.cardId).toSet();
    return List.unmodifiable(
      repository.cards.where((card) => ids.contains(card.id)),
    );
  }

  void moveMonth(int offset) {
    if (offset < -1 || offset > 1) return;
    _month = _anchorMonth.shift(offset);
    notifyListeners();
  }

  WritableCashbackRepository get _writable =>
      repository as WritableCashbackRepository;

  Future<void> rememberCategorySuggestions(Iterable<String> values) async {
    final store = repository;
    if (store is! CategorySuggestionStore) return;
    await (store as CategorySuggestionStore).rememberCategorySuggestions(
      values,
    );
    notifyListeners();
  }

  String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

  Future<void> saveCard(BankCard card) async {
    await _writable.saveCard(card);
    notifyListeners();
  }

  Future<void> deleteCard(String id) async {
    await _writable.deleteCard(id);
    notifyListeners();
  }

  Future<void> saveCategory(
    String cardId,
    CashbackMonth period,
    CashbackCategory category,
  ) async {
    final existing = repository.monthlySets
        .where((set) => set.cardId == cardId && set.period == period)
        .firstOrNull;
    final categories = [...?existing?.categories]
      ..removeWhere((item) => item.id == category.id)
      ..add(category);
    await _writable.saveSet(
      MonthlyCashbackSet(
        cardId: cardId,
        period: period,
        categories: categories,
        confirmedAt: DateTime.now(),
        notes: existing?.notes ?? '',
      ),
    );
    notifyListeners();
  }

  Future<void> deleteCategory(
    String cardId,
    CashbackMonth period,
    String categoryId,
  ) async {
    final existing = repository.monthlySets
        .where((set) => set.cardId == cardId && set.period == period)
        .firstOrNull;
    if (existing == null) return;
    final categories = existing.categories
        .where((item) => item.id != categoryId)
        .toList();
    if (categories.isEmpty) {
      await _writable.deleteSet(cardId, period);
    } else {
      await _writable.saveSet(
        MonthlyCashbackSet(
          cardId: cardId,
          period: period,
          categories: categories,
          confirmedAt: DateTime.now(),
          notes: existing.notes,
        ),
      );
    }
    notifyListeners();
  }

  MonthlyCashbackSet? setFor(String cardId, CashbackMonth period) => repository
      .monthlySets
      .where((set) => set.cardId == cardId && set.period == period)
      .firstOrNull;

  BankCard _cardFor(Bank bank, String? cardId, List<BankCard> created) {
    final available = [
      ...repository.cards,
      ...created,
    ].where((card) => card.bank == bank).toList();
    if (cardId != null) {
      return available.where((card) => card.id == cardId).firstOrNull ??
          (throw StateError('Выберите карту этого банка.'));
    }
    if (available.length > 1) {
      throw StateError('У этого банка несколько карт. Выберите нужную.');
    }
    if (available.length == 1) return available.single;
    final card = BankCard(
      id: 'auto-${bank.name}',
      bank: bank,
      name: 'Карта 1',
      rewardType: bank == Bank.sber
          ? RewardType.sberSpasibo
          : RewardType.rubles,
    );
    created.add(card);
    return card;
  }

  Future<void> saveQuickImport(List<QuickImportItem> items) async {
    if (items.isEmpty) throw ArgumentError('Нет категорий для сохранения.');
    final created = <BankCard>[];
    final grouped =
        <String, (BankCard, CashbackMonth, List<CashbackCategory>)>{};
    for (final item in items) {
      if (item.categories.isEmpty) {
        throw ArgumentError('Нет категорий для сохранения.');
      }
      final card = _cardFor(item.bank, item.cardId, created);
      final key = '${card.id}:${item.period.year}:${item.period.month}';
      final previous = grouped[key];
      grouped[key] = (
        card,
        item.period,
        [...?previous?.$3, ...item.categories],
      );
    }
    final sets = <MonthlyCashbackSet>[];
    for (final group in grouped.values) {
      final existing = setFor(group.$1.id, group.$2);
      final merged = <CashbackCategory>[];
      for (final category in [...?existing?.categories, ...group.$3]) {
        final duplicate = merged
            .where(
              (item) =>
                  item.originalName.trim().toLowerCase() ==
                  category.originalName.trim().toLowerCase(),
            )
            .firstOrNull;
        if (duplicate == null) {
          merged.add(category);
        } else if (duplicate.percent != category.percent ||
            duplicate.rewardType != category.rewardType ||
            duplicate.isUpTo != category.isUpTo ||
            duplicate.notes != category.notes) {
          throw StateError(
            '${group.$1.bank.label}: категория «${category.originalName}» уже сохранена с другими условиями. Проверьте её вручную.',
          );
        }
      }
      sets.add(
        MonthlyCashbackSet(
          cardId: group.$1.id,
          period: group.$2,
          categories: merged,
          confirmedAt: DateTime.now(),
          notes: existing?.notes ?? '',
        ),
      );
    }
    await _writable.saveImportBatch(newCards: created, sets: sets);
    notifyListeners();
  }

  Future<void> saveImportedCategories({
    String? cardId,
    required Bank bank,
    required CashbackMonth period,
    required List<CashbackCategory> incoming,
    required ImportSaveMode mode,
  }) async {
    if (incoming.isEmpty) throw ArgumentError('Нет выбранных категорий.');
    final created = <BankCard>[];
    final card = _cardFor(bank, cardId, created);
    final existing = setFor(card.id, period);
    if (mode == ImportSaveMode.create && existing != null) {
      throw StateError('Набор уже существует.');
    }
    if (mode != ImportSaveMode.create && existing == null) {
      throw StateError('Набор не найден.');
    }
    final categories = mode == ImportSaveMode.append
        ? [...existing!.categories, ...incoming]
        : incoming;
    final names = categories
        .map((item) => item.originalName.trim().toLowerCase())
        .toList();
    if (names.toSet().length != names.length) {
      throw StateError(
        'Категория с таким названием уже есть у карты в этом месяце.',
      );
    }
    await _writable.saveImportBatch(
      newCards: created,
      sets: [
        MonthlyCashbackSet(
          cardId: card.id,
          period: period,
          categories: categories,
          confirmedAt: DateTime.now(),
          notes: existing?.notes ?? '',
        ),
      ],
    );
    notifyListeners();
  }
}

enum ImportSaveMode { create, append, replace }

class QuickImportItem {
  const QuickImportItem({
    required this.bank,
    required this.period,
    required this.categories,
    this.cardId,
  });

  final Bank bank;
  final CashbackMonth period;
  final List<CashbackCategory> categories;
  final String? cardId;
}
