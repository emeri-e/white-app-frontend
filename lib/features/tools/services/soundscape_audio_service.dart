import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:whiteapp/features/tools/models/soundscape_track.dart';

class SoundscapeAudioService {
  static final SoundscapeAudioService _instance = SoundscapeAudioService._internal();
  factory SoundscapeAudioService() => _instance;
  SoundscapeAudioService._internal();

  final Map<int, AudioPlayer> _players = {};
  final Map<int, double> _volumes = {};
  
  int maxSimultaneousTracks = 3;
  double _masterVolume = 1.0;

  double get masterVolume => _masterVolume;
  
  void setMaxSimultaneousTracks(int max) {
    maxSimultaneousTracks = max;
  }

  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 1.0);
    _players.forEach((id, player) {
      final baseVol = _volumes[id] ?? 0.5;
      player.setVolume(baseVol * _masterVolume);
    });
  }

  bool isTrackActive(int trackId) {
    return _players.containsKey(trackId);
  }

  double getTrackVolume(int trackId) {
    return _volumes[trackId] ?? 0.5;
  }

  Future<bool> toggleTrack(SoundscapeTrack track) async {
    if (isTrackActive(track.id)) {
      await stopTrack(track.id);
      return false;
    } else {
      if (_players.length >= maxSimultaneousTracks) {
        throw Exception('Maximum of $maxSimultaneousTracks tracks allowed');
      }
      await startTrack(track);
      return true;
    }
  }

  Future<void> startTrack(SoundscapeTrack track) async {
    if (isTrackActive(track.id)) return;

    final player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.loop);
    
    _players[track.id] = player;
    _volumes[track.id] = 0.5; // Default volume
    
    // Crossfade in
    player.setVolume(0);
    await player.play(UrlSource(track.audioFile));
    
    // Simple fade in
    for (int i = 1; i <= 10; i++) {
      if (!_players.containsKey(track.id)) return;
      await Future.delayed(const Duration(milliseconds: 50));
      await player.setVolume((0.5 * _masterVolume) * (i / 10));
    }
  }

  Future<void> stopTrack(int trackId) async {
    final player = _players[trackId];
    if (player == null) return;
    
    _players.remove(trackId);
    
    // Fade out
    final baseVol = _volumes[trackId] ?? 0.5;
    for (int i = 9; i >= 0; i--) {
      await Future.delayed(const Duration(milliseconds: 50));
      try {
        await player.setVolume((baseVol * _masterVolume) * (i / 10));
      } catch (_) {}
    }
    
    await player.stop();
    await player.dispose();
    _volumes.remove(trackId);
  }

  Future<void> setTrackVolume(int trackId, double volume) async {
    _volumes[trackId] = volume.clamp(0.0, 1.0);
    final player = _players[trackId];
    if (player != null) {
      await player.setVolume(_volumes[trackId]! * _masterVolume);
    }
  }

  Future<void> stopAll() async {
    final activeIds = _players.keys.toList();
    for (final id in activeIds) {
      await stopTrack(id);
    }
  }

  int getActiveCount() => _players.length;
  List<int> getActiveTrackIds() => _players.keys.toList();
}
