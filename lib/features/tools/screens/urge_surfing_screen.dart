import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:whiteapp/features/tools/models/urge_surfing_config.dart';
import 'package:whiteapp/features/tools/services/tools_service.dart';
import 'package:whiteapp/features/tools/widgets/wave_animation_widget.dart';

class UrgeSurfingScreen extends StatefulWidget {
  static const String id = 'urge_surfing_screen';

  const UrgeSurfingScreen({super.key});

  @override
  State<UrgeSurfingScreen> createState() => _UrgeSurfingScreenState();
}

class _UrgeSurfingScreenState extends State<UrgeSurfingScreen> {
  bool _isLoading = true;
  List<UrgeSurfingConfig> _configs = [];
  UrgeSurfingConfig? _selectedConfig;

  Timer? _timer;
  bool _isActive = false;
  bool _isPaused = false;
  bool _isCompleted = false;
  int _secondsRemaining = 0;
  int _totalSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadConfigs() async {
    try {
      final configs = await ToolsService.getUrgeSurfingConfigs();
      setState(() {
        _configs = configs;
        if (_configs.isNotEmpty) {
          _selectedConfig = _configs.first;
          _secondsRemaining = _selectedConfig!.durationSeconds;
          _totalSeconds = _selectedConfig!.durationSeconds;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load configs: $e')),
        );
      }
    }
  }

  void _startTimer() {
    if (_selectedConfig == null) return;
    
    setState(() {
      _isActive = true;
      _isPaused = false;
      _isCompleted = false;
      
      // If we are starting fresh (not unpausing)
      if (_secondsRemaining == 0 || _secondsRemaining == _selectedConfig!.durationSeconds) {
        _secondsRemaining = _selectedConfig!.durationSeconds;
        _totalSeconds = _selectedConfig!.durationSeconds;
      }
    });

    HapticFeedback.mediumImpact();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;

          // Gentle haptic pulse every minute
          if (_secondsRemaining % 60 == 0 && _secondsRemaining > 0) {
            HapticFeedback.heavyImpact();
          }
        } else {
          _completeSession();
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isPaused = true;
    });
    HapticFeedback.lightImpact();
  }

  void _stopTimer({bool completed = false}) {
    _timer?.cancel();
    setState(() {
      _isActive = false;
      _isPaused = false;
      _isCompleted = completed;
      if (!completed && _selectedConfig != null) {
        _secondsRemaining = _selectedConfig!.durationSeconds;
      }
    });
  }

  Future<void> _completeSession() async {
    _stopTimer(completed: true);
    HapticFeedback.heavyImpact();

    try {
      await ToolsService.logToolUsage(
        toolType: 'urge_surfing',
        toolConfigId: _selectedConfig!.id,
        durationSeconds: _totalSeconds,
        completed: true,
      );
    } catch (e) {
      debugPrint("Error logging urge surfing usage: $e");
    }
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double _calculateIntensity() {
    if (!_isActive || _isPaused || _totalSeconds == 0) return 0.0;
    // Intensity is highest at the start, goes to 0 near the end.
    return _secondsRemaining / _totalSeconds;
  }

  @override
  Widget build(BuildContext context) {
    final intensity = _calculateIntensity();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Urge Surfing',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Waves
          Positioned.fill(
            child: WaveAnimationWidget(
              intensity: intensity,
              baseColor: Colors.tealAccent,
            ),
          ),
          
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildConfigSelector(),
                      
                      Expanded(
                        child: Center(
                          child: _isCompleted ? _buildCompletionState() : _buildTimerState(),
                        ),
                      ),
                      
                      _buildControls(),
                      const SizedBox(height: 40),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigSelector() {
    if (_isActive || _isCompleted) return const SizedBox.shrink();
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _configs.map((config) {
          final isSelected = _selectedConfig?.id == config.id;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(
                config.label,
                style: GoogleFonts.outfit(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: Colors.tealAccent.withOpacity(0.3),
              backgroundColor: Colors.white.withOpacity(0.1),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedConfig = config;
                    _secondsRemaining = config.durationSeconds;
                    _totalSeconds = config.durationSeconds;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimerState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Ride the wave.",
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w300,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _formatTime(_secondsRemaining),
            key: ValueKey<int>(_secondsRemaining),
            style: GoogleFonts.outfit(
              fontSize: 80,
              fontWeight: FontWeight.w200,
              color: Colors.white,
              letterSpacing: 8,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (_isPaused)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              "Paused",
              style: GoogleFonts.outfit(
                fontSize: 18,
                color: Colors.white54,
                letterSpacing: 2,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompletionState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.waves, color: Colors.tealAccent, size: 80),
        const SizedBox(height: 24),
        Text(
          "You rode the wave.",
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            _selectedConfig?.encouragementMessage ?? "The urge has passed.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 18,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    if (_isCompleted) {
      return ElevatedButton(
        onPressed: () {
          setState(() {
            _isCompleted = false;
            _isActive = false;
            if (_selectedConfig != null) {
              _secondsRemaining = _selectedConfig!.durationSeconds;
            }
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.2),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Text('Done', style: GoogleFonts.outfit(fontSize: 18)),
      );
    }

    if (!_isActive) {
      return ElevatedButton(
        onPressed: _selectedConfig != null ? _startTimer : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.tealAccent,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Text('Start Surfing', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.stop_circle_outlined, size: 50, color: Colors.white54),
          onPressed: () => _stopTimer(completed: false),
        ),
        const SizedBox(width: 32),
        if (_isPaused)
          IconButton(
            icon: const Icon(Icons.play_circle_fill, size: 64, color: Colors.tealAccent),
            onPressed: _startTimer,
          )
        else
          IconButton(
            icon: const Icon(Icons.pause_circle_filled, size: 64, color: Colors.tealAccent),
            onPressed: _pauseTimer,
          ),
      ],
    );
  }
}
