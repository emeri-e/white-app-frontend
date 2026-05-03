import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SoundTileWidget extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final double volume;
  final Function(bool) onToggle;
  final Function(double) onVolumeChanged;

  const SoundTileWidget({
    super.key,
    required this.title,
    required this.icon,
    required this.isActive,
    required this.volume,
    required this.onToggle,
    required this.onVolumeChanged,
  });

  @override
  State<SoundTileWidget> createState() => _SoundTileWidgetState();
}

class _SoundTileWidgetState extends State<SoundTileWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SoundTileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.animateTo(0, duration: const Duration(milliseconds: 300));
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = Colors.purpleAccent;

    return Container(
      decoration: BoxDecoration(
        color: widget.isActive ? activeColor.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isActive ? activeColor.withOpacity(0.5) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => widget.onToggle(!widget.isActive),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isActive ? activeColor.withOpacity(0.2) : Colors.transparent,
                    ),
                    child: Icon(
                      widget.icon,
                      size: 40,
                      color: widget.isActive ? activeColor : Colors.white54,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: widget.isActive ? Colors.white : Colors.white70,
                    fontWeight: widget.isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16,
                  ),
                ),
                if (widget.isActive) ...[
                  const Spacer(),
                  SliderTheme(
                    data: SliderThemeData(
                      thumbColor: activeColor,
                      activeTrackColor: activeColor.withOpacity(0.8),
                      inactiveTrackColor: Colors.white24,
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: widget.volume,
                      min: 0,
                      max: 1.0,
                      onChanged: widget.onVolumeChanged,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
