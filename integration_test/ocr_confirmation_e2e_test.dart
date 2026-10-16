import 'dart:io';

import 'package:balance_app/app/theme.dart';
import 'package:balance_app/data/local_cashback_repository.dart';
import 'package:balance_app/domain/models.dart';
import 'package:balance_app/logic/cashback_controller.dart';
import 'package:balance_app/presentation/ocr_import_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';

const _package = String.fromEnvironment(
  'OCR_PACKAGE',
  defaultValue: 'ru.cashbackguide.balance_app.qa',
);
final _fixture = '/data/user/0/$_package/files/ocr-fixtures/1.jpg';

class _FixturePicker extends ImagePicker {
  @override
  Future<LostDataResponse> retrieveLostData() async => LostDataResponse();

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async => [XFile(_fixture)];
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
  }
  expect(finder, findsWidgets);
}

Future<void> _waitForImportReady(WidgetTester tester) async {
  await _waitFor(tester, find.text('Выбрать скриншоты'));
  await tester.pumpAndSettle();
  for (var i = 0; i < 100; i++) {
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Выбрать скриншоты'),
    );
    if (button.onPressed != null &&
        find.text('Завершить проверку').evaluate().isEmpty) {
      return;
    }
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  fail('Импорт не стал доступен после возврата из проверки.');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Real OCR draft is saved with one tap and no card setup', (
    tester,
  ) async {
    expect(await File(_fixture).exists(), isTrue);
    final directory = await Directory.systemTemp.createTemp('cashback-e2e-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final repository = LocalCashbackRepository(directory: directory);
    await repository.load();
    final controller = CashbackController(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: SafeArea(
            child: ImportScreen(
              picker: _FixturePicker(),
              cashbackController: controller,
            ),
          ),
        ),
      ),
    );
    await _waitForImportReady(tester);
    final pick = find.text('Выбрать скриншоты');
    await tester.ensureVisible(pick);
    await tester.pumpAndSettle();
    await tester.tap(pick);
    await _waitFor(tester, find.text('Завершить проверку'));
    expect(repository.monthlySets, isEmpty);
    final bankButton = find.widgetWithText(OutlinedButton, 'Ozon Банк');
    await tester.ensureVisible(bankButton);
    await tester.pumpAndSettle();
    await tester.tap(bankButton);
    await _waitFor(tester, find.text('Название банка'));
    expect(tester.getTopLeft(bankButton).dy, lessThan(250));
    await tester.enterText(find.byType(TextField), 'oz');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ozon Банк').last);
    await tester.pumpAndSettle();
    expect(find.text('Название банка'), findsNothing);
    final review = find.text('Завершить проверку');
    await tester.ensureVisible(review);
    await tester.pumpAndSettle();
    await tester.tap(review);
    await _waitForImportReady(tester);
    expect(repository.monthlySets.single.categories, isNotEmpty);
    expect(repository.monthlySets.single.period, CashbackMonth(2026, 10));
    final reloaded = LocalCashbackRepository(directory: directory);
    await reloaded.load();
    expect(reloaded.monthlySets.single.categories, isNotEmpty);
    expect(reloaded.cards.single.bank, Bank.ozon);

    final originalCount = reloaded.monthlySets.single.categories.length;
    await tester.tap(find.text('Выбрать скриншоты'));
    await _waitFor(tester, find.text('Завершить проверку'));
    final repeatFinish = find.text('Завершить проверку');
    await tester.ensureVisible(repeatFinish);
    await tester.pumpAndSettle();
    await tester.tap(repeatFinish);
    await _waitForImportReady(tester);
    expect(repository.cards.length, 1);
    expect(repository.monthlySets.length, 1);
    expect(repository.monthlySets.single.categories.length, originalCount);

    await tester.tap(find.text('Выбрать скриншоты'));
    await _waitFor(tester, find.text('Выйти без сохранения новых категорий'));
    final exit = find.text('Выйти без сохранения новых категорий');
    await tester.ensureVisible(exit);
    await tester.pumpAndSettle();
    await tester.tap(exit);
    await _waitForImportReady(tester);
    expect(repository.monthlySets.single.categories.length, originalCount);
  });
}
