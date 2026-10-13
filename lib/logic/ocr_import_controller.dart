import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/ocr_engine.dart';
import '../domain/ocr_models.dart';
import '../domain/models.dart';
import 'bank_screenshot_parser.dart';

class ScreenshotResult {
  const ScreenshotResult({
    required this.path,
    this.document,
    this.draft,
    this.error,
  });
  final String path;
  final OcrDocument? document;
  final ParsedScreenshot? draft;
  final String? error;
}

/// Session-owned files are private copies, never the user's gallery originals.
class OcrImportController extends ChangeNotifier {
  OcrImportController(this.engine);
  final OcrEngine engine;
  final parser = BankScreenshotParser();
  List<ScreenshotResult> _results = const [];
  List<ScreenshotResult> get results => _results;
  bool busy = false;
  int completed = 0;
  int total = 0;
  Directory? _directory;
  bool _disposed = false;

  Future<void> import(List<String> paths, Directory directory) async {
    if (busy) throw StateError('Импорт уже выполняется.');
    busy = true;
    final results = <ScreenshotResult>[];
    try {
      await clear();
      _directory = directory;
      completed = 0;
      total = paths.length;
      _notify();
      for (final path in paths) {
        try {
          var document = await engine.recognize(path);
          var draft = parser.parse(document);
          // Ozon's dense list fares better in AUTO in the initial real corpus.
          // This is a layout policy, not an assumption about OCR correctness.
          if (draft.bank == Bank.ozon) {
            try {
              final alternative = await engine.recognize(path, mode: 'auto');
              final alternativeDraft = parser.parse(alternative);
              if (alternativeDraft.categories.isNotEmpty) {
                document = OcrDocument(
                  lines: alternative.lines,
                  width: alternative.width,
                  height: alternative.height,
                  engine: alternative.engine,
                  elapsedMs: document.elapsedMs + alternative.elapsedMs,
                  diagnostics: alternative.diagnostics,
                );
                draft = alternativeDraft;
              }
            } on OcrFailure {
              // Keep the first result as an explicitly unconfirmed draft.
            }
          }
          results.add(
            ScreenshotResult(path: path, document: document, draft: draft),
          );
        } on OcrFailure catch (error) {
          results.add(ScreenshotResult(path: path, error: error.message));
        } catch (_) {
          results.add(
            ScreenshotResult(
              path: path,
              error: 'Не удалось обработать этот скриншот.',
            ),
          );
        }
        completed++;
        _notify();
      }
      _results = List.unmodifiable(results);
    } finally {
      busy = false;
      if (_disposed) {
        await clear();
      } else {
        _notify();
      }
    }
  }

  Future<void> clear() async {
    final directory = _directory;
    _directory = null;
    _results = const [];
    // Only directories created by our importer are accepted as session storage.
    if (directory != null &&
        directory.path
            .split(Platform.pathSeparator)
            .last
            .startsWith('cashback-import-')) {
      try {
        if (await directory.exists()) await directory.delete(recursive: true);
      } on FileSystemException {
        // OS cache eviction is a fallback; no sensitive paths enter diagnostics.
      }
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (!busy) clear();
    super.dispose();
  }
}
