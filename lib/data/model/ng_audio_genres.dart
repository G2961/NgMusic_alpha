/// Сайдбар жанров аудио-портала 2015 (`ul.sideNav` на /audio).
///
/// Числовые ID — из живого справочника NG (`<select name="genre">`
/// на /audio/browse), каждый проверен прогоном: карточки содержат
/// только свой жанр. Пустые на NG жанры (Brit Pop=22, Bluegrass=1)
/// оставлены — фильтр валиден, треков просто нет.
///
/// Группы Podcasts и Voice Acting числовых ID НЕ имеют — NG фильтрует
/// их только через сайдбар-ссылки, которые browse игнорирует. Поэтому
/// их поджанры не показываем: группа раскрыта быть может, но пункты
/// без фильтра вводят в заблуждение — выпилены целиком.
class NgGenreGroup {
  final String label;

  /// Поджанры с рабочими ID.
  final List<NgGenre> genres;

  const NgGenreGroup({required this.label, required this.genres});
}

class NgGenre {
  final String id;
  final String label;

  const NgGenre({required this.id, required this.label});
}

class NgAudioGenres {
  static const groups = <NgGenreGroup>[
    NgGenreGroup(label: 'Easy Listening', genres: [
      NgGenre(id: '3', label: 'Classical'),
      NgGenre(id: '18', label: 'Jazz'),
      NgGenre(id: '51', label: 'Solo Instrument'),
    ]),
    NgGenreGroup(label: 'Electronic', genres: [
      NgGenre(id: '5', label: 'Ambient'),
      NgGenre(id: '48', label: 'Chipstep'),
      NgGenre(id: '6', label: 'Dance'),
      NgGenre(id: '7', label: 'Drum N Bass'),
      NgGenre(id: '41', label: 'Dubstep'),
      NgGenre(id: '9', label: 'House'),
      NgGenre(id: '59', label: 'Hyperpop'),
      NgGenre(id: '8', label: 'Industrial'),
      NgGenre(id: '20', label: 'New Wave'),
      NgGenre(id: '58', label: 'Phonk'),
      NgGenre(id: '57', label: 'Synthwave'),
      NgGenre(id: '10', label: 'Techno'),
      NgGenre(id: '11', label: 'Trance'),
      NgGenre(id: '12', label: 'Video Game'),
    ]),
    NgGenreGroup(label: 'Hip Hop, Rap, R&B', genres: [
      NgGenre(id: '17', label: 'Hip Hop - Modern'),
      NgGenre(id: '16', label: 'Hip Hop - Olskool'),
      NgGenre(id: '47', label: 'Nerdcore'),
      NgGenre(id: '21', label: 'R&B'),
    ]),
    NgGenreGroup(label: 'Metal, Rock', genres: [
      NgGenre(id: '22', label: 'Brit Pop'),
      NgGenre(id: '23', label: 'Classic Rock'),
      NgGenre(id: '24', label: 'General Rock'),
      NgGenre(id: '25', label: 'Grunge'),
      NgGenre(id: '15', label: 'Heavy Metal'),
      NgGenre(id: '26', label: 'Indie'),
      NgGenre(id: '27', label: 'Pop'),
      NgGenre(id: '28', label: 'Punk'),
    ]),
    NgGenreGroup(label: 'Other', genres: [
      NgGenre(id: '50', label: 'Cinematic'),
      NgGenre(id: '49', label: 'Experimental'),
      NgGenre(id: '13', label: 'Funk'),
      NgGenre(id: '52', label: 'Fusion'),
      NgGenre(id: '14', label: 'Goth'),
      NgGenre(id: '39', label: 'Miscellaneous'),
      NgGenre(id: '29', label: 'Ska'),
      NgGenre(id: '19', label: 'World'),
    ]),
    NgGenreGroup(label: 'Southern Flavor', genres: [
      NgGenre(id: '1', label: 'Bluegrass'),
      NgGenre(id: '2', label: 'Blues'),
      NgGenre(id: '4', label: 'Country'),
    ]),
  ];
}
