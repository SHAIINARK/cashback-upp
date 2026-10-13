package ru.cashbackguide.balance_app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.os.SystemClock
import com.googlecode.tesseract.android.TessBaseAPI
import java.io.File
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** Local-only adapter: paths and recognition results are never written to logs. */
class LocalOcrEngine(private val context: Context) {
    fun recognize(path: String, mode: String, debugCandidates: Boolean = false): Map<String, Any> {
        val started = SystemClock.elapsedRealtime()
        val bitmap = decodeBounded(path)
        var engine: TessBaseAPI? = null
        val badgeImages = mutableListOf<Pair<Rect, Bitmap>>()
        try {
            val preparationStarted = SystemClock.elapsedRealtime()
            // Keep original-polarity light badges before normalizing the dark page.
            for (rect in findLightBadges(bitmap)) {
                badgeImages.add(rect to makeBadgeImage(bitmap, rect))
            }
            val badgePreparationMs = SystemClock.elapsedRealtime() - preparationStarted
            normalizeContrast(bitmap)
            val dataDirectory = prepareModels()
            val api = TessBaseAPI()
            engine = api
            check(api.init(dataDirectory.absolutePath + File.separator, "rus+eng", TessBaseAPI.OEM_LSTM_ONLY))
            api.setDebug(false)
            api.setPageSegMode(if (mode == "auto") TessBaseAPI.PageSegMode.PSM_AUTO else TessBaseAPI.PageSegMode.PSM_SPARSE_TEXT)
            api.setImage(bitmap)
            // Recognition must complete before obtaining a ResultIterator.
            api.getUTF8Text()
            val lines = mutableListOf<Map<String, Any>>()
            val iterator = api.resultIterator
            if (iterator != null) {
                try {
                    iterator.begin()
                    val level = TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE
                    do {
                        val text = iterator.getUTF8Text(level)?.trim().orEmpty()
                        if (text.isNotEmpty()) {
                            val rect = iterator.getBoundingRect(level)
                            lines.add(mapOf(
                                "text" to text,
                                "left" to (rect.left.toDouble() / bitmap.width).coerceIn(0.0, 1.0),
                                "top" to (rect.top.toDouble() / bitmap.height).coerceIn(0.0, 1.0),
                                "right" to (rect.right.toDouble() / bitmap.width).coerceIn(0.0, 1.0),
                                "bottom" to (rect.bottom.toDouble() / bitmap.height).coerceIn(0.0, 1.0),
                                "confidence" to iterator.confidence(level).toDouble().coerceIn(0.0, 100.0)
                            ))
                        }
                    } while (iterator.next(level))
                } finally {
                    iterator.delete()
                }
            }
            val badgeStarted = SystemClock.elapsedRealtime()
            val badgeSamples = mutableListOf<Map<String, Any>>()
            var badgeRates = 0
            api.setVariable(TessBaseAPI.VAR_CHAR_WHITELIST, "0123456789.,%")
            for ((rect, badge) in badgeImages) {
                api.clear()
                api.setPageSegMode(TessBaseAPI.PageSegMode.PSM_SINGLE_LINE)
                api.setImage(badge)
                val text = api.getUTF8Text()?.trim().orEmpty()
                val confidence = api.meanConfidence()
                if (debugCandidates) {
                    badgeSamples.add(mapOf("text" to text,
                        "left" to rect.left.toDouble() / bitmap.width,
                        "top" to rect.top.toDouble() / bitmap.height,
                        "right" to rect.right.toDouble() / bitmap.width,
                        "bottom" to rect.bottom.toDouble() / bitmap.height,
                        "confidence" to confidence))
                }
                if (confidence < 55) continue
                val match = RATE.matchEntire(text) ?: continue
                val rate = match.groupValues[1].replace(',', '.').toDoubleOrNull() ?: continue
                if (rate !in 0.0..100.0) continue
                val left = rect.left.toDouble() / bitmap.width
                val top = rect.top.toDouble() / bitmap.height
                val right = rect.right.toDouble() / bitmap.width
                val bottom = rect.bottom.toDouble() / bitmap.height
                val duplicate = lines.any { line ->
                    line["text"] == text &&
                        (line["left"] as Double) < right && (line["right"] as Double) > left &&
                        (line["top"] as Double) < bottom && (line["bottom"] as Double) > top
                }
                if (!duplicate) {
                    lines.add(mapOf("text" to text, "left" to left, "top" to top,
                        "right" to right, "bottom" to bottom, "confidence" to confidence.toDouble()))
                    badgeRates++
                }
            }
            val response = mutableMapOf<String, Any>(
                "engine" to "Tesseract4Android 4.9.0 (rus+eng, LSTM)",
                "width" to bitmap.width,
                "height" to bitmap.height,
                "elapsedMs" to SystemClock.elapsedRealtime() - started,
                "lines" to lines,
                "badgeCandidates" to badgeImages.size,
                "badgeRates" to badgeRates,
                "badgePreparationMs" to badgePreparationMs,
                "badgePassMs" to SystemClock.elapsedRealtime() - badgeStarted
            )
            if (debugCandidates) response["badgeSamples"] = badgeSamples
            return response
        } finally {
            engine?.recycle()
            badgeImages.forEach { it.second.recycle() }
            bitmap.recycle()
        }
    }

