import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whiteapp/features/community/controllers/community_controller.dart';
import 'package:whiteapp/features/community/models/community_post.dart';
import 'package:whiteapp/features/progress/services/progress_service.dart';

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

  // Admin-only fields (check if user is admin in real implementation)
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
    try {
      // In a real app, check if user is admin before fetching
      final programs = await ProgressService.getPrograms();
      if (mounted) {
        setState(() => _programs = programs);
      }
    } catch (e) {
      print('Error fetching programs: $e');
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

    // Create post object
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

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post created successfully!')),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${controller.error}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          if (_isSubmitting)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _submitPost,
              tooltip: 'Submit Post',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _contentController,
              maxLines: 8,
              maxLength: 8000,
              decoration: const InputDecoration(
                labelText: 'What\'s on your mind?',
                hintText: 'Share your thoughts, ask for support, or share your progress...',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter some content';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
            const Text(
              'Post Options',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              title: const Text('Recovery Story'),
              subtitle: const Text('Mark this as a recovery story'),
              value: _isRecoveryStory,
              onChanged: (value) => setState(() => _isRecoveryStory = value),
            ),
            SwitchListTile(
              title: const Text('Post Anonymously'),
              subtitle: const Text('Hide your name on this post'),
              value: _isAnonymous,
              onChanged: (value) => setState(() => _isAnonymous = value),
            ),
            SwitchListTile(
              title: const Text('Allow Comments'),
              subtitle: const Text('Let others comment on your post'),
              value: _allowComments,
              onChanged: (value) => setState(() => _allowComments = value),
            ),
            // TODO: Add media picker
            const SizedBox(height: 8),
            const Divider(),
            const Text(
              'Admin Options',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_programs.isNotEmpty) ...[
              DropdownButtonFormField<int>(
                value: _targetProgram,
                decoration: const InputDecoration(
                  labelText: 'Target Program',
                  hintText: 'All Programs',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Programs')),
                  ..._programs.map((p) => DropdownMenuItem<int>(
                        value: p['id'],
                        child: Text(p['title']),
                      )),
                ],
                onChanged: (value) => setState(() => _targetProgram = value),
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              value: _targetGender,
              decoration: const InputDecoration(
                labelText: 'Target Gender',
                hintText: 'All',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
              ],
              onChanged: (value) => setState(() => _targetGender = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _targetCountry,
              decoration: const InputDecoration(
                labelText: 'Target Country',
                hintText: 'All Countries',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('All Countries')),
                DropdownMenuItem(value: 'US', child: Text('🇺🇸 United States')),
                DropdownMenuItem(value: 'FR', child: Text('🇫🇷 France')),
                DropdownMenuItem(value: 'DE', child: Text('🇩🇪 Germany')),
                DropdownMenuItem(value: 'ES', child: Text('🇪🇸 Spain')),
                // Add more countries as needed
              ],
              onChanged: (value) => setState(() => _targetCountry = value),
            ),
          ],
        ),
      ),
    );
  }
}
