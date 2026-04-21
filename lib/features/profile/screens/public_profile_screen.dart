import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/features/profile/services/profile_service.dart';
import 'dart:ui';

class PublicProfileScreen extends StatefulWidget {
  final int userId;
  const PublicProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPublicProfile();
  }

  Future<void> _fetchPublicProfile() async {
    try {
      final data = await ProfileService.getPublicProfile(widget.userId);
      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text(
          _profileData?['username'] ?? 'Profile',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text('Error: $_error', style: GoogleFonts.outfit(color: Colors.white70)),
            TextButton(onPressed: _fetchPublicProfile, child: const Text('Retry')),
          ],
        ),
      );
    }

    final p = _profileData!;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 80, 20, 40),
      children: [
        _buildHeader(p),
        const SizedBox(height: 32),
        _buildStats(p),
        const SizedBox(height: 32),
        if (p['bio']?.isNotEmpty == true) ...[
          _buildBio(p['bio']),
          const SizedBox(height: 32),
        ],
        _buildBadges(p['badges'] ?? []),
        const SizedBox(height: 32),
        _buildAchievements(p),
      ],
    );
  }

  Widget _buildHeader(Map<String, dynamic> p) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white10,
            backgroundImage: p['avatar'] != null ? NetworkImage(p['avatar']) : null,
            child: p['avatar'] == null ? const Icon(Icons.person, size: 50, color: Colors.white24) : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          p['username'],
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        if (p['location']?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: Colors.white38),
                const SizedBox(width: 4),
                Text(p['location'], style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStats(Map<String, dynamic> p) {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem('Clean Days', p['clean_days'].toString(), Icons.timer_rounded),
            _buildDivider(),
            _buildStatItem('Streak Rec', p['streak_record'].toString(), Icons.workspace_premium_rounded),
            _buildDivider(),
            _buildStatItem('Gender', _formatGender(p['gender']), Icons.person_outline_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.blueAccent.withOpacity(0.7)),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: GoogleFonts.outfit(fontSize: 11, color: Colors.white38)),
      ],
    );
  }

  Widget _buildBio(String bio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('ABOUT ME'),
        _buildGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(bio, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 15, height: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildBadges(List<dynamic> badges) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('BADGES EARNED'),
        if (badges.isEmpty)
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(child: Text('No badges yet', style: GoogleFonts.outfit(color: Colors.white24))),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: badges.length,
            itemBuilder: (context, index) {
              final b = badges[index];
              return _buildBadgeCard(b);
            },
          ),
      ],
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> b) {
    final badge = b['badge'];
    final level = b['current_level'];
    return _buildGlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (level['image'] != null)
            Image.network(level['image'], width: 40, height: 40)
          else
            const Icon(Icons.stars_rounded, size: 40, color: Colors.amberAccent),
          const SizedBox(height: 8),
          Text(badge['title'], style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
          Text('LVL ${level['level_number']}', style: GoogleFonts.outfit(fontSize: 10, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildAchievements(Map<String, dynamic> p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('CURRENT STATUS'),
        _buildGlassCard(
          child: ListTile(
            leading: _buildLevelMedal(p['level_order']),
            title: Text(p['level_title'] ?? 'Newcomer', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('Level ${p['level_order']} Contributor', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.orangeAccent),
                  const SizedBox(width: 4),
                  Text(p['trophies'].toString(), style: GoogleFonts.outfit(color: Colors.white)),
                ]),
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.stars_rounded, size: 14, color: Colors.blueAccent),
                  const SizedBox(width: 4),
                  Text(p['gems'].toString(), style: GoogleFonts.outfit(color: Colors.white)),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelMedal(int level) {
    Color color = Colors.brown;
    if (level > 2) color = Colors.blueGrey;
    if (level > 5) color = Colors.amber;
    if (level > 10) color = Colors.tealAccent;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Center(
        child: Text(level.toString(), style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent.withOpacity(0.8), letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildDivider() => Container(width: 1, height: 30, color: Colors.white.withOpacity(0.05));

  String _formatGender(String? g) {
    if (g == null || g.isEmpty) return 'N/A';
    return g[0].toUpperCase() + g.substring(1).replaceAll('_', ' ');
  }
}
