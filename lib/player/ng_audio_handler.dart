import 'dart:async';
import 'package:flutter/services.dart';

enum NgProcessingState { idle, loading, buffering, ready, completed }

/// Bridges Flutter ↔ native Media3 PlaybackService via MethodChannel + EventChannel.
class NgAudioHandler {
  static const _method = MethodChannel('ngmusic/player');
  static const _events = EventChannel('ngmusic/player/events');

  // Cached state — updated from the native event stream
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  NgProcessingState _processingState = NgProcessingState.idle;

  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration? get duration => _duration;
  NgProcessingState get processingState => _processingState;

  // Self-reference so ViewModel can use audioHandler.player.x unchanged
  NgAudioHandler get player => this;

  // Wired by ViewModel → fires when notification next/prev is tapped
  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;

  final _playingCtrl     = StreamController<bool>.broadcast();
  final _positionCtrl    = StreamController<Duration>.broadcast();
  final _durationCtrl    = StreamController<Duration?>.broadcast();
  final _processingCtrl  = StreamController<NgProcessingState>.broadcast();

  Stream<bool>               get playingStream      => _playingCtrl.stream;
  Stream<Duration>           get positionStream     => _positionCtrl.stream;
  Stream<Duration?>          get durationStream     => _durationCtrl.stream;
  Stream<NgProcessingState>  get processingStateStream => _processingCtrl.stream;

  StreamSubscription<dynamic>? _eventSub;

  NgAudioHandler() {
    _eventSub = _events.receiveBroadcastStream().listen(_onEvent);
  }

  void _onEvent(dynamic raw) {
    if (raw is! Map) return;
    final type  = raw['type']  as String?;
    final value = raw['value'];
    switch (type) {
      case 'playing':
        _isPlaying = value as bool;
        _playingCtrl.add(_isPlaying);
      case 'position':
        _position = Duration(milliseconds: (value as num).toInt());
        _positionCtrl.add(_position);
      case 'duration':
        _duration = Duration(milliseconds: (value as num).toInt());
        _durationCtrl.add(_duration);
      case 'state':
        _processingState = _parseState(value as String);
        _processingCtrl.add(_processingState);
      case 'command':
        if (value == 'next') onSkipToNext?.call();
        if (value == 'prev') onSkipToPrevious?.call();
    }
  }

  NgProcessingState _parseState(String s) => switch (s) {
    'buffering' => NgProcessingState.buffering,
    'ready'     => NgProcessingState.ready,
    'ended'     => NgProcessingState.completed,
    _           => NgProcessingState.idle,
  };

  Future<void> playUrl(
    String url, {
    String title = '',
    String artist = '',
    Uri? artworkUri,
  }) async {
    _duration = null;
    _position = Duration.zero;
    _processingState = NgProcessingState.loading;
    _processingCtrl.add(_processingState);
    await _method.invokeMethod<void>('play', {
      'url': url,
      'title': title,
      'artist': artist,
      'artworkUri': artworkUri?.toString(),
    });
  }

  Future<void> play()  => _method.invokeMethod<void>('resume');
  Future<void> pause() => _method.invokeMethod<void>('pause');
  Future<void> stop()  => _method.invokeMethod<void>('stop');

  Future<void> seek(Duration position) =>
      _method.invokeMethod<void>('seek', {'position': position.inMilliseconds});

  Future<void> dispose() async {
    await _eventSub?.cancel();
    _playingCtrl.close();
    _positionCtrl.close();
    _durationCtrl.close();
    _processingCtrl.close();
  }
}
