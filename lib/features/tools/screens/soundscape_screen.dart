import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/features/tools/models/soundscape_track.dart';
import 'package:whiteapp/features/tools/services/tools_service.dart';
import 'package:whiteapp/features/tools/services/soundscape_audio_service.dart';
import 'package:whiteapp/features/tools/widgets/sound_tile_widget.dart';

class SoundscapeScreen extends StatefulWidget {
  static const String id = 'soundscape_screen';

  const SoundscapeScreen({super.key});

  @override
  State<SoundscapeScreen> createState() => _SoundscapeScreenState();
}

class _SoundscapeScreenState extends State<SoundscapeScreen> {
  bool _isLoading = true;
  List<SoundscapeTrack> _tracks = [];
  final _audioService = SoundscapeAudioService();
  DateTime? _sessionStart;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  @override
  void dispose() {
    // Log usage and stop all tracks when exiting screen
    _logAndCleanup();
    super.dispose();
  }

  Future<void> _logAndCleanup() async {
    final activeCount = _audioService.getActiveCount();
    if (_sessionStart != null && activeCount > 0) {
      final duration = DateTime.now().difference(_sessionStart!).inSeconds;
      try {
        await ToolsService.logToolUsage(
          toolType: 'soundscape',
          durationSeconds: duration,
          completed: true,
          metadata: {
            'tracks_played': _audioService.getActiveTrackIds(),
          },
        );
      } catch (e) {
        debugPrint("Error logging soundscape usage: $e");
      }
    }
    await _audioService.stopAll();
  }

  Future<void> _loadTracks() async {
    try {
      final data = await ToolsService.getSoundscapeTracks();
      final config = data['config'];
      if (config != null) {
        _audioService.setMaxSimultaneousTracks(config['max_simultaneous_tracks'] ?? 3);
      }
      
      setState(() {
        _tracks = data['tracks'];
        _isLoading = false;
        _sessionStart = DateTime.now();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load soundscapes: $e')));
      }
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'rain': return Icons.water_drop;
      case 'ocean': return Icons.waves;
      case 'forest': return Icons.forest;
      case 'fire': return Icons.fireplace;
      case 'wind': return Icons.air;
      case 'white_noise': return Icons.noise_control_off;
      case 'birds': return Icons.pets; // Approximation
      default: return Icons.music_note;
    }
  }

  void _handleToggleTrack(SoundscapeTrack track) async {
    try {
      await _audioService.toggleTrack(track);
      setState(() {}); // Rebuild to update tile active state
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Soundscape Mixer',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
            : Column(
                children: [
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      "Mix up to ${_audioService.maxSimultaneousTracks} sounds to create your perfect calming environment.",
                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Master Volume
                  if (_audioService.getActiveCount() > 0) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_down, color: Colors.white54),
                          Expanded(
                            child: Slider(
                              value: _audioService.masterVolume,
                              min: 0,
                              max: 1.0,
                              activeColor: Colors.purpleAccent,
                              inactiveColor: Colors.white24,
                              onChanged: (val) {
                                setState(() {
                                  _audioService.setMasterVolume(val);
                                });
                              },
                            ),
                          ),
                          const Icon(Icons.volume_up, color: Colors.white54),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Grid of Sounds
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(24),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _tracks.length,
                      itemBuilder: (context, index) {
                        final track = _tracks[index];
                        final isActive = _audioService.isTrackActive(track.id);
                        final volume = _audioService.getTrackVolume(track.id);
                        
                        return SoundTileWidget(
                          title: track.name,
                          icon: _getIconData(track.iconName),
                          isActive: isActive,
                          volume: volume,
                          onToggle: (_) => _handleToggleTrack(track),
                          onVolumeChanged: (val) {
                            setState(() {
                              _audioService.setTrackVolume(track.id, val);
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
