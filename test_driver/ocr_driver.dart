import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  final device = Platform.environment['OCR_DEVICE'] ?? 'RF8T1051S0V';
  final package =
      Platform.environment['OCR_PACKAGE'] ?? 'ru.cashbackguide.balance_app.qa';
  // flutter drive may reinstall the app. Prepare private inputs only after its
  // installation and before the paused test isolate is resumed by the driver.
  final preparation = await Process.run('pwsh', [
    '-NoProfile',
    '-File',
    'tool/prepare_ocr_fixtures.ps1',
    '-Device',
    device,
    '-Package',
    package,
  ]);
  if (preparation.exitCode != 0) {
    throw StateError(
      'Не удалось подготовить приватные изображения для проверки.',
    );
  }
  await integrationDriver(
    timeout: const Duration(minutes: 5),
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      await Directory('private-data').create(recursive: true);
      final report = Map<String, dynamic>.from(data ?? {});
      final screenshots = report.remove('screenshots') as List<dynamic>?;
      if (screenshots != null) {
        for (final screenshot in screenshots) {
          final entry = Map<String, dynamic>.from(screenshot as Map);
          await File('private-data/ocr-review.png')
              .writeAsBytes((entry['bytes'] as List<dynamic>).cast<int>());
        }
      }
      await File('private-data/ocr-benchmark.json')
          .writeAsString(jsonEncode(report));
      await Process.run('D:\\dev-tools\\android-sdk\\platform-tools\\adb.exe', [
        '-s',
        device,
        'shell',
        'run-as',
        package,
        'rm',
        '-r',
        'files/ocr-fixtures',
      ]);
    },
  );
}
