class Playlist {
  final int? id;
  final String name;
  final String? description;
  final int createdAt;
  // null = local only; non-null = mirrored NG playlist id
  final String? ngId;

  const Playlist({
    this.id,
    required this.name,
    this.description,
    required this.createdAt,
    this.ngId,
  });

  Playlist copyWith({int? id, String? name, String? description, String? ngId}) =>
      Playlist(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        createdAt: createdAt,
        ngId: ngId ?? this.ngId,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
        'created_at': createdAt,
        'ng_id': ngId,
      };

  factory Playlist.fromMap(Map<String, dynamic> m) => Playlist(
        id: m['id'] as int?,
        name: m['name'] as String,
        description: m['description'] as String?,
        createdAt: m['created_at'] as int,
        ngId: m['ng_id'] as String?,
      );
}

class PlaylistTrack {
  final int? id;
  final int playlistId;
  final String trackId;
  final String title;
  final String artist;
  final String iconUrl;
  final int duration;
  final String? genre;
  final String? mp3Url;
  final int position;
  final int addedAt;

  const PlaylistTrack({
    this.id,
    required this.playlistId,
    required this.trackId,
    required this.title,
    required this.artist,
    required this.iconUrl,
    required this.duration,
    this.genre,
    this.mp3Url,
    required this.position,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'playlist_id': playlistId,
        'track_id': trackId,
        'title': title,
        'artist': artist,
        'icon_url': iconUrl,
        'duration': duration,
        'genre': genre,
        'mp3_url': mp3Url,
        'position': position,
        'added_at': addedAt,
      };

  factory PlaylistTrack.fromMap(Map<String, dynamic> m) => PlaylistTrack(
        id: m['id'] as int?,
        playlistId: m['playlist_id'] as int,
        trackId: m['track_id'] as String,
        title: m['title'] as String,
        artist: m['artist'] as String,
        iconUrl: m['icon_url'] as String,
        duration: m['duration'] as int? ?? 0,
        genre: m['genre'] as String?,
        mp3Url: m['mp3_url'] as String?,
        position: m['position'] as int? ?? 0,
        addedAt: m['added_at'] as int,
      );
}

class Favorite {
  final int? id;
  final String trackId;
  final String title;
  final String artist;
  final String iconUrl;
  final int duration;
  final String? genre;
  final int addedAt;

  /// Сердечко ушло в избранное аккаунта Newgrounds (а не только в базу
  /// приложения). Пишется в момент добавления — по настройке «Save favorites
  /// to», потому что прочитать список избранного с NG нельзя.
  final bool isNg;

  const Favorite({
    this.id,
    required this.trackId,
    required this.title,
    required this.artist,
    required this.iconUrl,
    required this.duration,
    this.genre,
    required this.addedAt,
    this.isNg = false,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'track_id': trackId,
        'title': title,
        'artist': artist,
        'icon_url': iconUrl,
        'duration': duration,
        'genre': genre,
        'added_at': addedAt,
        'is_ng': isNg ? 1 : 0,
      };

  factory Favorite.fromMap(Map<String, dynamic> m) => Favorite(
        id: m['id'] as int?,
        trackId: m['track_id'] as String,
        title: m['title'] as String,
        artist: m['artist'] as String,
        iconUrl: m['icon_url'] as String,
        duration: m['duration'] as int? ?? 0,
        genre: m['genre'] as String?,
        addedAt: m['added_at'] as int,
        isNg: (m['is_ng'] as int? ?? 0) == 1,
      );
}

// NG cloud playlist. `url`/`entries`/`iconUrl` заполняются, когда список
// собран со страницы `/playlists` через `/visual-links-fetch`;
// у варианта из выпадашки `addentry` есть только id и имя.
class NgCloudPlaylist {
  final String id;
  final String name;
  final String? url;
  final int? entries;
  final String? iconUrl;

  const NgCloudPlaylist({
    required this.id,
    required this.name,
    this.url,
    this.entries,
    this.iconUrl,
  });
}

/// Кнопка `favefollow` со страницы NG: секрет кнопки, одноразовый
/// `userkey` и текущее состояние (`null` — определить не удалось).
class NgFaveButton {
  final String key;
  final String userkey;
  final bool? active;

  const NgFaveButton({
    required this.key,
    required this.userkey,
    this.active,
  });
}
