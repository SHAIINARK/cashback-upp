import 'models.dart';

/// Engine-independent OCR geometry, normalized to the image bounds.
class OcrLine {
  const OcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
  final String text;
  final double left, top, right, bottom;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
}

class OcrDocument {
  OcrDocument({
    required Iterable<OcrLine> lines,
    required this.width,
    required this.height,
    required this.engine,
    required this.elapsedMs,
    Map<String, num> diagnostics = const {},
  }) : lines = List.unmodifiable(lines),
       diagnostics = Map.unmodifiable(diagnostics);
  final List<OcrLine> lines;
  final int width, height, elapsedMs;
  final String engine;
  final Map<String, num> diagnostics;
}

class ParsedCategory {
  const ParsedCategory({
    required this.originalName,
    required this.percent,
    this.isUpTo = false,
    this.notes = '',
    this.selectionUnknown = false,
  });
  final String originalName;
  final double percent;
  final bool isUpTo, selectionUnknown;
  final String notes;
}

/// A draft only: never evidence of activation or a confirmed monthly set.
class ParsedScreenshot {
  ParsedScreenshot({
    this.bank,
    this.month,
    this.year,
    required Iterable<ParsedCategory> categories,
    required Iterable<String> warnings,
  }) : categories = List.unmodifiable(categories),
       warnings = List.unmodifiable(warnings);
  final Bank? bank;
  final int? month, year;
  final List<ParsedCategory> categories;
  final List<String> warnings;
}
