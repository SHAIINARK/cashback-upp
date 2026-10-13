import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "cashback/ocr",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognize" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String, !path.isEmpty
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Не указан скриншот.", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        let response = LocalScreenshotOcr.recognize(path: path)
        DispatchQueue.main.async { result(response) }
      }
    }
  }
}

private enum LocalScreenshotOcr {
  static func recognize(path: String) -> Any {
    let started = ProcessInfo.processInfo.systemUptime
    guard let source = UIImage(contentsOfFile: path) else {
      return FlutterError(code: "IMAGE_UNREADABLE", message: "Не удалось открыть скриншот.", details: nil)
    }
    // Draw upright at its original pixel resolution so Vision and the preview
    // share top-left coordinates, including images with EXIF rotation.
    let format = UIGraphicsImageRendererFormat()
    format.scale = source.scale
    let upright = UIGraphicsImageRenderer(size: source.size, format: format).image { _ in
      source.draw(in: CGRect(origin: .zero, size: source.size))
    }
    guard let image = upright.cgImage else {
      return FlutterError(code: "IMAGE_UNREADABLE", message: "Не удалось подготовить скриншот.", details: nil)
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    do {
      let supported: [String]
      if #available(iOS 15.0, *) {
        supported = try request.supportedRecognitionLanguages()
      } else {
        supported = try VNRecognizeTextRequest.supportedRecognitionLanguages(
          for: .accurate, revision: request.revision
        )
      }
      guard let russian = supported.first(where: {
        $0 == "ru" || $0.hasPrefix("ru-")
      }) else {
        return FlutterError(
          code: "LANGUAGE_UNSUPPORTED",
          message: "Эта версия iOS не поддерживает локальное распознавание русского текста.",
          details: nil
        )
      }
      request.recognitionLanguages = [russian]
      if let english = supported.first(where: { $0 == "en" || $0.hasPrefix("en-") }) {
        request.recognitionLanguages.append(english)
      }
      try VNImageRequestHandler(cgImage: image, orientation: .up, options: [:]).perform([request])
      let lines: [[String: Any]] = (request.results ?? []).compactMap { observation in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        let box = observation.boundingBox
        return [
          "text": candidate.string,
          "left": Double(box.minX),
          "top": Double(1 - box.maxY),
          "right": Double(box.maxX),
          "bottom": Double(1 - box.minY),
          "confidence": Double(candidate.confidence),
        ]
      }
      return [
        "engine": "apple-vision",
        "width": image.width,
        "height": image.height,
        "elapsedMs": Int((ProcessInfo.processInfo.systemUptime - started) * 1000),
        "lines": lines,
      ]
    } catch {
      // Deliberately omit native error details: paths and recognized content
      // must never leak into application logs or diagnostic messages.
      return FlutterError(code: "OCR_FAILED", message: "Не удалось распознать скриншот.", details: nil)
    }
  }
}
