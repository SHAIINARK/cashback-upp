import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/cashback_repository.dart';
import '../domain/models.dart';

/// Versioned private file. Every change is written before memory is updated.
class LocalCashbackRepository implements WritableCashbackRepository {
  LocalCashbackRepository({Directory? directory}) {
    _directory = directory;
  }

  Directory? _directory;
  List<BankCard> _cards = [];
  List<MonthlyCashbackSet> _sets = [];
  Future<void> _pending = Future.value();
  bool _loaded = false;

  @override
  List<BankCard> get cards => List.unmodifiable(_cards);
  @override
  List<MonthlyCashbackSet> get monthlySets => List.unmodifiable(_sets);

  Future<File> get _file async {
    final directory = _directory ??= await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}cashback-data.json');
  }

  @override
  Future<void> load() async {
    final file = await _file;
    if (!await file.exists()) {
      _loaded = true;
      return;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic> ||
        (decoded['schema'] != 1 && decoded['schema'] != 2)) {
      throw const FormatException(
        'Неподдерживаемая версия сохранённых данных.',
      );
    }
    final cards = (decoded['cards'] as List<dynamic>)
        .map((item) => _decodeCard(item as Map<String, dynamic>))
        .toList();
    final sets = (decoded['sets'] as List<dynamic>)
        .map((item) => _decodeSet(item as Map<String, dynamic>))
        .toList();
    final ids = cards.map((card) => card.id).toSet();
    if (ids.length != cards.length ||
        sets.any((set) => !ids.contains(set.cardId)) ||
        {
              for (final set in sets)
                '${set.cardId}:${set.period.year}:${set.period.month}',
            }.length !=
            sets.length) {
      throw const FormatException('Сохранённые данные повреждены.');
    }
    _cards = cards;
    _sets = sets;
    _loaded = true;
  }

  Future<void> _change(
    List<BankCard> Function(List<BankCard>) updateCards,
    List<MonthlyCashbackSet> Function(List<MonthlyCashbackSet>) updateSets,
  ) {
    final operation = _pending.then((_) async {
      if (!_loaded) throw StateError('Данные ещё не загружены.');
      final cards = updateCards(List.of(_cards));
      final sets = updateSets(List.of(_sets));
      final file = await _file;
      final temporary = File('${file.path}.tmp');
      final payload = jsonEncode({
        'schema': 2,
        'cards': cards.map(_encodeCard).toList(),
        'sets': sets.map(_encodeSet).toList(),
      });
      try {
        await temporary.writeAsString(payload, flush: true);
        if (await file.exists()) {
          await file.copy('${file.path}.bak');
        }
        await temporary.rename(file.path);
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
      _cards = cards;
      _sets = sets;
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  @override
  Future<void> saveCard(BankCard card) => _change((cards) {
    cards.removeWhere((item) => item.id == card.id);
    return [...cards, card];
  }, (sets) => sets);

  @override
  Future<void> deleteCard(String id) => _change(
    (cards) => cards..removeWhere((item) => item.id == id),
    (sets) => sets..removeWhere((item) => item.cardId == id),
  );

  @override
  Future<void> saveSet(MonthlyCashbackSet set) => _change(
    (cards) {
      if (!cards.any((card) => card.id == set.cardId)) {
        throw StateError('Карта не найдена.');
      }
      return cards;
    },
    (sets) {
      sets.removeWhere(
        (item) => item.cardId == set.cardId && item.period == set.period,
      );
      return [...sets, set];
    },
  );

  @override
  Future<void> saveImportBatch({
    required List<BankCard> newCards,
    required List<MonthlyCashbackSet> sets,
  }) => _change(
    (cards) {
      final ids = cards.map((card) => card.id).toSet();
      for (final card in newCards) {
        if (!ids.add(card.id)) throw StateError('Карта уже существует.');
        cards.add(card);
      }
      if (sets.any((set) => !ids.contains(set.cardId))) {
        throw StateError('Карта для категории не найдена.');
      }
      return cards;
    },
    (current) {
      final keys = <String>{};
      for (final set in sets) {
        final key = '${set.cardId}:${set.period.year}:${set.period.month}';
        if (!keys.add(key)) throw StateError('Повторяется месячный набор.');
        current.removeWhere(
          (item) => item.cardId == set.cardId && item.period == set.period,
        );
        current.add(set);
      }
      return current;
    },
  );

  @override
  Future<void> deleteSet(String cardId, CashbackMonth period) => _change(
    (cards) => cards,
    (sets) => sets
      ..removeWhere((item) => item.cardId == cardId && item.period == period),
  );

  Map<String, Object?> _encodeCard(BankCard card) => {
    'id': card.id,
    'bank': card.bank.name,
    'name': card.name,
    'rewardType': card.rewardType.name,
    'customRewardName': card.customRewardName,
  };

  BankCard _decodeCard(Map<String, dynamic> data) => BankCard(
    id: data['id'] as String,
    bank: Bank.fromStoredName(data['bank'] as String),
    name: data['name'] as String,
    rewardType: RewardType.values.byName(data['rewardType'] as String),
    customRewardName: data['customRewardName'] as String? ?? '',
  );

  Map<String, Object?> _encodeSet(MonthlyCashbackSet set) => {
    'cardId': set.cardId,
    'year': set.period.year,
    'month': set.period.month,
    'confirmedAt': set.confirmedAt.toIso8601String(),
    'notes': set.notes,
    'categories': set.categories
        .map(
          (category) => {
            'id': category.id,
            'originalName': category.originalName,
            'percent': category.percent,
            'rewardType': category.rewardType.name,
            'customRewardName': category.customRewardName,
            'isUpTo': category.isUpTo,
            'notes': category.notes,
          },
        )
        .toList(),
  };

  MonthlyCashbackSet _decodeSet(Map<String, dynamic> data) =>
      MonthlyCashbackSet(
        cardId: data['cardId'] as String,
        period: CashbackMonth(data['year'] as int, data['month'] as int),
        confirmedAt: DateTime.parse(data['confirmedAt'] as String),
        notes: data['notes'] as String? ?? '',
        categories: (data['categories'] as List<dynamic>).map((item) {
          final category = item as Map<String, dynamic>;
          return CashbackCategory(
            id: category['id'] as String,
            originalName: category['originalName'] as String,
            percent: (category['percent'] as num).toDouble(),
            rewardType: RewardType.values.byName(
              category['rewardType'] as String,
            ),
            customRewardName: category['customRewardName'] as String? ?? '',
            isUpTo: category['isUpTo'] as bool? ?? false,
            notes: category['notes'] as String? ?? '',
          );
        }),
      );
}
