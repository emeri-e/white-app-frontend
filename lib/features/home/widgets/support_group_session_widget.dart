import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportGroupSessionWidget extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback? onJoin;

  const SupportGroupSessionWidget({
    Key? key,
    required this.session,
    this.onJoin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final startTime = DateTime.parse(session['start_datetime']);
    final endTime = DateTime.parse(session['end_datetime']);
    final now = DateTime.now();
    
    bool isLive = now.isAfter(startTime) && now.isBefore(endTime);
    bool isUpcoming = now.isBefore(startTime);
    bool justEnded = now.isAfter(endTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLive 
            ? [Colors.blueAccent.withOpacity(0.2), Colors.blueAccent.withOpacity(0.05)]
            : [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isLive ? Colors.blueAccent.withOpacity(0.3) : Colors.white10,
          width: 1.5,
        ),
        boxShadow: [
          if (isLive)
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: -5,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isLive ? Colors.blueAccent : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLive) ...[
                      const Icon(Icons.emergency_recording_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      isLive ? "LIVE NOW" : (justEnded ? "ENDED" : "TODAY"),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                "${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}",
                style: GoogleFonts.outfit(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            session['title'] ?? session['group_title'] ?? "Support Session",
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            session['group_title'] ?? "Support Group",
            style: GoogleFonts.outfit(
              color: Colors.white38,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () => _handleJoin(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLive ? Colors.blueAccent : Colors.white.withOpacity(0.1),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                isLive ? "Join Session" : "View Details",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleJoin(BuildContext context) async {
    final link = session['meeting_link'];
    if (link != null && link.isNotEmpty) {
      final url = Uri.parse(link);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch meeting link")),
        );
      }
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No meeting link available")),
      );
    }
  }
}
