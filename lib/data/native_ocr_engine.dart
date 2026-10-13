import 'package:flutter/services.dart';

import '../domain/ocr_engine.dart';
import '../domain/ocr_models.dart';

class NativeOcrEngine implements OcrEngine {
  const NativeOcrEngine();
  static const _channel = MethodChannel('cashback/ocr');

  @override
  Future<OcrDocument> recognize(String path, {String mode = 'sparse'}) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'recognize',
        {'path': path, 'mode': mode},
      );
      if (result == null) {
        throw const OcrFailure('Распознавание не вернуло результат.');
      }
      final lines = (result['lines'] as List<dynamic>).map((raw) {
        final line = Map<String, dynamic>.from(raw as Map);
        return OcrLine(
          text: line['text'] as String,
          left: (line['left'] as num).toDouble(),
          top: (line['top'] as num).toDouble(),
          right: (line['right'] as num).toDouble(),
          bottom: (line['bottom'] as num).toDouble(),
        );
      });
      return OcrDocument(
        lines: lines,
        width: result['width'] as int,
        height: result['height'] as int,
        engine: result['engine'] as String,
        elapsedMs: result['elapsedMs'] as int,
        diagnostics: {
          for (final key in [
            'badgeCandidates',
            'badgeRates',
            'badgePreparationMs',
            'badgePassMs',
          ])
            if (result[key] is num) key: result[key] as num,
        },
      );
    } on PlatformException catch (error) {
      throw OcrFailure(switch (error.code) {
        'LANGUAGE_UNSUPPORTED' => 'На этой версии iOS русский текст не поддерживается. Можно использовать ручной ввод в следующей версии.',
        'IMAGE_UNREADABLE' =>
          'Не удалось открыть изображение. Выберите другой скриншот.',
        _ => 'Не удалось распознать изображение. Попробуйте другой скриншот.',
      });
    } on MissingPluginException {
      throw const OcrFailure(
        'Распознавание доступно только в мобильной сборке.',
      );
    }
  }
}
