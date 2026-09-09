import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../data/model/track.dart';
import '../data/model/ng_user.dart';
import '../data/model/ng_audio_genres.dart';
import '../data/repository/ng_repository.dart';
import '../data/repository/ng_auth.dart';
import '../player/ng_audio_handler.dart';

enum NgTab { featured, latest, popular, topRated }

class TabState {
  List<Track> tracks = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;
  int offset = 0;
  bool hasMore = false;
  bool loaded = false;
}

class NgViewModel extends ChangeNotifier {
  final NgRepository _repo = NgRepository();
  final NgAudioHandler audioHandler;

  NgViewModel(this.audioHandler) {
    audioHandler.playingStream.listen((_) => notifyListeners());
    audioHandler.processingStateStream.listen((state) {
      notifyListeners();
      if (state == NgProcessingState.completed) _onTrackCompleted();
    });
    audioHandler.positionStream.listen((_) => notifyListeners());
    audioHandler.durationStream.listen((_) => notifyListeners());

    audioHandler.onSkipToNext     = () async => playNext();
    audioHandler.onSkipToPrevious = () async => playPrev();

    _tabs[NgTab.featured]!.hasMore = true;
    _tabs[NgTab.latest]!.hasMore   = true;
    _tabs[NgTab.popular]!.hasMore  = true;
    _tabs[NgTab.topRated]!.hasMore = true;

    loadTab(NgTab.featured);
    _tryLoadUser();
  }

  // ─── Per-tab state ──────────────────────────────────────────────────────────

  final _tabs = {
    NgTab.featured: TabState(),
    NgTab.latest:   TabState(),
    NgTab.popular:  TabState(),
    NgTab.topRated: TabState(),
  };

  TabState stateOf(NgTab tab) => _tabs[tab]!;

  // ─── Player state ───────────────────────────────────────────────────────────

  Track? currentTrack;
  bool isLoadingTrack = false;
  String? playError;
  NgTab _activeTab = NgTab.featured;

  bool              get isPlaying       => audioHandler.isPlaying;
  Duration          get position        => audioHandler.position;
  Duration?         get duration        => audioHandler.duration;
  NgProcessingState get processingState => audioHandler.processingState;

  // ─── User state ─────────────────────────────────────────────────────────────

  NgUser? currentUser;
  bool isLoadingUser = false;

  // ─── Search ─────────────────────────────────────────────────────────────────

  List<Track> searchResults = [];
  bool isSearching = false;
  String? searchError;
  String _lastQuery = '';
  bool _searchHasMore = false;
  int _searchOffset = 0;

  // ─── Tab loading ─────────────────────────────────────────────────────────────

  void setActiveTab(NgTab tab) {
    _activeTab = tab;
    loadTab(tab);
  }

  void loadTab(NgTab tab) {
    final s = _tabs[tab]!;
    if (s.loaded && s.tracks.isNotEmpty) return;
    s.tracks = [];
    s.offset = 0;
    s.error = null;
    s.loaded = false;
    s.isLoading = true;
    notifyListeners();

    _fetchForTab(tab, 0, genre: genre?.id).then((tracks) {
      // Дедуп и на первой странице: NG иногда дублирует внутри ответа.
      final seen = <String>{};
      s.tracks = tracks.where((t) => seen.add(t.id)).toList();
      s.isLoading = false;
      s.loaded = true;
      notifyListeners();
    }).catchError((e) {
      s.error = 'Ошибка загрузки: $e';
      s.isLoading = false;
      notifyListeners();
    });
  }

  void reloadTab(NgTab tab) {
    _tabs[tab]!.loaded = false;
    loadTab(tab);
  }

