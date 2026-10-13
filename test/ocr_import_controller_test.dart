import 'dart:async';
import 'dart:io';

import 'package:balance_app/domain/ocr_engine.dart';
import 'package:balance_app/domain/ocr_models.dart';
import 'package:balance_app/logic/ocr_import_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailThenRead implements OcrEngine {
  int count = 0;
  @override
  Future<OcrDocument> recognize(String path, {String mode = 'sparse'}) async {
    if (count++ == 0) throw const OcrFailure('Ошибка первого изображения');
    return OcrDocument(
      lines: const [
        OcrLine(text: '5% Аптеки', left: .2, top: .5, right: .8, bottom: .6),
      ],
      width: 100,
      height: 100,
      engine: 'test-only',
      elapsedMs: 1,
    );
  }
}

class _WaitingEngine implements OcrEngine {
  final ready = Completer<OcrDocument>();
  @override
  Future<OcrDocument> recognize(String path, {String mode = 'sparse'}) =>
      ready.future;
}

void main() {
  test('Concurrent import is rejected before any async cleanup', () async {
    final firstDirectory = await Directory.systemTemp.createTemp(
      'cashback-import-',
    );
    final secondDirectory = await Directory.systemTemp.createTemp(
      'cashback-import-',
    );
    final engine = _WaitingEngine();
    final controller = OcrImportController(engine);
    final first = controller.import(['first'], firstDirectory);
    await expectLater(
      controller.import(['second'], secondDirectory),
      throwsStateError,
    );
    expect(await secondDirectory.exists(), isTrue);
    engine.ready.complete(
      OcrDocument(
        lines: const [],
        width: 1,
        height: 1,
        engine: 'test-only',
        elapsedMs: 0,
      ),
    );
    await first;
    await controller.clear();
    await secondDirectory.delete();
    controller.dispose();
  });
  test(
    'One failed image does not discard the next; session copies are removed',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cashback-import-',
      );
      await File('${directory.path}/copy')
          .writeAsString('private temporary fixture');
      final controller = OcrImportController(_FailThenRead());
      await controller.import(['first', 'second'], directory);
      expect(controller.results.length, 2);
      expect(controller.results.first.error, isNotNull);
      expect(
        controller.results.last.draft!.categories.single.originalName,
        'Аптеки',
      );
      await controller.clear();
      expect(await directory.exists(), isFalse);
      expect(controller.results, isEmpty);
      controller.dispose();
    },
  );
}
