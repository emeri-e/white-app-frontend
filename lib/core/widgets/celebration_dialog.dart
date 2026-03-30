import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class CelebrationDialog extends StatefulWidget {
  final String title;
  final String message;
  final Widget? extraContent;
  final IconData icon;
  final VoidCallback onContinue;
  final String buttonText;

  const CelebrationDialog({
    super.key,
    required this.title,
    required this.message,
    this.extraContent,
    this.icon = Icons.emoji_events,
    required this.onContinue,
    this.buttonText = "Continue",
  });

  @override
  State<CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<CelebrationDialog> with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _confettiController.play();

    _animController = AnimationController(
       vsync: this, 
       duration: const Duration(milliseconds: 800)
    );
    _scaleAnimation = CurvedAnimation(
       parent: _animController, 
       curve: Curves.elasticOut
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
             padding: const EdgeInsets.only(top: 60, left: 16, right: 16, bottom: 16),
             margin: const EdgeInsets.only(top: 40),
             decoration: BoxDecoration(
               color: const Color(0xFF1E293B),
               shape: BoxShape.rectangle,
               borderRadius: BorderRadius.circular(16),
               boxShadow: const [
                 BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 10))
               ]
             ),
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                 const SizedBox(height: 12),
                 Text(widget.message, style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
                 if (widget.extraContent != null) ...[
                   const SizedBox(height: 16),
                   widget.extraContent!,
                 ],
                 const SizedBox(height: 24),
                 ElevatedButton(
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.amber,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     minimumSize: const Size.fromHeight(50)
                   ),
                   onPressed: widget.onContinue,
                   child: Text(widget.buttonText, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                 )
               ]
             )
          ),
          Positioned(
            top: -10,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: CircleAvatar(
                backgroundColor: const Color(0xFF1E293B),
                radius: 50,
                child: Icon(widget.icon, color: Colors.amber, size: 64),
              )
            )
          ),
          Positioned(
            top: 20,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            )
          )
        ],
      )
    );
  }
}