    private fun findLightBadges(bitmap: Bitmap): List<Rect> {
        val step = 3
        val columns = (bitmap.width + step - 1) / step
        val rows = (bitmap.height + step - 1) / step
        val mask = BooleanArray(columns * rows)
        for (y in 0 until rows) {
            for (x in 0 until columns) {
                mask[y * columns + x] = luminance(bitmap.getPixel(min(x * step, bitmap.width - 1), min(y * step, bitmap.height - 1))) >= 230
            }
        }
        val queue = IntArray(mask.size)
        val found = mutableListOf<Rect>()
        for (start in mask.indices) {
            if (!mask[start]) continue
            var head = 0
            var tail = 1
            queue[0] = start
            mask[start] = false
            var minX = columns
            var minY = rows
            var maxX = 0
            var maxY = 0
            while (head < tail) {
                val current = queue[head++]
                val x = current % columns
                val y = current / columns
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
                fun visit(index: Int) {
                    if (mask[index]) {
                        mask[index] = false
                        queue[tail++] = index
                    }
                }
                if (x > 0) visit(current - 1)
                if (x + 1 < columns) visit(current + 1)
                if (y > 0) visit(current - columns)
                if (y + 1 < rows) visit(current + columns)
            }
            val rect = Rect(minX * step, minY * step, min((maxX + 1) * step, bitmap.width), min((maxY + 1) * step, bitmap.height))
            val relativeWidth = rect.width().toDouble() / bitmap.width
            val relativeHeight = rect.height().toDouble() / bitmap.height
            val density = tail.toDouble() / ((maxX - minX + 1) * (maxY - minY + 1))
            if (relativeWidth in (45.0 / 1080)..(220.0 / 1080) &&
                relativeHeight in (30.0 / 2400)..(180.0 / 2400) &&
                rect.top.toDouble() / bitmap.height >= 0.06 && density > 0.3) {
                found.add(rect)
                if (found.size == 12) break
            }
        }
        return found
    }

