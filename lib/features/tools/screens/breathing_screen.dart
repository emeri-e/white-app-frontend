import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:whiteapp/features/tools/models/breathing_pattern.dart';
import 'package:whiteapp/features/tools/services/tools_service.dart';
import 'package:whiteapp/features/tools/widgets/breathing_circle_widget.dart';

class BreathingScreen extends StatefulWidget {
  static const String id = 'breathing_screen';

  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  List<BreathingPattern> _patterns = [];
  BreathingPattern? _selectedPattern;

  bool _isActive = false;
  bool _isCompleted = false;
  int _currentCycle = 1;
  String _currentPhase = "Ready";
  double _circleScale = 1.0;
  Duration _animationDuration = const Duration(milliseconds: 500);
  
  Timer? _phaseTimer;
  Timer? _hapticTimer;

  // Background ambient animation
  late AnimationController _bgAnimController;
  late Animation<Color?> _bgGradientColor1;
  late Animation<Color?> _bgGradientColor2;

  @override
  void initState() {
    super.initState();
    _loadPatterns();

    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _bgGradientColor1 = ColorTween(
      begin: const Color(0xFF0F172A),
      end: const Color(0xFF1E293B),
    ).animate(_bgAnimController);

    _bgGradientColor2 = ColorTween(
      begin: const Color(0xFF1E1B4B),
      end: const Color(0xFF0F172A),
    ).animate(_bgAnimController);
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _hapticTimer?.cancel();
    _bgAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadPatterns() async {
    try {
      final patterns = await ToolsService.getBreathingPatterns();
      setState(() {
        _patterns = patterns;
        if (_patterns.isNotEmpty) {
          _selectedPattern = _patterns.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load patterns: $e')),
        );
      }
    }
  }

  void _stopSession({bool completed = false}) {
    _phaseTimer?.cancel();
    _hapticTimer?.cancel();
    setState(() {
      _isActive = false;
      _isCompleted = completed;
      if (!completed) {
        _currentPhase = "Ready";
        _circleScale = 1.0;
        _currentCycle = 1;
        _animationDuration = const Duration(milliseconds: 500);
      }
    });
  }

  void _startSession() {
    if (_selectedPattern == null) return;
    setState(() {
      _isActive = true;
      _isCompleted = false;
      _currentCycle = 1;
    });
    _runPhase(0); // 0: Inhale, 1: Hold, 2: Exhale, 3: Hold
  }

  void _runPhase(int phaseIndex) {
    if (!mounted || !_isActive) return;

    final pattern = _selectedPattern!;
    
    // Check if cycle is complete
    if (phaseIndex > 3) {
      if (_currentCycle >= pattern.totalCycles) {
        _completeSession();
        return;
      } else {
        setState(() {
          _currentCycle++;
        });
        phaseIndex = 0;
      }
    }

    int durationSeconds = 0;
    String phaseName = "";
    double targetScale = 1.0;

    switch (phaseIndex) {
      case 0: // Inhale
        durationSeconds = pattern.inhaleSeconds;
        phaseName = "Inhale";
        targetScale = 2.0; // expand
        break;
      case 1: // Hold
        durationSeconds = pattern.holdSeconds;
        phaseName = "Hold";
        targetScale = 2.0; // stay expanded
        break;
      case 2: // Exhale
        durationSeconds = pattern.exhaleSeconds;
        phaseName = "Exhale";
        targetScale = 1.0; // shrink
        break;
      case 3: // Post Exhale Hold
        durationSeconds = pattern.postExhaleHoldSeconds;
        phaseName = "Hold";
        targetScale = 1.0; // stay shrunk
        break;
    }

    // Skip phase if duration is 0 (e.g. 4-7-8 has no post-exhale hold)
    if (durationSeconds == 0) {
      _runPhase(phaseIndex + 1);
      return;
    }

    setState(() {
      _currentPhase = phaseName;
      _circleScale = targetScale;
      _animationDuration = Duration(seconds: durationSeconds);
    });

    if (pattern.hapticsEnabled) {
      HapticFeedback.mediumImpact();
      
      // Gentle pulsing during inhale
      _hapticTimer?.cancel();
      if (phaseIndex == 0) {
        int ticks = durationSeconds;
        _hapticTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (ticks > 1) {
            HapticFeedback.lightImpact();
            ticks--;
          } else {
            timer.cancel();
          }
        });
      }
    }

    _phaseTimer = Timer(Duration(seconds: durationSeconds), () {
      _runPhase(phaseIndex + 1);
    });
  }

  Future<void> _completeSession() async {
    _stopSession(completed: true);
    HapticFeedback.heavyImpact();
    
    setState(() {
      _currentPhase = "Complete";
      _circleScale = 1.0;
    });

    try {
      int totalDuration = _selectedPattern!.totalCycles * (
        _selectedPattern!.inhaleSeconds +
        _selectedPattern!.holdSeconds +
        _selectedPattern!.exhaleSeconds +
        _selectedPattern!.postExhaleHoldSeconds
      );
      
      await ToolsService.logToolUsage(
        toolType: 'breathing',
        toolConfigId: _selectedPattern!.id,
        durationSeconds: totalDuration,
        completed: true,
      );
    } catch (e) {
      debugPrint("Error logging tool usage: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Breathing',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBuilder(
        animation: _bgAnimController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_bgGradientColor1.value!, _bgGradientColor2.value!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  const SizedBox(height: 20),
                  _buildPatternSelector(),
                  
                  Expanded(
                    child: Center(
                      child: _isCompleted ? _buildCompletionState() : _buildBreathingState(),
                    ),
                  ),

                  _buildControls(),
                  const SizedBox(height: 40),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildPatternSelector() {
    if (_isActive || _isCompleted) return const SizedBox.shrink();
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _patterns.map((pattern) {
          final isSelected = _selectedPattern?.id == pattern.id;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(
                pattern.name,
                style: GoogleFonts.outfit(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: Colors.lightBlueAccent.withOpacity(0.3),
              backgroundColor: Colors.white.withOpacity(0.1),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedPattern = pattern;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBreathingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isActive)
          Text(
            "Cycle $_currentCycle of ${_selectedPattern?.totalCycles}",
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: Colors.white54,
              letterSpacing: 2,
            ),
          ),
        const SizedBox(height: 60),
        
        // The animated circle
        SizedBox(
          height: 350,
          child: Center(
            child: BreathingCircleWidget(
              phase: _currentPhase,
              scale: _circleScale,
              duration: _animationDuration,
              baseColor: Colors.lightBlueAccent,
            ),
          ),
        ),
        
        const SizedBox(height: 60),
        
        // Phase label
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _currentPhase,
            key: ValueKey<String>(_currentPhase),
            style: GoogleFonts.outfit(
              fontSize: 42,
              fontWeight: FontWeight.w200,
              color: Colors.white,
              letterSpacing: 4,
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
        const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 80),
        const SizedBox(height: 24),
        Text(
          "Great job.",
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Your nervous system is calming down.",
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!_isActive && !_isCompleted)
          ElevatedButton(
            onPressed: _selectedPattern != null ? _startSession : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlueAccent,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(
              'Start',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

        if (_isActive)
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined, size: 64, color: Colors.white54),
            onPressed: () => _stopSession(completed: false),
          ),

        if (_isCompleted)
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isCompleted = false;
                _currentPhase = "Ready";
                _circleScale = 1.0;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(
              'Repeat',
              style: GoogleFonts.outfit(fontSize: 16),
            ),
          ),
      ],
    );
  }
}
