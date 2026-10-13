package ru.cashbackguide.balance_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ocr = LocalOcrEngine(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cashback/ocr")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                val mode = call.argument<String>("mode") ?: "sparse"
                val debugCandidates = BuildConfig.DEBUG && (call.argument<Boolean>("debugCandidates") == true)
                if (path.isNullOrBlank() || mode !in listOf("sparse", "auto")) {
                    result.error("invalid_input", "Некорректные параметры изображения.", null)
                    return@setMethodCallHandler
                }
                worker.execute {
                    try {
                        val response = ocr.recognize(path, mode, debugCandidates)
                        mainHandler.post { result.success(response) }
                    } catch (_: OutOfMemoryError) {
                        mainHandler.post { result.error("image_too_large", "Недостаточно памяти для изображения.", null) }
                    } catch (_: LinkageError) {
                        mainHandler.post { result.error("engine_unavailable", "Распознавание недоступно на этом устройстве.", null) }
                    } catch (_: Exception) {
                        mainHandler.post { result.error("recognition_failed", "Не удалось обработать изображение. Попробуйте другой скриншот.", null) }
                    }
                }
            }
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }
}
