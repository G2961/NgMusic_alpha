# NGMusic Flutter

Полный порт Kotlin/Jetpack Compose → Flutter/Dart.

## Что сохранено 1:1

| Kotlin | Flutter |
|---|---|
| `NgRepository` (jsoup) | `NgRepository` (html package) |
| Парсинг `li[data-hub-id]` | Идентичный CSS-селектор |
| Парсинг поиска `ul.itemlist li:has(.audio-wrapper)` | Идентичный |
| `getMp3Url` (og:audio meta → buildAudioUrl) | Идентичный |
| `getTrackStats` (score/votes/downloads) | Идентичный |
| `loadMore()` с дедупликацией по ID | Идентичный |
| `playNext()` → триггер `loadMore()` при конце списка | Идентичный |
| NG-палитра (все hex-цвета) | Идентичный |
| Infinity scroll (threshold = 4 от конца) | ScrollController listener |
| User-Agent header | Идентичный |

## Замены

| Kotlin/Android | Flutter |
|---|---|
| `media3-exoplayer` + `MediaSession` | `just_audio` + `audio_service` |
| `coil` | `cached_network_image` |
| `StateFlow` + `collectAsState()` | `ChangeNotifier` + `Provider` |
| `DownloadManager` | `url_launcher` (открывает mp3 в браузере) |

## Сборка

```bash
flutter pub get
flutter run                    # дев-режим
flutter build apk --release   # релизный APK
```

Минимальный SDK: **Android 5.0 (API 21)** — down от Kotlin-версии (API 24),
потому что just_audio поддерживает API 21+.

## Структура

```
lib/
├── data/
│   ├── model/track.dart          # Track data class
│   └── repository/ng_repository.dart  # HTML парсинг (jsoup → html package)
├── player/
│   └── ng_audio_handler.dart     # just_audio + audio_service handler
├── ui/
│   ├── screens/
│   │   ├── hub_screen.dart       # Список треков, поиск, табы, infinity scroll
│   │   └── player_screen.dart    # Полноэкранный плеер
│   └── theme/ng_theme.dart       # NG-цвета
├── viewmodel/
│   └── ng_viewmodel.dart         # Логика (порт MainViewModel)
└── main.dart                     # Точка входа
```
