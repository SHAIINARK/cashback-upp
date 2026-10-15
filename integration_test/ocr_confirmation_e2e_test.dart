import 'dart:io';

import 'package:balance_app/app/theme.dart';
import 'package:balance_app/data/local_cashback_repository.dart';
import 'package:balance_app/domain/models.dart';
import 'package:balance_app/logic/cashback_controller.dart';
import 'package:balance_app/presentation/ocr_import_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Real OCR draft is saved only after explicit review', (
    tester,
  ) async {
    expect(await File(_fixture).exists(), isTrue);
    final directory = await Directory.systemTemp.createTemp('cashback-e2e-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final repository = LocalCashbackRepository(directory: directory);
    await repository.load();
    await repository.saveCard(
      BankCard(
        id: 'qa-ozon',
        bank: Bank.ozon,
        name: 'Тестовая карта',
        rewardType: RewardType.rubles,
      ),
    );
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
    await _waitFor(tester, find.text('Выбрать скриншоты'));
    final pick = find.text('Выбрать скриншоты');
    await tester.ensureVisible(pick);
    await tester.pumpAndSettle();
    await tester.tap(pick);
    await _waitFor(tester, find.text('Исправить и сохранить'));
    expect(repository.monthlySets, isEmpty);
    final review = find.text('Исправить и сохранить');
    await tester.ensureVisible(review);
    await tester.pumpAndSettle();
    await tester.tap(review);
    await _waitFor(tester, find.text('Подтвердить категории'));
    expect(find.text('Категории · отмечено 0'), findsOneWidget);
    expect(repository.monthlySets, isEmpty);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тестовая карта').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    expect(find.text('Категории · отмечено 1'), findsOneWidget);
    expect(repository.monthlySets, isEmpty);
    await tester.enterText(find.byType(TextField).first, '2026');
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.pumpAndSettle();
    final save = find.text('Проверить и сохранить');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Сохранить категории?'), findsOneWidget);
    expect(repository.monthlySets, isEmpty);
    await tester.tap(find.text('Сохранить').last);
    await tester.pumpAndSettle();
    expect(repository.monthlySets.single.categories, hasLength(1));
    expect(repository.monthlySets.single.period, CashbackMonth(2026, 10));
    final reloaded = LocalCashbackRepository(directory: directory);
    await reloaded.load();
    expect(reloaded.monthlySets.single.categories, hasLength(1));
    expect(reloaded.cards.single.bank, Bank.ozon);
  });
}
