import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/features/profile/models/user_profile.dart';
import 'package:whiteapp/features/profile/services/profile_service.dart';
import 'package:whiteapp/features/rewards/services/rewards_service.dart';
import 'package:whiteapp/features/recovery/services/recovery_service.dart';
import 'package:whiteapp/core/services/token_storage.dart';
import 'package:whiteapp/features/auth/screens/login_screen.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/features/profile/screens/notification_preferences_screen.dart';
import 'package:whiteapp/features/profile/screens/offline_downloads_screen.dart';
import 'package:whiteapp/features/feedback/screens/feedback_screen.dart';
import 'dart:ui';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _dailyGoalController = TextEditingController();

  late Future<List<dynamic>> _myBadgesFuture;
  List<dynamic> _availablePrograms = [];
  Map<String, dynamic>? _activeProgram;

  @override
  void initState() {
    super.initState();
    _myBadgesFuture = RewardsService.getMyBadges();
    _loadProfile();
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    try {
      final programs = await RecoveryService.getPrograms();
      final dashboard = await RecoveryService.getProgressDashboard();
      setState(() {
        _availablePrograms = programs;
        _activeProgram = dashboard['active_program'];
      });
    } catch (e) {
      debugPrint('Error loading programs: $e');
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ProfileService.getProfile();
      setState(() {
        _profile = profile;
        _isLoading = false;
        _populateControllers();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  void _populateControllers() {
    if (_profile != null) {
      _bioController.text = _profile!.bio ?? '';
      _locationController.text = _profile!.location ?? '';
      _dailyGoalController.text = _profile!.dailyGoal.toString();
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final data = {
        'bio': _bioController.text,
        'location': _locationController.text,
        'daily_goal': int.tryParse(_dailyGoalController.text) ?? 0,
      };

      final updatedProfile = await ProfileService.updateProfile(data);
      setState(() {
        _profile = updatedProfile;
        _isEditing = false;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  Future<void> _handleSwitchProgram() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Switch Program',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a program to focus on. Your progress in others will be saved.',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white38),
            ),
            const SizedBox(height: 16),
            ..._availablePrograms.map((program) {
                final isCurrent = _activeProgram?['id'] == program['id'];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCurrent ? Colors.blueAccent.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.psychology_outlined, 
                      color: isCurrent ? Colors.blueAccent : Colors.white38,
                      size: 20,
                    ),
                  ),
                  title: Text(program['title'], style: GoogleFonts.outfit(color: Colors.white, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text(program['description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  trailing: isCurrent 
                      ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20)
                      : const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                  onTap: isCurrent ? null : () async {
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    try {
                      await RecoveryService.switchProgram(program['id']);
                      await _loadProfile();
                      await _loadPrograms();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Switched to ${program['title']}')),
                        );
                      }
                    } catch (e) {
                      setState(() => _isLoading = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await TokenStorage.clearTokens();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        LoginScreen.id,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _profile == null) return const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              backgroundColor: const Color(0xFF0F172A),
              elevation: 0,
              leading: const BackButton(color: Colors.white),
              actions: [
                IconButton(
                  icon: Icon(_isEditing ? Icons.check_rounded : Icons.edit_rounded, color: Colors.white),
                  onPressed: _isEditing ? _saveProfile : () => setState(() => _isEditing = true),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Gradient Background
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.blueAccent.withOpacity(0.15),
                            const Color(0xFF0F172A),
                          ],
                        ),
                      ),
                    ),
                    // Glass effect
                    ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(color: Colors.white.withOpacity(0.01)),
                      ),
                    ),
                    // Profile Info
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 1.5),
                          ),
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: Colors.white.withOpacity(0.05),
                            backgroundImage: _profile?.avatar != null ? NetworkImage(_profile!.avatar!) : null,
                            child: _profile?.avatar == null ? const Icon(Icons.person_rounded, size: 42, color: Colors.white24) : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _profile?.user.username ?? 'User',
                          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Colors.white38),
                            const SizedBox(width: 4),
                            Text(
                              _profile?.location ?? 'Earth',
                              style: GoogleFonts.outfit(fontSize: 13, color: Colors.white38),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStreakStats(),
                      const SizedBox(height: 24),
                      
                      _buildWalletStats(),
                      const SizedBox(height: 24),

                      _buildSectionHeader('Current Program'),
                      _buildProgramCard(),
                      const SizedBox(height: 24),

                      _buildMyBadges(),
                      const SizedBox(height: 24),

                      _buildSectionHeader('Personal Details'),
                      _buildGlassCard(
                        child: Column(
                          children: [
                            _buildProfileField('Bio', _bioController, icon: Icons.notes_rounded, maxLines: 2),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(color: Colors.white24, height: 1)),
                            _buildProfileField('Daily Goal (mins)', _dailyGoalController, icon: Icons.bolt_rounded, isNumber: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildSectionHeader('App & Safety'),
                      _buildGlassCard(
                        child: Column(
                          children: [
                            _buildSettingsTile(
                              icon: Icons.notifications_active_outlined,
                              title: 'Notification Preferences',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationPreferencesScreen())),
                            ),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(color: Colors.white24, height: 1)),
                            _buildSettingsTile(
                              icon: Icons.cloud_download_outlined,
                              title: 'Offline Downloads',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OfflineDownloadsScreen())),
                            ),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(color: Colors.white24, height: 1)),
                            _buildSettingsTile(
                              icon: Icons.security_outlined,
                              title: 'Privacy & Security',
                              onTap: () {}, // TODO
                            ),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(color: Colors.white24, height: 1)),
                            _buildSettingsTile(
                              icon: Icons.feedback_outlined,
                              title: 'Share Feedback',
                              onTap: () => Navigator.pushNamed(context, FeedbackScreen.id),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),
                      _buildLogoutButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent.withOpacity(0.8), letterSpacing: 1.5),
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

  Widget _buildProfileField(String label, TextEditingController controller, {required IconData icon, int maxLines = 1, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.white38),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
                TextFormField(
                  controller: controller,
                  enabled: _isEditing,
                  maxLines: maxLines,
                  keyboardType: isNumber ? TextInputType.number : TextInputType.text,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      dense: true,
      leading: Icon(icon, color: Colors.white70, size: 20),
      title: Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 15)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
    );
  }

  Widget _buildProgramCard() {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.psychology_outlined, color: Colors.blueAccent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _activeProgram?['title'] ?? 'No Active Program',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text('Active Focus', style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _handleSwitchProgram,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('SWITCH', style: GoogleFonts.outfit(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyBadges() {
    return FutureBuilder<List<dynamic>>(
      future: _myBadgesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        
        final badges = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Unlocked Achievements'),
            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: badges.length,
                itemBuilder: (context, index) {
                  final item = badges[index];
                  final badge = item['badge'];
                  final level = item['current_level'];
                  return Container(
                    width: 110,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildBadgeIcon(badge['title']),
                        const SizedBox(height: 8),
                        Text(
                          badge['title'],
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                        Text(
                          'Level ${level['level_number']}',
                          style: GoogleFonts.outfit(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBadgeIcon(String title) {
    // Return a themed icon based on badge title
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.shield_rounded, color: Colors.amber, size: 28),
    );
  }

  Widget _buildStreakStats() {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(Icons.local_fire_department_rounded, '${_profile?.cleanDays ?? 0}', 'Current Streak', Colors.orange),
            Container(width: 1, height: 40, color: Colors.white.withOpacity(0.05)),
            _buildStatItem(Icons.auto_awesome_rounded, '${_profile?.streakRecord ?? 0}', 'Personal Record', Colors.blueAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletStats() {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.emoji_events_rounded, '${_profile?.trophies ?? 0}', 'Trophies', Colors.amber),
                _buildStatItem(Icons.monetization_on_rounded, '${_profile?.gold ?? 0}', 'Gold', Colors.orangeAccent),
                _buildStatItem(Icons.diamond_rounded, '${_profile?.gems ?? 0}', 'Gems', Colors.cyanAccent),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, 'badge_shop_screen'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Center(
                        child: Text('Visit Shop', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, 'donation_screen'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.blueAccent, Color(0xFF2563EB)]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Center(
                        child: Text('Donate Gems', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w500, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _logout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
        ),
        child: Center(
          child: Text(
            'Sign Out',
            style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
