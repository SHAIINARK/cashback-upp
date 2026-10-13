import 'dart:convert';
import 'dart:io';

import 'package:balance_app/domain/models.dart';
import 'package:balance_app/domain/ocr_models.dart';
import 'package:balance_app/logic/bank_screenshot_parser.dart';

// Re-evaluate parsing on recorded genuine OCR, without altering OCR lines.
// Private report stays ignored by Git. No raw user text enters stdout.
Future<void> main() async {
  final file = File('private-data/ocr-benchmark.json');
  final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final parser = BankScreenshotParser();
  for (final value in data['reports'] as List<dynamic>) {
    final report = value as Map<String, dynamic>;
    final document = OcrDocument(
      lines: (report['lines'] as List<dynamic>).map((value) {
        final line = value as Map<String, dynamic>;
        return OcrLine(
          text: line['text'] as String,
          left: (line['left'] as num).toDouble(),
          top: (line['top'] as num).toDouble(),
          right: (line['right'] as num).toDouble(),
          bottom: (line['bottom'] as num).toDouble(),
        );
      }),
      width: report['width'] as int,
      height: report['height'] as int,
      engine: report['engine'] as String,
      elapsedMs: report['elapsedMs'] as int,
    );
    final draft = parser.parse(
      document,
      bankHint: Bank.values.byName(report['bankHint'] as String),
    );
    report['categories'] = draft.categories
        .map(
          (category) => {
            'name': category.originalName,
            'percent': category.percent,
            'isUpTo': category.isUpTo,
            'notes': category.notes,
            'selectionUnknown': category.selectionUnknown,
          },
        )
        .toList();
    report['warnings'] = draft.warnings;
    report['month'] = draft.month;
    report['year'] = draft.year;
    stdout.writeln(
      'Fixture ${report['fixture']} / ${report['mode']}: ${draft.categories.length} candidates.',
    );
  }
  data['parserReplayed'] = true;
  await file.writeAsString(jsonEncode(data));
}
