import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();
  static AudioService get I => instance;

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  bool _isMuted = false;
  String? _currentBgm;
  String? _pendingBgm;
  bool _audioUnlocked = false;

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      _bgmPlayer.pause();
    } else {
      if (_currentBgm != null) {
        _bgmPlayer.resume();
      }
    }
  }

  /// Play background music.
  Future<void> playBGM(String assetPath) async {
    if (_isMuted) return;

    final normalizedPath = assetPath.replaceFirst('assets/', '');

    await _doPlayBGM(normalizedPath);
  }

  Future<void> _doPlayBGM(String normalizedPath) async {
    await _bgmPlayer.stop();
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    _currentBgm = normalizedPath;

    try {
      await _bgmPlayer.play(AssetSource(normalizedPath));
    } catch (e) {
      debugPrint('[AudioService] Failed to play BGM "$normalizedPath": $e');
    }
  }

  Future<void> stopBGM() async {
    await _bgmPlayer.stop();
    _currentBgm = null;
  }

  Future<void> pauseBGM() async {
    await _bgmPlayer.pause();
  }

  Future<void> resumeBGM() async {
    if (_isMuted || _currentBgm == null) return;
    await _bgmPlayer.resume();
  }

  /// Play sound effect.
  Future<void> playSFX(String assetPath) async {
    if (_isMuted) return;

    final normalizedPath = assetPath.replaceFirst('assets/', '');
    try {
      await _sfxPlayer.play(AssetSource(normalizedPath));
    } catch (e) {
      debugPrint('[AudioService] Failed to play SFX "$normalizedPath": $e');
    }
  }

  /// Called on first user tap - unlocks web audio context.
  /// Also plays pending BGM if any.
  void onFirstTap() {
    if (!_audioUnlocked) {
      _audioUnlocked = true;
      if (_pendingBgm != null) {
        _doPlayBGM(_pendingBgm!);
        _pendingBgm = null;
      }
    }
  }

  String? get currentBgm => _currentBgm;
  bool get isMuted => _isMuted;

  void dispose() {
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
  }
}
