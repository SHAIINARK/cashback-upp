import 'ocr_models.dart';

/// Replaceable on-device recognizer; independent of parser and user storage.
abstract interface class OcrEngine {
  Future<OcrDocument> recognize(String path, {String mode = 'sparse'});
}

class OcrFailure implements Exception {
  const OcrFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
