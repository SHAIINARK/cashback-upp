# Подготовка Android-релиза

Целевые магазины: Google Play и RuStore. Публикация ещё не выполнена. Отладочная версия на телефоне подписана другим ключом; нельзя устанавливать релиз поверх неё без предварительного сохранения данных. Экспорт данных пока отложен, поэтому обычную установленную версию не удалять.

## Решения до первого магазинного пакета

1. Утвердить окончательный `applicationId`. Сейчас `ru.cashbackguide.balance_app` — предварительное значение. После первой публикации смена идентификатора означает новое приложение в магазинах.
2. Создать долговременный ключ подписи с большим сроком действия и хранить резервную копию отдельно от проекта и Git. Для бесшовных обновлений между магазинами нужен одинаковый сертификат подписи устанавливаемых пакетов. При настройке Play App Signing выбрать загрузку собственного ключа подписи приложения; отдельно может использоваться upload key. Сверить сертификаты Google Play и RuStore до выпуска.
3. Подготовить описание, значок, изображения, политику конфиденциальности, данные о сборе информации и аккаунты разработчика. Затем провести закрытое тестирование на реальных Android-устройствах.

## Локальная сборка после принятия решений

Скопировать `android/key.properties.example` в игнорируемый Git файл `android/key.properties`, указать путь к настоящему `.jks` и пароли. Ключ и пароли нельзя коммитить. Настроить переменные среды Flutter/Android из README и выполнить:

```powershell
flutter pub get
flutter build appbundle --release --flavor standard
flutter build apk --release --flavor standard
```

Для Google Play предназначен AAB, для RuStore можно загрузить APK или AAB с учётом настройки подписи в консоли. Проверить пакет, версию, разрешения, сертификат и запуск на отдельной тестовой установке до загрузки. Текущая пробная AAB проверила только сборочный путь на временном ключе; она не предназначена для публикации.

Официальные требования: [Google Play — целевой Android API](https://developer.android.com/google/play/requirements/target-sdk), [Android — подпись и Play App Signing](https://developer.android.com/studio/publish/app-signing), [RuStore — публикация](https://www.rustore.ru/help/developers/publishing-and-verifying-apps/app-publication), [RuStore — подпись APK](https://www.rustore.ru/help/developers/publishing-and-verifying-apps/app-publication/apk-signature), [RuStore — AAB](https://www.rustore.ru/help/developers/publishing-and-verifying-apps/app-publication/new-version-app/upload-aab). Требования перепроверить перед отправкой: они могут измениться.
