import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/features/support_groups/models/support_group.dart';
import 'package:whiteapp/features/support_groups/services/support_group_service.dart';
import 'package:whiteapp/features/support_groups/screens/support_group_detail_screen.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'dart:ui';

class SupportGroupListScreen extends StatefulWidget {
  const SupportGroupListScreen({Key? key}) : super(key: key);

  @override
  State<SupportGroupListScreen> createState() => _SupportGroupListScreenState();
}

class _SupportGroupListScreenState extends State<SupportGroupListScreen> {
  List<SupportGroup> _groups = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await SupportGroupService.getGroups();
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final myGroups = _groups.where((g) => g.isMember).toList();
    final freeGroups = _groups.where((g) => g.isFree && !g.isMember).toList();
    final hasPaidGroups = _groups.any((g) => !g.isFree && !g.isMember);

    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: const Color(0xFF0F172A),
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Group Therapy',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          colors: [Colors.blueAccent.withOpacity(0.15), const Color(0xFF0F172A)],
                        ),
                      ),
                    ),
                    Positioned(
                      right: -50,
                      top: -20,
                      child: Icon(Icons.psychology_outlined, size: 200, color: Colors.blueAccent.withOpacity(0.05)),
                    ),
                  ],
                ),
              ),
            ),
            
            if (_error != null)
              SliverFillRemaining(child: Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.white)))),
            
            if (_groups.isEmpty && _error == null)
              SliverFillRemaining(child: Center(child: Text('No support groups available.', style: GoogleFonts.outfit(color: Colors.white54)))),

            if (myGroups.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader('Your Active Groups'),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: myGroups.length,
                    itemBuilder: (context, index) => _buildMyGroupCard(myGroups[index]),
                  ),
                ),
              ),
            ],

            SliverToBoxAdapter(
              child: _buildSectionHeader('Available Explorations'),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildFreeGroupCard(freeGroups[index]),
                  childCount: freeGroups.length,
                ),
              ),
            ),

            if (hasPaidGroups)
              SliverToBoxAdapter(
                child: _buildPremiumTeaser(),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildMyGroupCard(SupportGroup group) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent.withOpacity(0.1), Colors.white.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(group),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.video_call_rounded, color: Colors.blueAccent, size: 20),
                  ),
                  const Spacer(),
                  Text('Next: ${group.weeklyStartTime}', style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const Spacer(),
              Text(group.title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(group.programName, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFreeGroupCard(SupportGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(group),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(group.programName, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text('FREE', style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildStat(Icons.people_outline_rounded, '${group.seatsTaken} Active Members'),
                  const SizedBox(width: 20),
                  _buildStat(Icons.access_time_rounded, group.weeklyStartTime),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white38),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
      ],
    );
  }

  Widget _buildPremiumTeaser() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_outline_rounded, color: Colors.amber.withOpacity(0.7), size: 32),
          const SizedBox(height: 12),
          Text(
            'Specialized Premium Groups',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'We also host private, advanced therapy sessions tailored for deep recovery. Join our newsletter or contact support to unlock premium group access.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(SupportGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupportGroupDetailScreen(groupId: group.id),
      ),
    );
  }
}
