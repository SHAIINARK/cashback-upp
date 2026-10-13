import 'dart:io';

import 'package:balance_app/data/native_ocr_engine.dart';
import 'package:balance_app/domain/models.dart';
import 'package:balance_app/logic/bank_screenshot_parser.dart';
import 'package:balance_app/presentation/ocr_import_screen.dart';
import 'package:balance_app/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Picker-only substitution: real private image, real on-device OCR, real UI.
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
  }) async => [
    XFile('/data/user/0/ru.cashbackguide.balance_app/files/ocr-fixtures/1.jpg'),
  ];
}

/// Private fixtures are supplied to app-private files by the host, not bundled.
/// No image or raw recognition result is printed to console or committed.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('On-device local OCR benchmark, private fixture corpus', (
    tester,
  ) async {
    const engine = NativeOcrEngine();
    final parser = BankScreenshotParser();
    const banks = [Bank.ozon, Bank.sber, Bank.alfa, Bank.tbank, Bank.vtb];
    final reports = <Map<String, dynamic>>[];
    for (var i = 0; i < banks.length; i++) {
      final file = File(
        '/data/user/0/ru.cashbackguide.balance_app/files/ocr-fixtures/${i + 1}.jpg',
      );
      expect(
        await file.exists(),
        isTrue,
        reason:
            'Private benchmark fixture ${i + 1} is missing; do not replace it with synthetic data.',
      );
      for (final mode in ['sparse', 'auto']) {
        final document = await engine.recognize(file.path, mode: mode);
        final draft = parser.parse(document, bankHint: banks[i]);
        final automatic = parser.parse(document);
        expect(
          document.lines.isNotEmpty,
          isTrue,
          reason: 'No OCR lines for fixture ${i + 1}.',
        );
        reports.add({
          'fixture': i + 1,
          'bankHint': banks[i].name,
          'detectedBank': automatic.bank?.name,
          'mode': mode,
          'engine': document.engine,
          'width': document.width,
          'height': document.height,
          'elapsedMs': document.elapsedMs,
          'diagnostics': document.diagnostics,
          'month': draft.month,
          'year': draft.year,
          'categories': draft.categories
              .map(
                (c) => {
                  'name': c.originalName,
                  'percent': c.percent,
                  'isUpTo': c.isUpTo,
                  'notes': c.notes,
                  'selectionUnknown': c.selectionUnknown,
                },
              )
              .toList(),
          'warnings': draft.warnings,
          'lines': document.lines
              .map(
                (l) => {
                  'text': l.text,
                  'left': l.left,
                  'top': l.top,
                  'right': l.right,
                  'bottom': l.bottom,
                },
              )
              .toList(),
        });
      }
    }
    binding.reportData = {'reports': reports};
    final badgeDebug = await const MethodChannel('cashback/ocr')
        .invokeMapMethod<String, dynamic>('recognize', {
          'path': '/data/user/0/ru.cashbackguide.balance_app/files/ocr-fixtures/2.jpg',
          'mode': 'sparse',
          'debugCandidates': true,
        });
    binding.reportData!['badgeDiagnostics'] = badgeDebug?['badgeSamples'];
    // Runtime evidence is inspected privately by the host after the test.
    expect(reports.length, 10);
  });

  testWidgets(
    'Real image passes importer and review; gallery original is retained',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: SafeArea(child: ImportScreen(picker: _FixturePicker())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.text('Выбрать скриншоты');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      final buttonWidget = find
          .ancestor(
            of: button,
            matching: find.byWidgetPredicate(
              (widget) => widget is FilledButton,
            ),
          )
          .first;
      for (
        var i = 0;
        i < 100 && tester.widget<FilledButton>(buttonWidget).onPressed == null;
        i++
      ) {
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(
        tester.widget<FilledButton>(buttonWidget).onPressed,
        isNotNull,
        reason: 'Picker remained disabled after recovery.',
      );
      await tester.tap(button);
      for (
        var i = 0;
        i < 120 && find.text('Проверка импорта').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('Найденные категории: 5'), findsOneWidget);
      expect(find.text('Фастфуд'), findsOneWidget);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('ocr-review');
      final finish = find.text('Завершить проверку');
      await tester.ensureVisible(finish);
      await tester.pumpAndSettle();
      await tester.tap(finish);
      await tester.pumpAndSettle();
      expect(
        await File(
          '/data/user/0/ru.cashbackguide.balance_app/files/ocr-fixtures/1.jpg',
        ).exists(),
        isTrue,
      );
      binding.reportData!['uiSmokeTest'] = 'passed';
    },
  );
}
