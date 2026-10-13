import '../domain/models.dart';
import '../domain/ocr_models.dart';

/// Conservative rules for visible text. Checkmarks are not inferred from OCR.
class BankScreenshotParser {
  static final _rate = RegExp(
    r'(до\s*)?(\d{1,3}(?:[.,]\d+)?)\s*%',
    caseSensitive: false,
  );
  static final _months = <String, int>{
    'январ': 1,
    'феврал': 2,
    'март': 3,
    'апрел': 4,
    'мае': 5,
    'май': 5,
    'мая': 5,
    'июн': 6,
    'июл': 7,
    'август': 8,
    'сентябр': 9,
    'октябр': 10,
    'ноябр': 11,
    'декабр': 12,
  };

  ParsedScreenshot parse(OcrDocument document, {Bank? bankHint}) {
    // Phone status indicators (battery percentages) are not bank offers.
    final lines = document.lines.where((l) => l.top >= .06).toList()
      ..sort((a, b) => a.top.compareTo(b.top));
    final text = lines.map((l) => l.text).join('\n').toLowerCase();
    final bank = bankHint ?? _detectBank(text);
    final warnings = <String>[];
    int? month, year;
    final monthLines = lines.where(
      (l) => RegExp(
        r'категори|выгод|выбираете|выбрали',
        caseSensitive: false,
      ).hasMatch(l.text),
    );
    for (final line in monthLines) {
      final lower = line.text.toLowerCase();
      for (final entry in _months.entries) {
        if (lower.contains(entry.key)) month = entry.value;
      }
      final foundYear = RegExp(r'\b(20\d{2})\b').firstMatch(line.text);
      if (foundYear != null) year = int.parse(foundYear.group(1)!);
    }
    // A month selector is distinguishable only visually; ask rather than guess.
    if (month == null) {
      warnings.add('Месяц не определён: выберите его вручную.');
    }
    if (year == null) warnings.add('Год не указан: подтвердите его вручную.');
    if (bank == null) warnings.add('Банк не определён: выберите его вручную.');
    final choiceScreen =
        text.contains('выбираете') ||
        text.contains('какую еще') ||
        text.contains('какую ещё');
    final selectionUnknown = bank == Bank.tbank || choiceScreen;
    if (selectionUnknown) {
      warnings.add(
        'Это кандидаты: подтвердите выбранные строки и сохранение выбора в банке. Галочки по тексту не определяются.',
      );
    }
    if (bank == Bank.sber) {
      warnings.add(
        'Лента может продолжаться за кадром. Проверьте полноту списка.',
      );
    }
    final boundaries = lines.where(
      (l) => RegExp(
        r'выгода\s+(?:от|oт|oT|оt)\s+партн|копим бонус|ещ[её] больше к[эе]ш|действует для карт|включите геолокацию',
        caseSensitive: false,
      ).hasMatch(l.text),
    );
    final end = boundaries.isEmpty ? 1.0 : boundaries.first.top;
    final header = lines.where(
      (l) => RegExp(
        r'категори|ваша выгода|выбираете',
        caseSensitive: false,
      ).hasMatch(l.text),
    );
    final start = header.isEmpty ? 0.0 : header.first.bottom;
    final body = lines.where((l) => l.top >= start && l.top < end).toList();
    final categories = <ParsedCategory>[];
    final usedNames = <OcrLine>{};
    for (final line in body) {
      final match = _rate.firstMatch(line.text);
      if (match == null) continue;
      if (_rate.allMatches(line.text).length > 1) {
        warnings.add(
          'Несколько процентов слиты в одну строку. Нужна ручная проверка или другой режим распознавания.',
        );
        continue;
      }
      final percent = double.parse(match.group(2)!.replaceAll(',', '.'));
      if (percent > 100) {
        warnings.add(
          'Процент вне допустимого диапазона: проверьте изображение.',
        );
        continue;
      }
      var name = line.text.substring(match.end).trim();
      final before = line.text.substring(0, match.start).trim();
      if (name.isEmpty && before.isNotEmpty) name = before;
      name = name.replaceAll(RegExp(r'\s*[?✓✔]+\s*$'), '').trim();
      if (bank == Bank.tbank &&
          line.right > .84 &&
          RegExp(r'\s\d+\s+[А-Яа-яA-Za-z]+$').hasMatch(name)) {
        warnings.add(
          'В название могли попасть значки интерфейса. Проверьте текст категории.',
        );
      }
      final related = body
          .where(
            (other) =>
                other != line &&
                other.top < line.bottom + .18 &&
                other.bottom > line.top - .18 &&
                _sameColumn(line, other),
          )
          .toList();
      OcrLine? nameLine;
      if (name.isEmpty) {
        final candidates =
            related
                .where((l) => _isName(l.text) && !usedNames.contains(l))
                .toList()
              ..sort(
                (a, b) => (a.centerY - line.centerY).abs().compareTo(
                  (b.centerY - line.centerY).abs(),
                ),
              );
        if (candidates.isNotEmpty) {
          nameLine = candidates.first;
          final coveredRates = body
              .where(
                (other) =>
                    _rate.hasMatch(other.text) &&
                    _sameColumn(nameLine!, other) &&
                    (other.centerY - line.centerY).abs() < .035,
              )
              .length;
          if (coveredRates > 1) {
            warnings.add(
              'Название охватывает несколько карточек. Проверьте категории вручную или выберите другой режим распознавания.',
            );
            continue;
          }
          name = nameLine.text.trim();
          usedNames.add(nameLine);
          // Preserve wrapped labels on horizontal cards.
          final continuation = related
              .where(
                (l) =>
                    l != nameLine &&
                    _isName(l.text) &&
                    !usedNames.contains(l) &&
                    ((l.top - nameLine!.bottom).abs() < .025 ||
                        (nameLine.top - l.bottom).abs() < .025) &&
                    (l.left - nameLine.left).abs() < .06 &&
                    !_rate.hasMatch(l.text),
              )
              .toList();
          if (continuation.isNotEmpty) {
            name = continuation.first.top < nameLine.top
                ? '${continuation.first.text.trim()} $name'
                : '$name ${continuation.first.text.trim()}';
            usedNames.add(continuation.first);
          }
        }
      }
      if (name.isEmpty || !_isName(name)) {
        warnings.add(
          'Для одного процента не найдена категория. Проверьте скриншот.',
        );
        continue;
      }
      final anchor = nameLine ?? line;
      final notes = body
          .where(
            (l) =>
                l != line &&
                l.top >= anchor.top &&
                l.top < anchor.bottom + .10 &&
                _sameColumn(anchor, l) &&
                RegExp(
                  r'максимум|из\s+\d|для молод|можно выбрать',
                  caseSensitive: false,
                ).hasMatch(l.text),
          )
          .map((l) => l.text.trim())
          .join('; ');
      categories.add(
        ParsedCategory(
          originalName: name,
          percent: percent,
          isUpTo: match.group(1) != null,
          notes: notes,
          selectionUnknown: selectionUnknown,
        ),
      );
    }
    if (categories.isEmpty) {
      warnings.add('Категории не найдены. Можно внести их вручную.');
    }
    warnings.add('Проверьте категории и проценты перед использованием.');
    return ParsedScreenshot(
      bank: bank,
      month: month,
      year: year,
      categories: categories,
      warnings: warnings,
    );
  }

  bool _sameColumn(OcrLine a, OcrLine b) =>
      a.left < b.right && b.left < a.right;
  bool _isName(String text) =>
      text.trim().isNotEmpty &&
      RegExp(r'[A-Za-zА-Яа-яЁё]{2,}').hasMatch(text) &&
      !_rate.hasMatch(text) &&
      !RegExp(
        r'максимум|подробнее|подключить|готово|условия|категори|premium|история|лимит|для молод|можно выбрать|^из\s|^0\s*[₽р]',
        caseSensitive: false,
      ).hasMatch(text);
  Bank? _detectBank(String text) {
    if (text.contains('ozon')) return Bank.ozon;
    if (text.contains('т-путешествия') ||
        text.contains('тпутешествия') ||
        text.contains('т-банк')) {
      return Bank.tbank;
    }
    if (text.contains('сбер') || text.contains('история бонусов')) {
      return Bank.sber;
    }
    if (text.contains('втб')) return Bank.vtb;
    if (text.contains('альфа')) return Bank.alfa;
    return null;
  }
}