    private fun makeBadgeImage(source: Bitmap, rect: Rect): Bitmap {
        val scale = 3
        val margin = 24
        val image = Bitmap.createBitmap(rect.width() * scale + margin * 2, rect.height() * scale + margin * 2, Bitmap.Config.ARGB_8888)
        var foreground: Bitmap? = null
        try {
            val width = rect.width()
            val height = rect.height()
            val dark = BooleanArray(width * height)
            for (y in 0 until height) {
                for (x in 0 until width) dark[y * width + x] = luminance(source.getPixel(rect.left + x, rect.top + y)) < 140
            }
            // Rounded badge corners contain the page's dark background. Remove only
            // dark components touching the crop edge; internal digits stay untouched.
            val queue = IntArray(dark.size)
            var tail = 0
            fun visit(index: Int) {
                if (dark[index]) {
                    dark[index] = false
                    queue[tail++] = index
                }
            }
            for (x in 0 until width) { visit(x); visit((height - 1) * width + x) }
            for (y in 0 until height) { visit(y * width); visit(y * width + width - 1) }
            var head = 0
            while (head < tail) {
                val index = queue[head++]
                val x = index % width
                val y = index / width
                if (x > 0) visit(index - 1)
                if (x + 1 < width) visit(index + 1)
                if (y > 0) visit(index - width)
                if (y + 1 < height) visit(index + width)
            }
            val pixels = IntArray(dark.size) { if (dark[it]) Color.BLACK else Color.WHITE }
            val cleaned = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            foreground = cleaned
            cleaned.setPixels(pixels, 0, width, 0, 0, width, height)
            val canvas = Canvas(image)
            canvas.drawColor(Color.WHITE)
            canvas.drawBitmap(cleaned, null, RectF(margin.toFloat(), margin.toFloat(), (margin + width * scale).toFloat(), (margin + height * scale).toFloat()), Paint(Paint.FILTER_BITMAP_FLAG))
            return image
        } catch (error: Throwable) {
            image.recycle()
            throw error
        } finally {
            foreground?.recycle()
        }
    }

    private fun prepareModels(): File {
        val root = File(context.filesDir, "tesseract")
        val models = File(root, "tessdata")
        check(models.exists() || models.mkdirs())
        for (language in listOf("rus", "eng")) {
            val name = "$language.traineddata"
            val destination = File(models, name)
            if (!destination.exists() || destination.length() == 0L) {
                val temporary = File(models, "$name.tmp")
                try {
                    context.assets.open("tessdata/$name").use { source ->
                        temporary.outputStream().use { target -> source.copyTo(target) }
                    }
                    check(temporary.renameTo(destination))
                } finally {
                    temporary.delete()
                }
            }
        }
        return root
    }

    private fun decodeBounded(path: String): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        require(bounds.outWidth > 0 && bounds.outHeight > 0)
        val maximumSide = 3000
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / sample > maximumSide) sample *= 2
        val options = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inMutable = true
        }
        val decoded = requireNotNull(BitmapFactory.decodeFile(path, options))
        val longest = max(decoded.width, decoded.height)
        if (longest <= maximumSide) return decoded
        val ratio = maximumSide.toDouble() / longest
        return try {
            Bitmap.createScaledBitmap(decoded, max(1, (decoded.width * ratio).roundToInt()), max(1, (decoded.height * ratio).roundToInt()), true)
        } finally {
            decoded.recycle()
        }
    }

    private fun normalizeContrast(bitmap: Bitmap) {
        // Median of a sparse grid is robust to small bright text on a dark UI.
        val samples = mutableListOf<Int>()
        for (y in 0 until bitmap.height step max(1, bitmap.height / 30)) {
            for (x in 0 until bitmap.width step max(1, bitmap.width / 20)) samples.add(luminance(bitmap.getPixel(x, y)))
        }
        samples.sort()
        val invert = samples[samples.size / 2] < 128
        val row = IntArray(bitmap.width)
        for (y in 0 until bitmap.height) {
            bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
            for (x in row.indices) {
                val brightness = luminance(row[x])
                val gray = if (invert) 255 - brightness else brightness
                row[x] = Color.rgb(gray, gray, gray)
            }
            bitmap.setPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
        }
    }

    private fun luminance(color: Int): Int = (Color.red(color) * 299 + Color.green(color) * 587 + Color.blue(color) * 114) / 1000

    companion object {
        private val RATE = Regex("^(?:до\\s*)?(\\d{1,3}(?:[.,]\\d+)?)\\s*%$", RegexOption.IGNORE_CASE)
    }
}
