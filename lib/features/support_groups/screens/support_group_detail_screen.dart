import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/features/support_groups/models/support_group.dart';
import 'package:whiteapp/features/support_groups/services/support_group_service.dart';
import 'package:whiteapp/features/support_groups/screens/live_session_screen.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';

class SupportGroupDetailScreen extends StatefulWidget {
  final int groupId;

  const SupportGroupDetailScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  State<SupportGroupDetailScreen> createState() => _SupportGroupDetailScreenState();
}

class _SupportGroupDetailScreenState extends State<SupportGroupDetailScreen> {
  SupportGroup? _group;
  bool _isLoading = true;
  String? _error;
  bool _isJoining = false;
  bool _isEntering = false;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    try {
      final group = await SupportGroupService.getGroupDetail(widget.groupId);
      setState(() {
        _group = group;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _joinGroup() async {
    setState(() => _isJoining = true);
    try {
      await SupportGroupService.joinGroup(widget.groupId);
      await _loadGroup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined group successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _enterSession() async {
    setState(() => _isEntering = true);
    try {
      if (_group?.meetingProvider != 'livekit') {
        final tokenData = await SupportGroupService.getLiveKitToken(widget.groupId);
        final link = tokenData['meeting_link'];
        if (link != null && link.isNotEmpty) {
          final url = Uri.parse(link);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch meeting link')));
          }
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No meeting link available')));
        }
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LiveSessionScreen(group: _group!),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isEntering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(backgroundColor: Color(0xFF0F172A), appBar: AppBar(backgroundColor: Colors.transparent), body: Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.white))));

    final group = _group!;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(group),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTherapistHeader(group),
                    const SizedBox(height: 32),
                    
                    _buildInfoGrid(group),
                    const SizedBox(height: 32),

                    _buildSectionHeader('Description'),
                    Text(
                      group.description,
                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 24),

                    if (group.goals.isNotEmpty) ...[
                      _buildSectionHeader('Core Goals'),
                      Text(
                        group.goals,
                        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                    ],

                    const SizedBox(height: 100), // Space for FAB
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildActionButton(group),
    );
  }

  Widget _buildAppBar(SupportGroup group) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: const Color(0xFF0F172A),
      leading: const BackButton(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blueAccent.withOpacity(0.3), const Color(0xFF0F172A)],
                ),
              ),
            ),
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withOpacity(0.1)),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),
                  Text(
                    group.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(group.programName, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTherapistHeader(SupportGroup group) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.blueAccent.withOpacity(0.1),
            backgroundImage: group.therapist['avatar_url'] != null ? NetworkImage(group.therapist['avatar_url']) : null,
            child: group.therapist['avatar_url'] == null ? const Icon(Icons.person_rounded, size: 30, color: Colors.blueAccent) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hosted by', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
                Text(group.therapist['name'], style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                if (group.therapist['bio'] != null)
                  Text(group.therapist['bio'], maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(SupportGroup group) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildInfoCard(Icons.calendar_month_rounded, 'Sessions', '${group.sessionCount} Classes'),
        _buildInfoCard(Icons.schedule_rounded, 'Weekly', group.weeklyStartTime),
        _buildInfoCard(Icons.payments_outlined, 'Price', group.formattedPrice),
        _buildInfoCard(Icons.people_outline_rounded, 'Seats', '${group.availableSeats} of ${group.capacity}'),
      ],
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildActionButton(SupportGroup group) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: group.isMember
            ? ElevatedButton(
                onPressed: _isEntering ? null : _enterSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                  shadowColor: Colors.blueAccent.withOpacity(0.3),
                ),
                child: _isEntering 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.video_call_rounded),
                        const SizedBox(width: 8),
                        Text('Enter Live Session', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
              )
            : ElevatedButton(
                onPressed: _isJoining || group.availableSeats == 0 ? null : _joinGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.05),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.1))),
                  elevation: 0,
                ),
                child: _isJoining
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(group.availableSeats == 0 ? 'Group Fully Booked' : 'Join Journey', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
      ),
    );
  }
}
