# Исследование локального OCR

Дата: **13 октября 2026 года**. Цель — выбрать основу технического прототипа для русских банковских скриншотов Android и iOS. Этот документ описывает подтверждённые возможности и ограничения движков, а не измеренную точность или скорость приложения.

## Сравнение

| Вариант | Русский текст и локальная обработка | Применение в проекте |
|---|---|---|
| Tesseract + Tesseract4Android | Официальная модель `rus`; модель `eng` нужна для смешанных названий. Встроенные модели позволяют обрабатывать изображения без сети. | Начальная экспериментальная основа Android. Нативный адаптер изолирован от банковских правил и пользовательских моделей. |
| Google ML Kit Text Recognition v2 | Официальная документация перечисляет Latin, Chinese, Devanagari, Japanese и Korean. Русский не заявлен среди поддерживаемых языков OCR; наличие отдельных записей Cyrl в таблице mapped languages не подтверждает доступный русский recognizer Android. | Не использовать как гарантированную основу кириллицы. Поддержка Russian в Language Identification относится к определению языка уже готового текста, а не OCR. |
| Apple Vision | Системный локальный API. Доступные языки зависят от версии ОС, revision и режима распознавания. | Адаптер создан с runtime-проверкой `supportedRecognitionLanguages()`. Без `ru`/`ru-*` возвращает `LANGUAGE_UNSUPPORTED`, а не выдаёт английское распознавание за русское. |
| PaddleOCR mobile | Официальные модели `cyrillic_PP-OCRv5_mobile_rec` и `eslav_PP-OCRv5_mobile_rec` включают Russian и English. | Резерв для отдельного эксперимента, если начальный движок недостаточен. Нужны детектор текста, распознаватель и интеграция мобильного runtime; это сложнее простой замены языковой модели. |

## Начальный Android-подход

- Нативный bridge к Tesseract4Android; Dart получает независимые строки, текст, координаты и confidence.
- `rus+eng` из официального `tessdata_fast` поставляются в APK и копируются в приватный каталог приложения. Загрузка моделей во время OCR не нужна.
- Модели и их SHA-256 закреплены в [ocr-models.json](ocr-models.json); лицензия поставляемых моделей — [asset LICENSE](../android/app/src/main/assets/tessdata/LICENSE).
- `tessdata_fast` — экспериментальная начальная конфигурация. `tessdata_best` следует сравнить при необходимости: документация описывает его как более точный, но более медленный вариант. Это описание семейства моделей, а не измерение на наших скриншотах.
- Для fast/best нужен LSTM-режим OEM 1; legacy-режим для этих файлов не поддерживается.
- Проверяются сегментация разреженного текста, оригинальные и инвертированные тёмные изображения. Один экземпляр `TessBaseAPI` нельзя использовать параллельно.
- Координаты необходимы для связи процента с категорией и исключения рекламы; банковские правила остаются отдельным слоем.

## Что OCR не гарантирует

Галочка выбранной категории — элемент изображения, а не текстовая категория OCR. Её определение требует отдельной обработки и проверки. Даже видимая галочка не доказывает, что пользователь сохранил выбор в банковском приложении.

OCR также не устанавливает полноту горизонтальной ленты, действительность предложения, год при его отсутствии, соответствие MCC или оставшийся лимит кэшбэка. Результат является черновиком для подтверждения пользователем.

## iOS

Bridge `cashback/ocr` создан в `ios/Runner/AppDelegate.swift`: Vision accurate, локальная обработка на фоновой очереди, исправление ориентации, координаты от верхнего левого угла и проверка русского языка во время выполнения. Используется системный Vision, без скачивания Tesseract-моделей на iOS.

**Bridge не скомпилирован на macOS и не проверен на iPhone.** Наличие исходного Swift-кода не подтверждает сборку или качество русского OCR. На неподдерживаемой версии ОС показывается ошибка языка. Минимальную поддерживаемую версию iOS следует окончательно выбрать после проверки на Mac и устройстве.

## Лицензии и зависимости

- Tesseract, официальные tessdata-модели и Tesseract4Android: Apache-2.0; сохранять уведомления и лицензии при распространении.
- Tesseract4Android использует также Leptonica, libjpeg и libpng, имеющие собственные лицензии. Их уведомления должны попасть в итоговый перечень сторонних компонентов; Apache-лицензия обёртки не заменяет их.
- PaddleOCR и рассмотренная официальная Cyrillic-модель: Apache-2.0. Лицензию выбранного runtime нужно проверить отдельно при интеграции.
- ML Kit и Apple Vision — платформенные SDK со своими условиями использования; их нельзя обозначать Apache-2.0 по лицензии Flutter-обёртки.

## Первичные источники

- [Tesseract: лицензия и установка](https://tesseract-ocr.github.io/tessdoc/Installation.html).
- [Tesseract: языки и fast/best](https://tesseract-ocr.github.io/tessdoc/Data-Files.html).
- [Tesseract4Android: интеграция, зависимости и лицензия](https://github.com/adaptech-cz/Tesseract4Android).
- [TessBaseAPI: координаты, confidence и отмена](https://github.com/adaptech-cz/Tesseract4Android/blob/master/tesseract4android/src/main/java/com/googlecode/tesseract/android/TessBaseAPI.java).
- [ML Kit: наборы символов](https://developers.google.com/ml-kit/vision/text-recognition/v2), [языковая таблица](https://developers.google.com/ml-kit/vision/text-recognition/v2/languages), [Android и bundled model](https://developers.google.com/ml-kit/vision/text-recognition/v2/android).
- [Apple Vision: OCR и проверка языков](https://developer.apple.com/documentation/vision/recognizing-text-in-images), [supportedRecognitionLanguages](https://developer.apple.com/documentation/Vision/RecognizeTextRequest/supportedRecognitionLanguages).
- [PaddleOCR: официальные многоязычные модели](https://github.com/PaddlePaddle/PaddleOCR/blob/main/docs/version3.x/algorithm/PP-OCRv5/PP-OCRv5_multi_languages.en.md), [официальная Cyrillic-модель и её лицензия](https://huggingface.co/PaddlePaddle/cyrillic_PP-OCRv5_mobile_rec).

Фактические результаты устройства и скриншотов фиксируются в отдельном отчёте проверки. Пять примеров не доказывают качество на всех версиях банковских интерфейсов.