  Future<void> loadMoreForTab(NgTab tab) async {
    final s = _tabs[tab]!;
    if (s.isLoadingMore || !s.hasMore) return;

    // Шаг 30: NG отдаёт страницы по 30 треков, другой шаг тянет
    // пересечения с уже загруженными (24 давал 6 дублей на догрузку).
    s.offset += 30;
    s.isLoadingMore = true;
    notifyListeners();

    try {
      final more = await _fetchForTab(tab, s.offset, genre: genre?.id);
      if (more.isEmpty) {
        s.hasMore = false;
      } else {
        final ids = s.tracks.map((t) => t.id).toSet();
        final fresh = more.where((t) => !ids.contains(t.id)).toList();
        // Если после дедупа ничего нового (featured пересекается на 1 шт) —
        // список кончился.
        if (fresh.isEmpty) {
          s.hasMore = false;
        } else {
          s.tracks = [...s.tracks, ...fresh];
        }
      }
    } catch (e) {
      s.error = 'Ошибка: $e';
    } finally {
      s.isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<List<Track>> _fetchForTab(NgTab tab, int offset, {String? genre}) {
    return switch (tab) {
      NgTab.featured => _repo.getFeaturedTracks(offset: offset, genre: genre),
      NgTab.latest   => _repo.getBrowseTracks(offset: offset, genre: genre),
      NgTab.popular  => _repo.getPopularTracks(offset: offset, genre: genre),
      NgTab.topRated => _repo.getTopRatedTracks(offset: offset, genre: genre),
    };
  }

  // ─── Фильтр жанра поверх активной вкладки ─────────────────────

  /// Выбранный жанр сайдбара (null — обычные табы).
  NgGenre? genre;

  /// Включить/выключить жанровый фильтр — все вкладки сбрасываются и
  /// активная перезагружается с новым параметром.
  void setGenre(NgGenre? g) {
    if (genre?.id == g?.id) return;
    genre = g;
    for (final s in _tabs.values) {
      s.tracks = [];
      s.offset = 0;
      s.error = null;
      s.loaded = false;
      s.hasMore = true;
    }
    loadTab(_activeTab);
  }

  // ─── Search ─────────────────────────────────────────────────────────────────

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    _lastQuery = q;
    _searchOffset = 0;
    _searchHasMore = true;
    searchResults = [];
    isSearching = true;
    searchError = null;
    notifyListeners();

    try {
      searchResults = await _repo.searchTracks(q, offset: 0);
      _searchHasMore = searchResults.length >= 24;
    } catch (e) {
      searchError = 'Ошибка поиска: $e';
    } finally {
      isSearching = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreSearch() async {
    if (!_searchHasMore || isSearching) return;
    _searchOffset += 24;
    isSearching = true;
    notifyListeners();
    try {
      final more = await _repo.searchTracks(_lastQuery, offset: _searchOffset);
      if (more.isEmpty) {
        _searchHasMore = false;
      } else {
        searchResults = [...searchResults, ...more];
      }
    } finally {
      isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    searchResults = [];
    _lastQuery = '';
    _searchHasMore = false;
    isSearching = false;
    searchError = null;
    notifyListeners();
  }

  bool get isInSearch => _lastQuery.isNotEmpty;

  // ─── User / Auth ─────────────────────────────────────────────────────────────

  Future<void> _tryLoadUser() async {
    if (!await NgAuth.isLoggedIn()) return;
    await fetchUser();
  }

  Future<void> fetchUser() async {
    isLoadingUser = true;
    notifyListeners();
    try {
      final username = await NgAuth.getUsername();
      if (username != null && username.isNotEmpty && username != 'unknown') {
        currentUser = await _repo.getUserProfile(username);
      } else {
        currentUser = await _repo.getCurrentUser();
      }
    } finally {
      isLoadingUser = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await NgAuth.logout();
    currentUser = null;
    notifyListeners();
  }

  /// Подписка на автора. Возвращает подтверждённое состояние или null,
  /// если NG отказал (тогда UI не должен менять кнопку).
  Future<bool?> setFollow(String artist, bool follow) =>
      _repo.setFollow(artist, follow);

  /// Текущий статус подписки (null — определить не удалось).
  Future<bool?> getFollowStatus(String artist) =>
      _repo.getFollowStatus(artist);

  // ─── Playback ────────────────────────────────────────────────────────────────

  List<Track>? _contextTracks;

  void setQueueContext(List<Track>? tracks) {
    _contextTracks = tracks;
  }

  // ─── Shuffle & Repeat ────────────────────────────────────────────────────────

  bool _shuffle = false;
  bool get shuffle => _shuffle;

  // 0 = off, 1 = repeat all, 2 = repeat one
  int _repeat = 0;
  int get repeat => _repeat;

  void toggleShuffle() {
    _shuffle = !_shuffle;
    notifyListeners();
  }

  void cycleRepeat() {
    _repeat = (_repeat + 1) % 3;
    notifyListeners();
  }

  List<Track> get _allTracks {
    if (_contextTracks != null) return _contextTracks!;
    if (isInSearch) return searchResults;
    return _tabs[_activeTab]!.tracks;
  }

  int _playGen = 0;

  Future<void> playTrack(Track track) async {
    final gen = ++_playGen;
    currentTrack = track;
    isLoadingTrack = true;
    playError = null;
    _lastCompletedId = null;
    notifyListeners();

    try { await audioHandler.stop(); } catch (_) {}
    if (gen != _playGen) return;

    try {
      if (track.mp3Url == null || track.mp3Url!.isEmpty) {
        await _repo.enrichTrack(track);
      }
      if (gen != _playGen) return;

      final url = track.mp3Url;
      if (url == null || url.isEmpty) {
        playError = 'Не удалось найти ссылку на трек';
      } else {
        await audioHandler.playUrl(
          url,
          title: track.title,
          artist: track.artist,
          artworkUri: Uri.tryParse(track.aIconUrl),
        );
        if (gen != _playGen) {
          try { await audioHandler.stop(); } catch (_) {}
          return;
        }
      }
    } catch (e) {
      if (gen == _playGen) playError = 'Ошибка воспроизведения: $e';
    } finally {
      if (gen == _playGen) {
        isLoadingTrack = false;
        notifyListeners();
      }
    }
  }

  void togglePlayPause() {
    if (audioHandler.isPlaying) {
      audioHandler.pause();
    } else {
      audioHandler.play();
    }
    notifyListeners();
  }

  void seekTo(Duration position) => audioHandler.seek(position);

  String? _lastCompletedId;

  void _onTrackCompleted() {
    if (currentTrack == null || _lastCompletedId == currentTrack!.id) return;
    _lastCompletedId = currentTrack!.id;
    // repeat one — restart current
    if (_repeat == 2) { playTrack(currentTrack!); return; }
    if (_shuffle) { _playRandom(); return; }
    final list = _allTracks;
    final idx = list.indexWhere((t) => t.id == currentTrack!.id);
    if (idx != -1 && idx + 1 < list.length) {
      playTrack(list[idx + 1]);
    } else if (_repeat == 1 && list.isNotEmpty) {
      // repeat all — wrap to start
      playTrack(list.first);
    }
  }

  void _playRandom() {
    final list = _allTracks;
    if (list.length <= 1) return;
    final rng = math.Random();
    Track next;
    do { next = list[rng.nextInt(list.length)]; }
    while (next.id == currentTrack?.id && list.length > 1);
    playTrack(next);
  }

  void playNext() {
    if (_shuffle) { _playRandom(); return; }
    final list = _allTracks;
    final idx = list.indexWhere((t) => t.id == currentTrack?.id);
    if (idx != -1 && idx + 1 < list.length) {
      playTrack(list[idx + 1]);
    } else if (_repeat == 1 && list.isNotEmpty) {
      playTrack(list.first);
    }
  }

  void playPrev() {
    final list = _allTracks;
    final idx = list.indexWhere((t) => t.id == currentTrack?.id);
    if (idx > 0) playTrack(list[idx - 1]);
  }

  bool hasPrev() {
    final idx = _allTracks.indexWhere((t) => t.id == currentTrack?.id);
    return idx > 0;
  }

  bool hasNext() {
    if (_shuffle || _repeat == 1) return _allTracks.length > 1;
    if (_repeat == 2) return true;
    final list = _allTracks;
    final idx = list.indexWhere((t) => t.id == currentTrack?.id);
    return idx != -1 && idx + 1 < list.length;
  }

  @override
  void dispose() {
    audioHandler.dispose();
    super.dispose();
  }
}
