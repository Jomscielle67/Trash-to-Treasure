import 'dart:math';
import 'package:audioplayers/audioplayers.dart';

/// Singleton background-music service.
/// Plays all 6 tracks in random order (shuffle), never repeating the same track twice in a row.
class BgmService {
  BgmService._();

  static final BgmService instance = BgmService._();

  final AudioPlayer _player = AudioPlayer();
  int _currentIndex = 0;
  bool _initialized = false;
  final _random = Random();
  final List<String> _queue = [];

  static const List<String> _tracks = [
    'backgroud_music/bgm1.mp3',
    'backgroud_music/bgm2.mp3',
    'backgroud_music/bgm3.mp3',
    'backgroud_music/bgm4.mp3',
    'backgroud_music/bgm5.mp3',
    'backgroud_music/bgm6.mp3',
  ];

  Future<void> start() async {
    if (_initialized) return;
    _initialized = true;

    await _player.setVolume(0.4);
    _buildQueue(-1); // build initial shuffled queue
    _currentIndex = int.parse(_queue.removeAt(0)); // pick first random track

    // When a track finishes, pick the next random track
    _player.onPlayerComplete.listen((_) async {
      if (_queue.isEmpty) _buildQueue(_currentIndex);
      _currentIndex = int.parse(_queue.removeAt(0));
      await _playCurrentTrack();
    });

    await _playCurrentTrack();
  }

  /// Builds a shuffled queue of track indices, excluding [lastIndex] as first item
  /// to avoid playing the same track twice in a row.
  void _buildQueue(int lastIndex) {
    final indices = List<int>.generate(_tracks.length, (i) => i);
    indices.shuffle(_random);
    // ensure we don't start with the same track that just played
    if (lastIndex != -1 && indices.first == lastIndex && indices.length > 1) {
      final swap = 1 + _random.nextInt(indices.length - 1);
      final tmp = indices[0];
      indices[0] = indices[swap];
      indices[swap] = tmp;
    }
    _queue.addAll(indices.map((i) => i.toString()));
  }

  Future<void> _playCurrentTrack() async {
    await _player.play(AssetSource(_tracks[_currentIndex]));
  }

  Future<void> pause() => _player.pause();

  Future<void> resume() => _player.resume();

  Future<void> stop() => _player.stop();

  void setVolume(double volume) => _player.setVolume(volume);

  bool get isPlaying => _player.state == PlayerState.playing;
}
