import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/features/community/controllers/community_controller.dart';
import 'package:whiteapp/features/community/models/community_post.dart';
import 'package:whiteapp/features/progress/services/progress_service.dart';
import 'package:whiteapp/features/profile/services/profile_service.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'dart:ui';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  
  bool _isRecoveryStory = false;
  bool _isAnonymous = false;
  bool _allowComments = true;
  bool _isSubmitting = false;

  // Admin-only fields
  String? _targetGender;
  String? _targetCountry;
  int? _targetProgram;
  List<dynamic> _programs = [];

  @override
  void initState() {
    super.initState();
    _fetchPrograms();
  }

  Future<void> _fetchPrograms() async {
    final isStaff = ProfileService.cachedProfile?.user.isStaff ?? false;
    if (!isStaff) return;

    try {
      final programs = await ProgressService.getPrograms();
      if (mounted) {
        setState(() => _programs = programs);
      }
    } catch (e) {
      debugPrint('Error fetching programs: $e');
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final controller = Provider.of<CommunityController>(context, listen: false);

    final newPost = CommunityPost(
      id: 0,
      author: 0,
      authorName: '',
      authorCountryFlag: '',
      visibility: _isAnonymous ? 'anonymous' : 'public',
      originalLanguage: 'en',
      contentText: _contentController.text,
      displayText: _contentController.text,
      isRecoveryStory: _isRecoveryStory,
      challengeDay: null,
      moderationStatus: 'pending',
      allowComments: _allowComments,
      targetGender: _targetGender,
      targetCountry: _targetCountry,
      targetProgram: _targetProgram,
      targetInfo: null,
      countrySnapshot: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isRemoved: false,
      media: [],
      translations: [],
      commentsCount: 0,
      reactionsCount: 0,
      levelId: controller.assignedLevelId,
      challengeId: controller.assignedChallengeId,
      isTargetedForViewer: false,
    );

    final success = await controller.createPost(newPost);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post submitted for moderation!')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${controller.error}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = ProfileService.cachedProfile?.user.isStaff ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'Share Progress',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          if (_isSubmitting)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent)),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.blueAccent),
                onPressed: _submitPost,
              ),
            ),
        ],
      ),
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 70, 20, 40),
            children: [
              _buildGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    controller: _contentController,
                    maxLines: 8,
                    maxLength: 8000,
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Share your thoughts, ask for support, or celebrate a win...',
                      hintStyle: GoogleFonts.outfit(color: Colors.white24, fontSize: 16),
                      border: InputBorder.none,
                      counterStyle: GoogleFonts.outfit(color: Colors.white10),
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter some content' : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              _buildSectionHeader('Post Settings'),
              _buildGlassCard(
                child: Column(
                  children: [
                    _buildSwitchTile(
                      title: 'Recovery Story',
                      subtitle: 'Heroic story of overcoming addiction',
                      icon: Icons.auto_awesome_rounded,
                      value: _isRecoveryStory,
                      onChanged: (val) => setState(() => _isRecoveryStory = val),
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      title: 'Post Anonymously',
                      subtitle: 'Hide your identity from others',
                      icon: Icons.account_circle_outlined,
                      value: _isAnonymous,
                      onChanged: (val) => setState(() => _isAnonymous = val),
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      title: 'Allow Comments',
                      subtitle: 'Let the community interact with you',
                      icon: Icons.chat_bubble_outline_rounded,
                      value: _allowComments,
                      onChanged: (val) => setState(() => _allowComments = val),
                    ),
                  ],
                ),
              ),

              if (isStaff) ...[
                const SizedBox(height: 32),
                _buildSectionHeader('Admin Controls'),
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_programs.isNotEmpty) ...[
                          _buildAdminDropdown<int>(
                            label: 'Target Program',
                            value: _targetProgram,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Programs')),
                              ..._programs.map((p) => DropdownMenuItem<int>(value: p['id'], child: Text(p['title']))),
                            ],
                            onChanged: (val) => setState(() => _targetProgram = val),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _buildAdminDropdown<String>(
                          label: 'Target Gender',
                          value: _targetGender,
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Global (All)')),
                            DropdownMenuItem(value: 'male', child: Text('Male only')),
                            DropdownMenuItem(value: 'female', child: Text('Female only')),
                          ],
                          onChanged: (val) => setState(() => _targetGender = val),
                        ),
                        const SizedBox(height: 16),
                        _buildAdminDropdown<String>(
                          label: 'Target Country',
                          value: _targetCountry,
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Global (All Countries)')),
                            DropdownMenuItem(value: 'US', child: Text('🇺🇸 United States')),
                            DropdownMenuItem(value: 'FR', child: Text('🇫🇷 France')),
                            DropdownMenuItem(value: 'DE', child: Text('🇩🇪 Germany')),
                            DropdownMenuItem(value: 'ES', child: Text('🇪🇸 Spain')),
                          ],
                          onChanged: (val) => setState(() => _targetCountry = val),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 40),
              _buildSubmitButton(),
            ],
          ),
        ),
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
        title.toUpperCase(),
        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent.withOpacity(0.8), letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildSwitchTile({required String title, required String subtitle, required IconData icon, required bool value, required ValueChanged<bool> onChanged}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white38, size: 20),
      title: Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
      subtitle: Text(subtitle, style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12)),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blueAccent,
      ),
    );
  }

  Widget _buildAdminDropdown<T>({required String label, required T? value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: const Color(0xFF1E293B),
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Colors.white.withOpacity(0.02),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() => Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Divider(color: Colors.white.withOpacity(0.05), height: 1));

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _isSubmitting ? null : _submitPost,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.blueAccent, Color(0xFF2563EB)]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Center(
          child: _isSubmitting 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Post to Community', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    );
  }
}
