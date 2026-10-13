import 'package:flutter_test/flutter_test.dart';
import 'package:balance_app/domain/models.dart';
import 'package:balance_app/domain/ocr_models.dart';
import 'package:balance_app/logic/bank_screenshot_parser.dart';

// Synthetic OCR geometry tests rules only, not OCR accuracy on real images.
OcrLine line(String text, double top, {double left = .1, double right = .9}) =>
    OcrLine(text: text, left: left, top: top, right: right, bottom: top + .02);
ParsedScreenshot parse(List<OcrLine> lines, {Bank? bank}) =>
    BankScreenshotParser().parse(
      OcrDocument(
        lines: lines,
        width: 1080,
        height: 2400,
        engine: 'synthetic-test',
        elapsedMs: 0,
      ),
      bankHint: bank,
    );

void main() {
  test('Symbols with a single OCR letter are not category names', () {
    final result = parse([
      line('Ваши категории в сентябре', .33),
      line('Транспорт', .392, left: .40, right: .56),
      line('о -.. @~', .462, left: .40, right: .96),
      line('4%', .475, left: .40, right: .49),
      line('Включите геолокацию', .586),
    ], bank: Bank.sber);
    expect(result.categories.length, 1);
    expect(result.categories.single.originalName, 'Транспорт');
  });
  test(
    'Merged horizontal names cannot be assigned to three separate rates',
    () {
      final result = parse([
        line('Ваши категории в сентябре', .33),
        line('Такси и Транспорт Хобби и', .39, left: .08, right: .84),
        line('каршеринг развлечения', .414, left: .08, right: .92),
        line('4%', .475, left: .08, right: .17),
        line('4%', .475, left: .40, right: .49),
        line('4%', .475, left: .72, right: .81),
        line('Включите геолокацию', .586),
      ], bank: Bank.sber);
      expect(result.categories, isEmpty);
      expect(
        result.warnings.any((w) => w.contains('несколько карточек')),
        isTrue,
      );
    },
  );
  test('Actual OCR failure patterns remain explicit, not reconstructed', () {
    final result = parse([
      line('22:28 81% а', .02),
      line('Ваша выгода в октябре', .28),
      line('1% 2%', .345, left: .08, right: .62),
      line('За все покупки Дом и ремонт', .377, left: .08, right: .8),
      line('5%', .538, left: .08, right: .15),
      line('Фастфуд', .569, left: .08, right: .24),
    ], bank: Bank.alfa);
    expect(result.categories.length, 1);
    expect(result.categories.single.originalName, 'Фастфуд');
    expect(result.warnings.any((w) => w.contains('слиты')), isTrue);
  });
  test('Latin OCR letters in partner boundary still exclude advertising', () {
    final result = parse([
      line('Категории на октябрь', .2),
      line('5% Аптеки', .4),
      line('Выгода oT партнёров', .69),
      line('Кешбэк 30%', .83),
    ], bank: Bank.ozon);
    expect(result.categories.length, 1);
    expect(result.categories.single.originalName, 'Аптеки');
  });
  test('Missing Sber OCR rates cannot be recovered from category labels', () {
    final result = parse([
      line('Ваши категории в сентябре', .33),
      line('Такси и', .39, left: .08, right: .2),
      line('каршеринг', .415, left: .08, right: .25),
      line('ss', .477, left: .21, right: .31),
      line('Включите геолокацию', .586),
    ], bank: Bank.sber);
    expect(result.categories, isEmpty);
    expect(result.warnings.any((w) => w.contains('не найдены')), isTrue);
  });
  test(
    'Ozon excludes unactivated partner advertising and does not guess year',
    () {
      final result = parse([
        line('Категории на октябрь', .2),
        line('5 категорий с Ozon Premium', .25),
        line('1% Все покупки', .32),
        line('5% Аптеки', .4),
        line('10% Перекрёсток Доставка', .5),
        line('Выгода от партнёров', .65),
        line('Магнит Кешбэк 30%', .75),
        line('Подключить', .8),
      ]);
      expect(result.bank, Bank.ozon);
      expect(result.month, 10);
      expect(result.year, isNull);
      expect(result.categories.map((c) => c.originalName), [
        'Все покупки',
        'Аптеки',
        'Перекрёсток Доставка',
      ]);
    },
  );
  test('T-Bank rates are candidates, never inferred as chosen', () {
    final result = parse([
      line('Какую еще категорию выбираете на октябрь?', .1),
      line('1% Все покупки', .25),
      line('5% Такси', .35),
      line('40% Чиббис', .45),
      line('Максимум — 700 бонусов', .48),
      line('до 25% Супермаркеты в Городе', .6),
      line('Готово', .9),
    ], bank: Bank.tbank);
    expect(result.categories.length, 4);
    expect(result.categories.every((c) => c.selectionUnknown), isTrue);
    expect(result.categories.last.isUpTo, isTrue);
    expect(result.categories[2].notes, contains('700'));
    expect(result.warnings.any((w) => w.contains('Галочки')), isTrue);
  });
  test('Sber horizontal cards keep wrapped names and their own rates', () {
    final result = parse([
      line('Ваши категории в сентябре', .2),
      line('Такси и', .3, left: .08, right: .28),
      line('каршеринг', .325, left: .08, right: .28),
      line('Транспорт', .3, left: .4, right: .6),
      line('4%', .4, left: .08, right: .2),
      line('7%', .4, left: .4, right: .52),
    ], bank: Bank.sber);
    expect(result.month, 9);
    expect(result.categories.map((c) => c.originalName), [
      'Такси и каршеринг',
      'Транспорт',
    ]);
    expect(result.categories.map((c) => c.percent), [4, 7]);
    expect(result.warnings.any((w) => w.contains('Лента')), isTrue);
  });
  test('Alfa grid pairs rates with text in the same column', () {
    final result = parse([
      line('Ваша выгода в октябре 2026', .2),
      line('1%', .3, left: .1, right: .25),
      line('2%', .3, left: .55, right: .7),
      line('За все покупки', .34, left: .1, right: .45),
      line('Дом и ремонт', .34, left: .55, right: .9),
      line('5%', .55, left: .1, right: .25),
      line('Фастфуд', .59, left: .1, right: .45),
      line('Для молодёжи', .65, left: .1, right: .45),
      line('Действует для карт', .8),
    ], bank: Bank.alfa);
    expect(result.year, 2026);
    expect(result.categories.map((c) => c.originalName), [
      'За все покупки',
      'Дом и ремонт',
      'Фастфуд',
    ]);
    expect(result.categories.last.notes, contains('Для молодёжи'));
  });
  test('VTB limit belongs to category; ambiguous selector stays unknown', () {
    final result = parse([
      line('Август Сентябрь Октябрь', .3),
      line('3% Wildberries', .4),
      line('0 ₽ из 500 ₽', .44),
      line('1% Все остальные покупки', .55),
      line('2% Супермаркеты', .65),
      line('Еще больше кешбэка', .8),
      line('15% Реклама', .9),
    ], bank: Bank.vtb);
    expect(result.month, isNull);
    expect(result.categories.length, 3);
    expect(result.categories.first.notes, contains('500'));
    expect(result.categories[1].notes, isEmpty);
  });
  test(
    'Unmatched percentage and invalid rate are not fabricated categories',
    () {
      final result = parse([line('150% Аптеки', .3), line('5%', .7)]);
      expect(result.categories, isEmpty);
      expect(result.bank, isNull);
    },
  );
}
