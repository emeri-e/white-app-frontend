import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ToolsHubScreen extends StatelessWidget {
  static const String id = 'tools_hub_screen';

  const ToolsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Immediate Help Tools',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          physics: const BouncingScrollPhysics(),
          children: [
            Text(
              'Select a tool to help you stay grounded and manage urges.',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 30),
            _buildToolCard(
              context,
              title: 'Breathing Techniques',
              description: 'Regulate your nervous system with guided breathing patterns.',
              icon: Icons.air,
              color: Colors.lightBlueAccent,
              onTap: () {
                Navigator.pushNamed(context, 'breathing_screen');
              },
            ),
            _buildToolCard(
              context,
              title: '5-4-3-2-1 Grounding',
              description: 'A sensory exercise to pull you into the present moment.',
              icon: Icons.visibility,
              color: Colors.tealAccent,
              onTap: () {
                Navigator.pushNamed(context, 'grounding_screen');
              },
            ),
            _buildToolCard(
              context,
              title: 'Urge Surfing',
              description: 'Ride out cravings with a calming visual timer.',
              icon: Icons.waves,
              color: Colors.indigoAccent,
              onTap: () {
                Navigator.pushNamed(context, 'urge_surfing_screen');
              },
            ),
            _buildToolCard(
              context,
              title: 'Interactive Flash Cards',
              description: 'Active reflection and grounding prompts.',
              icon: Icons.style,
              color: Colors.pinkAccent,
              onTap: () {
                Navigator.pushNamed(context, 'flash_cards_screen');
              },
            ),
            _buildToolCard(
              context,
              title: 'Soundscape Mixer',
              description: 'Create a personalized relaxing audio environment.',
              icon: Icons.headphones,
              color: Colors.purpleAccent,
              onTap: () {
                Navigator.pushNamed(context, 'soundscape_screen');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
