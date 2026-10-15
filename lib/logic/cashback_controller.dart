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

  Future<void> saveImportedCategories({
    required String cardId,
    required CashbackMonth period,
    required List<CashbackCategory> incoming,
    required ImportSaveMode mode,
  }) async {
    if (incoming.isEmpty) throw ArgumentError('Нет выбранных категорий.');
    final existing = setFor(cardId, period);
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
}

enum ImportSaveMode { create, append, replace }
