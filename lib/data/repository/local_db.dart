import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../model/playlist.dart';
import '../model/track.dart';

class LocalDb {
  static LocalDb? _instance;
  static LocalDb get instance => _instance ??= LocalDb._();
  LocalDb._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'ngmusic.db');
    return openDatabase(
      path,
      version: 3,
      onUpgrade: (db, from, to) async {
        // v2: уникальность зеркал NG. До неё две параллельные синхронизации
        // (из LibraryViewModel._init и из _RootShell.build) вставляли один и
        // тот же плейлист дважды — в библиотеке было 162 записи вместо 81.
        if (from < 2) {
          await db.execute('''
            DELETE FROM playlists
            WHERE ng_id IS NOT NULL AND id NOT IN (
              SELECT MIN(id) FROM playlists WHERE ng_id IS NOT NULL GROUP BY ng_id
            )
          ''');
          // FK-каскад в sqflite по умолчанию выключен — чистим осиротевшие треки.
          await db.execute('''
            DELETE FROM playlist_tracks
            WHERE playlist_id NOT IN (SELECT id FROM playlists)
          ''');
          await db.execute(_ngIdIndex);
        }
        // v3: откуда сердечко — из приложения или с аккаунта NG. Вкладка
        // Favorites делит список на две секции, а прочитать избранное с NG
        // нельзя, поэтому источник фиксируем в момент добавления.
        if (from < 3) {
          await db.execute(
              'ALTER TABLE favorites ADD COLUMN is_ng INTEGER NOT NULL DEFAULT 0');
        }
      },
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE playlists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            created_at INTEGER NOT NULL,
            ng_id TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE playlist_tracks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            playlist_id INTEGER NOT NULL,
            track_id TEXT NOT NULL,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            icon_url TEXT NOT NULL,
            duration INTEGER DEFAULT 0,
            genre TEXT,
            mp3_url TEXT,
            position INTEGER DEFAULT 0,
            added_at INTEGER NOT NULL,
            FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
            UNIQUE (playlist_id, track_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE favorites (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            track_id TEXT NOT NULL UNIQUE,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            icon_url TEXT NOT NULL,
            duration INTEGER DEFAULT 0,
            genre TEXT,
            added_at INTEGER NOT NULL,
            is_ng INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(_ngIdIndex);
      },
    );
  }

  /// Один локальный плейлист на один плейлист NG. NULL (чисто локальные)
  /// SQLite в UNIQUE-индексе дубликатами не считает, так что их сколько угодно.
  static const _ngIdIndex =
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_playlists_ng_id '
      'ON playlists(ng_id)';

  // ─── Playlists ────────────────────────────────────────────────────────────────

  Future<List<Playlist>> getPlaylists() async {
    final d = await db;
    final rows = await d.query('playlists', orderBy: 'created_at DESC');
    return rows.map(Playlist.fromMap).toList();
  }

  Future<Playlist> createPlaylist(String name, {String? description}) async {
    final d = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final p = Playlist(name: name, description: description, createdAt: now);
    final id = await d.insert('playlists', p.toMap());
    return p.copyWith(id: id);
  }

  /// Создаёт зеркало плейлиста NG. Если зеркало уже есть — возвращает его,
  /// а не вторую копию: UNIQUE-индекс по `ng_id` вставить дубликат не даст,
  /// но `insert` с `ignore` вернул бы id = 0.
  Future<Playlist> createPlaylistWithNgId(String name, {required String ngId}) async {
    final d = await db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final p = Playlist(name: name, createdAt: now, ngId: ngId);
    final id = await d.insert('playlists', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
    if (id != 0) return p.copyWith(id: id);
    final rows = await d.query('playlists',
        where: 'ng_id = ?', whereArgs: [ngId], limit: 1);
    if (rows.isEmpty) return p;
    return Playlist.fromMap(rows.first);
  }

  Future<void> renamePlaylist(int id, String name) async {
    final d = await db;
    await d.update('playlists', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePlaylist(int id) async {
    final d = await db;
    await d.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Playlist tracks ──────────────────────────────────────────────────────────

  Future<List<PlaylistTrack>> getPlaylistTracks(int playlistId) async {
    final d = await db;
    final rows = await d.query(
      'playlist_tracks',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'position ASC, added_at ASC',
    );
    return rows.map(PlaylistTrack.fromMap).toList();
  }

  Future<int> trackCountForPlaylist(int playlistId) async {
    final d = await db;
    final r = await d.rawQuery(
        'SELECT COUNT(*) as c FROM playlist_tracks WHERE playlist_id = ?',
        [playlistId]);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<bool> isTrackInPlaylist(int playlistId, String trackId) async {
    final d = await db;
    final r = await d.query(
      'playlist_tracks',
      where: 'playlist_id = ? AND track_id = ?',
      whereArgs: [playlistId, trackId],
      limit: 1,
    );
    return r.isNotEmpty;
  }

  Future<void> addTrackToPlaylist(int playlistId, Track track) async {
    final d = await db;
    final count = await trackCountForPlaylist(playlistId);
    final pt = PlaylistTrack(
      playlistId: playlistId,
      trackId: track.id,
      title: track.title,
      artist: track.artist,
      iconUrl: track.iconUrl,
      duration: track.duration,
      genre: track.genre.isEmpty ? null : track.genre,
      mp3Url: track.mp3Url,
      position: count,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await d.insert('playlist_tracks', pt.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeTrackFromPlaylist(int playlistId, String trackId) async {
    final d = await db;
    await d.delete(
      'playlist_tracks',
      where: 'playlist_id = ? AND track_id = ?',
      whereArgs: [playlistId, trackId],
    );
  }

  // ─── Favorites ────────────────────────────────────────────────────────────────

  Future<List<Favorite>> getFavorites() async {
    final d = await db;
    final rows = await d.query('favorites', orderBy: 'added_at DESC');
    return rows.map(Favorite.fromMap).toList();
  }

  Future<bool> isFavorite(String trackId) async {
    final d = await db;
    final r = await d.query(
      'favorites',
      where: 'track_id = ?',
      whereArgs: [trackId],
      limit: 1,
    );
    return r.isNotEmpty;
  }

  Future<void> addFavorite(Track track, {bool isNg = false}) async {
    final d = await db;
    final fav = Favorite(
      trackId: track.id,
      title: track.title,
      artist: track.artist,
      iconUrl: track.iconUrl,
      duration: track.duration,
      genre: track.genre.isEmpty ? null : track.genre,
      addedAt: DateTime.now().millisecondsSinceEpoch,
      isNg: isNg,
    );
    await d.insert('favorites', fav.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFavorite(String trackId) async {
    final d = await db;
    await d.delete('favorites', where: 'track_id = ?', whereArgs: [trackId]);
  }

  /// Помечает, лежит ли сердечко на NG. Нужно для сверки с сайтом:
  /// записи, сделанные до появления колонки `is_ng`, источника не помнят.
  Future<void> setFavoriteIsNg(String trackId, bool isNg) async {
    final d = await db;
    await d.update('favorites', {'is_ng': isNg ? 1 : 0},
        where: 'track_id = ?', whereArgs: [trackId]);
  }

  /// [isNg] — сердечко ушло и на Newgrounds; влияет только на новую запись.
  Future<void> toggleFavorite(Track track, {bool isNg = false}) async {
    if (await isFavorite(track.id)) {
      await removeFavorite(track.id);
    } else {
      await addFavorite(track, isNg: isNg);
    }
  }

  // Convert PlaylistTrack / Favorite back to Track for playback
  static Track playlistTrackToTrack(PlaylistTrack pt) => Track(
        id: pt.trackId,
        title: pt.title,
        artist: pt.artist,
        genre: pt.genre ?? '',
        iconUrl: pt.iconUrl,
        duration: pt.duration,
        audioType: 3,
        mp3Url: pt.mp3Url,
      );

  static Track favoriteToTrack(Favorite f) => Track(
        id: f.trackId,
        title: f.title,
        artist: f.artist,
        genre: f.genre ?? '',
        iconUrl: f.iconUrl,
        duration: f.duration,
        audioType: 3,
      );
}
