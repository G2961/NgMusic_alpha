/// Награда сабмишена: `ul.trophies > li` на странице трека
/// (`frontpage`, `daily1`, `weekly1`, `monthly4`, `review`…).
class TrackAward {
  final String kind;
  final String label;
  final String date;

  const TrackAward({required this.kind, required this.label, this.date = ''});
}

class Track {
  final String id;
  final String title;
  final String artist;
  String genre;
  String iconUrl; // real CDN thumbnail parsed from NG (mutable: enrich can upgrade)
  final int duration; // seconds
  final int audioType;
  String? mp3Url;
  String? score;
  String? votes;

  /// `Listens` со страницы трека.
  String? listens;

  /// `Downloads` — реальные скачивания, это не то же самое, что прослушивания.
  String? downloads;
  String? faves;
  String? bpm;

  /// `Uploaded` — «May 27, 2026».
  String? uploaded;

  /// `File Info` — «Song | 3.1 MB | 6 min 4 sec».
  String? fileInfo;

  /// Теги из ссылок `/audio/browse/tag/{tag}`.
  List<String> tags = [];

  /// Награды (Frontpaged и пр.) — есть только у отмеченных треков.
  List<TrackAward> awards = [];

  /// Аватар автора (`uimg.ngfiles.com`).
  String? authorIcon;

  /// `Author Comments` — описание сабмишена текстом.
  String? description;

  /// `Licensing Terms` — условия использования.
  String? license;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.genre,
    required this.iconUrl,
    required this.duration,
    required this.audioType,
    this.mp3Url,
    this.score,
    this.votes,
    this.listens,
    this.downloads,
    this.faves,
    this.bpm,
  });

  bool get _hasRealIcon => iconUrl.contains('aicon.ngfiles.com');

  /// Папка CDN: `floor(id / 1000)` — для 1572356 это 1572.
  String? get _iconFolder {
    final numId = int.tryParse(id);
    return numId == null ? null : '${numId ~/ 1000}';
  }

  /// Small thumbnail for lists. Prefers the real CDN URL parsed from NG
  /// (fast static file, e.g. {id}_medium.webp?cachebust). Falls back to the
  /// server-rendered {id}_raw.png only when no real URL is available.
  String get aIconUrl {
    if (_hasRealIcon) return iconUrl;
    final folder = _iconFolder;
    if (folder == null) return iconUrl;
    return 'https://aicon.ngfiles.com/$folder/${id}_raw.png';
  }

  /// Обложка для плеера, от лучшего качества к худшему. `_raw` — исходник,
  /// который автор загрузил (png или jpg), дальше `_full.webp` и превью списка.
  List<String> get artworkUrls {
    final out = <String>[];
    final folder = _iconFolder;
    if (folder != null) {
      out.add('https://aicon.ngfiles.com/$folder/${id}_raw.png');
      out.add('https://aicon.ngfiles.com/$folder/${id}_raw.jpg');
    }
    if (_hasRealIcon) {
      out.add(iconUrl
          .replaceAll('_medium.', '_full.')
          .replaceAll('_small.', '_full.'));
      out.add(iconUrl);
    } else if (iconUrl.isNotEmpty) {
      out.add(iconUrl);
    }
    return out;
  }

  /// Larger artwork for the full-screen player — первый кандидат из
  /// [artworkUrls]; полный каскад с фоллбэками умеет `NgArtFrame`.
  String get largeIconUrl =>
      artworkUrls.isEmpty ? iconUrl : artworkUrls.first;

  /// https://audio.ngfiles.com/{floor(id/1000)*1000}/
  String get audioBaseUrl {
    final numId = int.tryParse(id);
    if (numId == null) return '';
    final folder = (numId ~/ 1000) * 1000;
    return 'https://audio.ngfiles.com/$folder/';
  }
}
