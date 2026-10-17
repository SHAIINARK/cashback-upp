# Подготовка Android-релиза

Целевые магазины: Google Play и RuStore. Публикация ещё не выполнена. Отладочная версия на телефоне подписана другим ключом; нельзя устанавливать релиз поверх неё без предварительного сохранения данных. Экспорт данных пока отложен, поэтому обычную установленную версию не удалять.

16.10.2026 собраны `build/app/outputs/bundle/standardRelease/app-standard-release.aab` и `build/app/outputs/flutter-apk/app-standard-release.apk` версии 0.6.1 (код 10). Оба файла подписаны постоянным ключом с SHA-256 отпечатком `CC:DF:61:DE:8F:03:AB:AF:A0:31:E1:B0:39:C2:29:43:95:61:D6:01:EA:09:7C:6E:76:95:73:35:BD:34:74:F2`. APK имеет `targetSdkVersion` 36. На устройстве эта релизная сборка пока не проверялась.

## Решения до первого магазинного пакета

1. Окончательный `applicationId` — `ru.cashbackguide.balance_app`, утверждён владельцем 16.10.2026. После первой публикации смена идентификатора означает новое приложение в магазинах.
2. Постоянный ключ подписи хранится вне проекта в `D:/dev-tools/signing/cashback-release.jks`. Пароль находится только в игнорируемом Git файле `android/key.properties`. **Владельцу нужно сделать собственную резервную копию обоих файлов на другом носителе**: копия на том же диске D не защищает от поломки диска. Для бесшовных обновлений между магазинами нужен одинаковый сертификат подписи устанавливаемых пакетов. При настройке Play App Signing выбрать загрузку собственного ключа подписи приложения; отдельно может использоваться upload key. Сверить сертификаты Google Play и RuStore до выпуска.
3. Подготовить описание, значок, изображения, политику конфиденциальности, данные о сборе информации и аккаунты разработчика. Затем провести закрытое тестирование на реальных Android-устройствах.

## Локальная сборка после принятия решений

Для повторной сборки используются существующие `android/key.properties` и `D:/dev-tools/signing/cashback-release.jks`. Ключ и пароли нельзя коммитить. После переноса на другой компьютер восстановить оба файла из личной резервной копии; `android/key.properties.example` показывает формат. Настроить переменные среды Flutter/Android из README и выполнить:

```powershell
flutter pub get
flutter build appbundle --release --flavor standard
flutter build apk --release --flavor standard
```

Для Google Play предназначен AAB, для RuStore можно загрузить APK или AAB с учётом настройки подписи в консоли. Перед загрузкой проверить материалы и поля магазина, а подписанную версию запустить на отдельном тестовом устройстве. Не заменять ею установленную отладочную копию с локальными данными без способа их переноса.

Официальные требования: [Google Play — целевой Android API](https://developer.android.com/google/play/requirements/target-sdk), [Android — подпись и Play App Signing](https://developer.android.com/studio/publish/app-signing), [RuStore — публикация](https://www.rustore.ru/help/developers/publishing-and-verifying-apps/app-publication), [RuStore — подпись APK](https://www.rustore.ru/help/developers/publishing-and-verifying-apps/app-publication/apk-signature), [RuStore — AAB](https://www.rustore.ru/help/developers/publishing-and-verifying-apps/app-publication/new-version-app/upload-aab). Требования перепроверить перед отправкой: они могут измениться.
